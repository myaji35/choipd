require "net/http"
require "json"

module ScanOrganizer
  module Http
    class Error < StandardError; end

    def self.request(method, url, headers: {}, query: {}, json: nil, form: nil)
      uri = URI(url)
      uri.query = URI.encode_www_form(query) unless query.empty?
      request = method.new(uri, headers)
      if json
        request.content_type = "application/json"
        request.body = JSON.generate(json)
      elsif form
        request.set_form_data(form)
      end

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 30, write_timeout: 30) do |http|
        http.max_retries = 0
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "외부 서비스 요청에 실패했습니다 (HTTP #{response.code})."
      end

      response.body
    rescue Error
      raise
    rescue StandardError
      raise Error, "외부 서비스에 연결하지 못했습니다.", cause: nil
    end

    def self.parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      raise Error, "외부 서비스의 응답 형식이 올바르지 않습니다.", cause: nil
    end
  end
end
