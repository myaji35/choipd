# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Llm
  class Client
    # outcome: 옵셔널 out 파라미터. 호출자가 Hash를 넘기면 실패 사유(status/error)를 받아간다.
    # 반환 계약(Hash 또는 nil)은 그대로 유지한다.
    def self.post(purpose:, model:, provider: "anthropic", body:, headers:, url:, outcome: nil)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status = nil
      error = nil
      parsed = nil

      begin
        uri = URI.parse(url)
        req = Net::HTTP::Post.new(uri)
        headers.each { |key, value| req[key] = value }
        req.body = JSON.generate(body)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10, open_timeout: 4) do |http|
          http.request(req)
        end

        unless response.is_a?(Net::HTTPSuccess)
          status = "api_failed"
          error = "HTTP #{response.code} #{response.message}".strip
          Rails.logger.warn("[Llm::Client] #{purpose} #{error}")
          return nil
        end

        parsed = JSON.parse(response.body)
        status = "ok"
        parsed
      rescue JSON::ParserError => e
        status = "parse_failed"
        error = "#{e.class}: #{e.message}"[0, 500]
        Rails.logger.warn("[Llm::Client] #{purpose} #{error}")
        nil
      rescue => e
        status = "exception"
        error = "#{e.class}: #{e.message}"[0, 500]
        Rails.logger.warn("[Llm::Client] #{purpose} #{error}")
        nil
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        usage = parsed.is_a?(Hash) ? parsed["usage"] : nil

        if outcome.is_a?(Hash)
          outcome["status"] = status || "exception"
          outcome["error"]  = error
        end

        begin
          LlmCallLog.create!(
            purpose: purpose,
            model: model,
            provider: provider,
            tokens_in: usage.is_a?(Hash) ? usage["input_tokens"] : nil,
            tokens_out: usage.is_a?(Hash) ? usage["output_tokens"] : nil,
            duration_ms: duration_ms,
            status: status || "exception",
            error: error,
          )
        rescue => log_error
          Rails.logger.warn("[Llm::Client:log] #{log_error.class}: #{log_error.message}")
        end
      end
    end

    def self.extract_text(res)
      Array(res["content"]).map { |content| content["text"] }.compact.join("\n")
    end
  end
end
