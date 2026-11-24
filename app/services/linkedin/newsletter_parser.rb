module Linkedin
  class NewsletterParser
    AUTHOR = /\s*·\s*글쓴이\z/
    COUNT = /\d+(?:,\d{3})*/

    def initialize(pages)
      @pages = pages.is_a?(Hash) ? pages : {}
    end

    def to_h
      list = @pages["newsletters"]
      lines = page_lines(list).take_while { |line| line != "소개" }
      heading = lines.index { |line| line.match?(/\A뉴스레터 #{COUNT}\z/) }
      lines = lines.drop(heading + 1) if heading
      details = array(@pages["newsletter_pages"]).select { |page| page.is_a?(Hash) }.index_by { |page| normalize_url(page["url"]) }

      newsletters = page_links(list, "/newsletters/").reject { |url| url.include?("/mynetwork/") }.filter_map do |url|
        index = lines.index { |line| slug(line.sub(AUTHOR, "")) == url_slug(url) }
        index ||= 0 if lines.first&.match?(AUTHOR) || (heading && lines.first && !lines.first.match?(/\A구독자\s/))
        next unless index

        lines = lines.drop(index)
        label = lines.shift
        count = number(lines.first&.match(/\A구독자\s*(#{COUNT})\z/)&.[](1))
        lines.shift if count
        {
          name: label.sub(AUTHOR, ""),
          role: label.match?(AUTHOR) ? "author" : "subscriber",
          url: url
        }.merge(detail(details[url], count))
      end
      { newsletters: newsletters }
    end

    private

    def array(value)
      value.is_a?(Array) ? value : []
    end

    def page_lines(page)
      return [] unless page.is_a?(Hash) && !page.key?("error") && page["text"].is_a?(String)

      page["text"].lines.map(&:strip).reject(&:empty?)
    end

    def page_links(page, path)
      return [] unless page.is_a?(Hash) && !page.key?("error")

      array(page["links"]).grep(%r{\Ahttps?://(?:www\.)?linkedin\.com#{path}[^/?#]}i).map { |url| normalize_url(url) }.uniq
    end

    def normalize_url(url)
      return unless url.is_a?(String)

      url.sub(/[?#].*\z/, "").sub(%r{/+\z}, "")
    end

    def slug(name)
      name.downcase.gsub(/[^\p{Alnum}]+/, "-").delete_suffix("-").delete_prefix("-")
    end

    def url_slug(url)
      decoded = URI::DEFAULT_PARSER.unescape(url.split("/").last).scrub
      slug(decoded.sub(/-\d+\z/, ""))
    end

    def number(value)
      value&.delete(",")&.to_i
    end

    def detail(page, count)
      lines = page_lines(page)
      links = page_links(page, "/pulse/")
      blocks = lines.each_index.select { |index| lines[index] == "피드 게시물" }
      links = [] unless blocks.size == links.size
      editions = blocks.each_with_index.filter_map do |index, link_index|
        published = lines[index + 1]&.match(/\A발행일:\s*(\d+\s*(?:분|시간|일|주|개월|년)\s*전)\z/)&.[](1)
        title, author = lines[index + 2, 2]
        next unless published && title && author && author != "피드 게시물"

        { title: title, published_relative: published, url: links[link_index] }
      end
      {
        subscribers: number(lines.filter_map { |line| line[/\A구독자\s*(#{COUNT})명\z/, 1] }.first) || count,
        new_subscribers_7d: number(lines.filter_map { |line| line[/\A(#{COUNT})\s*신규 구독자\z/, 1] }.first),
        cadence: lines.find { |line| line.match?(/\A(?:매\S+|#{COUNT}\s*(?:일|주|개월)마다)\s*발행\z/) },
        editions: editions
      }
    end
  end
end
