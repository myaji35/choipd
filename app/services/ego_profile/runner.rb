require "open3"
require "timeout"

module EgoProfile
  class Runner
    SCRIPTS = { "naver_people" => "naver_people_check.mjs", "linkedin" => "linkedin_check.mjs" }.freeze

    def self.binary
      ENV["EGO_BROWSER_BIN"].presence || [ File.expand_path("~/.local/bin/ego-browser"), "/opt/homebrew/bin/ego-browser", "/usr/local/bin/ego-browser" ].find { |path| File.file?(path) && File.executable?(path) }
    end

    def self.available? = binary.present?

    def call(platform)
      script = SCRIPTS[platform] or raise Error, "알 수 없는 플랫폼: #{platform}"
      executable = self.class.binary or raise Error, "ego 브라우저를 찾을 수 없습니다."
      stdout, stderr, = Timeout.timeout(240) do
        Open3.capture3(executable, "nodejs", stdin_data: File.read(Rails.root.join("lib/ego", script)))
      end
      line = [ stdout, stderr ].filter_map { |output| output.lines.reverse.find { |entry| entry.start_with?("EGO_RESULT ") } }.first
      diagnostic = stderr.lines.reject { |entry| entry.start_with?("EGO_RESULT ") }.join.last(300)
      raise Error, "점검 결과가 없습니다. #{diagnostic}" unless line
      begin
        JSON.parse(line.delete_prefix("EGO_RESULT "))
      rescue JSON::ParserError
        raise Error, "점검 결과를 읽을 수 없습니다. #{diagnostic}"
      end
    rescue Timeout::Error, SystemCallError => e
      raise Error, e.message
    end
  end
end
