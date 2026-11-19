# frozen_string_literal: true

require "json"

module IdentityProbeEngine
  module Llm
    # Haiku 4.5 — raw signals → 구조화된 JSON 추출.
    # 키 없거나 호출 실패 시 {status: "skipped"} 반환 (orchestrator가 부분 결과로 처리).
    class ExtractHaiku
      DEFAULT_MODEL = "claude-haiku-4-5-20251001"
      API           = "https://api.anthropic.com/v1/messages"

      def self.call(raw_signals)
        new.call(raw_signals)
      end

      def call(raw_signals)
        signals = Array(raw_signals)
        if anthropic_key.empty?
          if Rails.env.local? && ENV["LLM_MOCK"] == "1"
            Rails.logger.warn("[IdentityProbe:ExtractHaiku] mock mode (LLM_MOCK=1)")
            return mock_result(signals)
          end

          return { "status" => "skipped", "reason" => "llm_unavailable" }
        end
        return { "status" => "skipped", "reason" => "no_signals" } if signals.empty?

        config = llm_config
        body = build_body(signals, config)
        outcome = {}
        res  = ::Llm::Client.post(outcome: outcome, purpose: "identity_extract", model: config.model, provider: config.provider,
          url: API, body: body, headers: {
          "x-api-key"         => anthropic_key,
          "anthropic-version" => "2023-06-01",
          "content-type"      => "application/json"
        })

        return { "status" => "skipped", "reason" => outcome["status"].presence || "api_failed" } unless res

        text = ::Llm::Client.extract_text(res)
        parse_structured(text) || { "status" => "skipped", "reason" => "parse_failed", "raw" => text.to_s[0, 500] }
      rescue => e
        Rails.logger.warn("[IdentityProbe:ExtractHaiku] #{e.class}: #{e.message}")
        { "status" => "skipped", "reason" => "exception", "error" => "#{e.class}: #{e.message}" }
      end

      private

      def anthropic_key
        ENV["ANTHROPIC_API_KEY"].to_s.strip
      end

      def llm_config
        LlmConfig.for("identity_extract", default_model: DEFAULT_MODEL)
      end

      def build_body(signals, config)
        prompt = <<~PROMPT
          다음은 공개된 웹/SNS에서 수집한 raw 신호입니다. 이 사람의 정체성 단서만 추출해 구조화 JSON으로 응답하세요.

          반드시 다음 스키마의 **JSON만** 반환하세요. 다른 문장/설명/마크다운 절대 금지.
          {
            "candidate_names": ["..."],
            "candidate_roles": ["..."],
            "candidate_regions": ["..."],
            "bio_sentences": ["원문 그대로의 짧은 자기소개 문장"],
            "links": [{"url":"...","source":"..."}],
            "notes": "짧은 한줄"
          }

          raw_signals:
          #{JSON.pretty_generate(signals.first(15))}
        PROMPT

        body = {
          model: config.model,
          max_tokens: config.max_tokens || 1024,
          messages: [ { role: "user", content: prompt } ]
        }
        body[:temperature] = config.temperature unless config.temperature.nil?
        body
      end

      def parse_structured(text)
        return nil if text.to_s.strip.empty?
        # JSON 블록만 떼내기 (간혹 모델이 ```json 감싸는 경우)
        json_str = text.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
        JSON.parse(json_str)
      rescue JSON::ParserError
        nil
      end

      def mock_result(signals)
        {
          "status" => "mock",
          "candidate_names" => signals.filter_map { |s| s[:display_name] || s[:title] }.first(3),
          "candidate_roles" => [],
          "candidate_regions" => signals.filter_map { |s| s[:location] }.uniq,
          "bio_sentences" => signals.filter_map { |s| s[:bio] || s[:snippet] }.first(3).compact,
          "links" => signals.filter_map { |s|
            next nil unless s[:profile_url] || s[:link]
            { "url" => s[:profile_url] || s[:link], "source" => s[:source].to_s }
          }.first(5),
          "notes" => "mock mode — ANTHROPIC_API_KEY not set"
        }
      end
    end
  end
end
