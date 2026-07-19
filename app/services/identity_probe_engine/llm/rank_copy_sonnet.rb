# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module IdentityProbeEngine
  module Llm
    # Sonnet 4.6 — Haiku의 구조화 신호를 병합·랭킹하고 bio를 imPD 톤으로 재작성.
    # 키 없거나 실패 시 {status: "skipped"} — orchestrator가 부분 결과로 처리.
    class RankCopySonnet
      MODEL = "claude-sonnet-4-6"
      API   = "https://api.anthropic.com/v1/messages"

      def self.call(structured_signals, hints: {})
        new.call(structured_signals, hints: hints || {})
      end

      def call(structured_signals, hints: {})
        return mock_result(structured_signals, hints) if anthropic_key.empty?
        return { "status" => "skipped", "reason" => "no_structured" } unless structured_signals.is_a?(Hash)

        body = build_body(structured_signals, hints)
        res  = post_json(API, body, headers: {
          "x-api-key"         => anthropic_key,
          "anthropic-version" => "2023-06-01",
          "content-type"      => "application/json",
        })

        return { "status" => "skipped", "reason" => "api_failed" } unless res

        text = extract_text(res)
        parse_structured(text) || { "status" => "skipped", "reason" => "parse_failed", "raw" => text.to_s[0, 500] }
      rescue => e
        Rails.logger.warn("[IdentityProbe:RankCopySonnet] #{e.class}: #{e.message}")
        { "status" => "skipped", "reason" => "exception", "error" => "#{e.class}: #{e.message}" }
      end

      private

      def anthropic_key
        ENV["ANTHROPIC_API_KEY"].to_s.strip
      end

      def build_body(structured, hints)
        prompt = <<~PROMPT
          당신은 imPD의 브랜드 카피 에디터입니다. 아래 구조화된 신호와 회원이 입력한 힌트를 기반으로,
          프로필 초안을 만드세요. 확실하지 않은 정보는 포함하지 마세요. 환각 금지.

          반드시 다음 스키마의 **JSON만** 반환하세요. 다른 문장/설명/마크다운 절대 금지.
          {
            "display_name": "...",
            "professional_roles": ["..."],
            "region": {"country":"KR","city":"..."},
            "bio_draft": "2~3문장. 담백·당당한 imPD 톤.",
            "bio_source_quote": "bio_draft가 참조한 원문 한 줄(환각 검증용)",
            "links": [{"url":"...","label":"...","source":"..."}],
            "confidence": 0.0
          }

          structured_signals:
          #{JSON.pretty_generate(structured)}

          member_hints:
          #{JSON.pretty_generate(hints)}
        PROMPT

        {
          model: MODEL,
          max_tokens: 1024,
          messages: [{ role: "user", content: prompt }],
        }
      end

      def post_json(url, body, headers: {})
        uri = URI.parse(url)
        req = Net::HTTP::Post.new(uri)
        headers.each { |k, v| req[k] = v }
        req.body = JSON.generate(body)

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10, open_timeout: 4) do |http|
          http.request(req)
        end
        return nil unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      rescue => e
        Rails.logger.warn("[IdentityProbe:RankCopySonnet:http] #{e.class}: #{e.message}")
        nil
      end

      def extract_text(res)
        Array(res["content"]).map { |c| c["text"] }.compact.join("\n")
      end

      def parse_structured(text)
        return nil if text.to_s.strip.empty?
        json_str = text.strip.sub(/\A```(?:json)?\s*/, "").sub(/\s*```\z/, "")
        JSON.parse(json_str)
      rescue JSON::ParserError
        nil
      end

      def mock_result(structured, hints)
        names  = Array(structured && structured["candidate_names"]).first(1)
        roles  = Array(structured && structured["candidate_roles"]).first(2)
        region = Array(structured && structured["candidate_regions"]).first
        bios   = Array(structured && structured["bio_sentences"]).first(2).compact
        links  = Array(structured && structured["links"]).first(3)

        {
          "status" => "mock",
          "display_name" => names.first || hints[:name].to_s,
          "professional_roles" => roles.empty? ? [hints[:profession_hint]].compact : roles,
          "region" => { "country" => "KR", "city" => region.to_s },
          "bio_draft" => bios.first.to_s.empty? ? "아직 자기소개를 확정하지 않았습니다. 잠시 뒤 확인하세요." : bios.join(" "),
          "bio_source_quote" => bios.first.to_s[0, 140],
          "links" => links,
          "confidence" => structured && structured["candidate_names"].is_a?(Array) && !structured["candidate_names"].empty? ? 0.45 : 0.1,
        }
      end
    end
  end
end
