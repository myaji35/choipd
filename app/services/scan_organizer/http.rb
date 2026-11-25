require "net/http"

module ScanOrganizer
  module Http
    class Error < StandardError; end

    def self.request(method, url, headers:)
      uri = URI(url)
      request = method.new(uri, headers)

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
  end
end
