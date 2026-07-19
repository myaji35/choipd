# frozen_string_literal: true

module IdentityProbeEngine
  # 파이프라인: probe record 생성 → 병렬 소스 수집 → Haiku 추출 → Sonnet 랭크/카피 → 저장.
  # 단계별 예외는 개별 격리. 한 단계 실패해도 나머지는 진행한다.
  # LLM 키 없으면 mock fallback.
  class Orchestrator
    def self.call(member)
      new(member).call
    end

    def initialize(member)
      @member = member
    end

    def call
      probe = find_or_create_probe
      probe.update(status: "in_progress")

      hints = {
        name: @member.name,
        email: @member.email,
        profession_hint: @member.respond_to?(:profession) ? @member.profession : nil,
        region_hint: @member.respond_to?(:region) ? @member.region : nil,
      }

      raw_signals, sources_queried, sources_hit = run_sources(hints)
      structured = safe_call_llm(:extract) { Llm::ExtractHaiku.call(raw_signals) }
      profile    = safe_call_llm(:rank_copy) { Llm::RankCopySonnet.call(structured, hints: hints) }

      confidence = extract_confidence(profile)
      status     = raw_signals.empty? && !mock_mode? ? "failed" : "completed"

      probe.update(
        status: status,
        confidence: confidence,
        identity: {
          "profile"     => profile,
          "structured"  => structured,
          "hints"       => stringify_hints(hints),
          "mock_mode"   => mock_mode?,
        },
        sources_queried: sources_queried,
        sources_hit: sources_hit,
        raw_signals: raw_signals,
      )

      probe
    rescue => e
      Rails.logger.error("[IdentityProbeEngine:Orchestrator] failed member_id=#{@member&.id} error=#{e.class}: #{e.message}")
      probe&.update(status: "failed", identity: { "error" => "#{e.class}: #{e.message.to_s[0, 200]}" })
      raise
    end

    private

    def find_or_create_probe
      # 최신 pending 하나가 있으면 재사용, 아니면 새로 생성.
      existing = ::IdentityProbe.where(member_id: @member.id).where(status: %w[pending in_progress]).order(created_at: :desc).first
      return existing if existing.present?
      ::IdentityProbe.create!(member_id: @member.id, status: "pending", sources_queried: [], sources_hit: [], raw_signals: [], step_payloads: {}, identity: {})
    end

    def run_sources(hints)
      sources = [
        Sources::GravatarSource.new,
        Sources::GoogleCseSource.new,
        Sources::NaverSearchSource.new,
        Sources::InstagramOembedSource.new,
      ]

      raw_signals = []
      queried     = []
      hit         = []

      # 병렬 실행. 각 소스 개별 예외 격리는 BaseSource#fetch가 담당.
      threads = sources.map do |source|
        Thread.new do
          begin
            source.fetch(email: hints[:email], name: hints[:name], hints: hints)
          rescue => e
            Rails.logger.warn("[IdentityProbe:Orchestrator] source #{source.class} failed: #{e.class}: #{e.message}")
            { signals: [], source: source.class.source_key }
          end
        end
      end

      threads.map(&:value).each do |res|
        key = res[:source].to_s
        queried << key
        sigs = Array(res[:signals])
        next if sigs.empty?
        hit << key
        sigs.each { |s| raw_signals << s.merge(source: key) }
      end

      [raw_signals, queried.uniq, hit.uniq]
    end

    def safe_call_llm(stage)
      yield
    rescue => e
      Rails.logger.warn("[IdentityProbeEngine:Orchestrator] llm #{stage} failed: #{e.class}: #{e.message}")
      { "status" => "skipped", "reason" => "exception", "error" => "#{e.class}: #{e.message}" }
    end

    def mock_mode?
      ENV["ANTHROPIC_API_KEY"].to_s.strip.empty?
    end

    def extract_confidence(profile)
      return nil unless profile.is_a?(Hash)
      val = profile["confidence"] || profile[:confidence]
      return nil unless val
      Float(val) rescue nil
    end

    def stringify_hints(hints)
      hints.transform_keys(&:to_s).transform_values { |v| v.is_a?(String) ? v : v.to_s }
    end
  end
end
