require "pdf/reader"
require "stringio"

# PDF binary → plain text (pure Ruby, no external binary).
# 실패 시 empty string 반환 (크래시 방지).
class PdfTextExtractor
  MAX_PAGES = 50  # 폭발 방지
  MAX_CHARS = 200_000

  def self.extract(binary)
    return "" if binary.blank?
    io = StringIO.new(binary)
    reader = PDF::Reader.new(io)
    buffer = []
    reader.pages.first(MAX_PAGES).each do |page|
      buffer << page.text.to_s
      break if buffer.sum(&:length) > MAX_CHARS
    end
    buffer.join("\n\n").strip
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
    Rails.logger.warn "[PdfTextExtractor] #{e.class}: #{e.message}"
    ""
  rescue StandardError => e
    Rails.logger.error "[PdfTextExtractor] unexpected #{e.class}: #{e.message}"
    ""
  end
end
