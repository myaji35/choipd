module Linkedin
  class ActivityParser
    ACTIVITY_ID = %r{/analytics/post-summary/urn:li:activity:(\d+)}
    END_OF_BODY = /\A(?:노출\s*[\d,]+|분석 보기\z|스폰서로 등록\z|(?:(?:…|\.{3})\s*)?더\s*보기\z|[[:space:]\u200B]*\z)/

    RELATIVE_TIME = /\A\d+\s*(분|시간|일|주|개월|년)\s*•/

    def initialize(text, links)
      @blocks = text.to_s.split(/^[ \t]*피드 게시물[ \t]*\r?$/).drop(1)
      @links = links.is_a?(Array) ? links : []
    end

    def posts
      analytics_indices = @links.each_index.select { |index| @links[index].to_s.match?(ACTIVITY_ID) }
        .uniq { |index| @links[index][ACTIVITY_ID, 1] }
      used_article_urls = Set.new

      @blocks.map.with_index do |block, index|
        lines = block.strip.lines.map(&:strip)
        time_index = lines.index { |line| line.match?(RELATIVE_TIME) }
        title_lines, article = title_content(lines, time_index)
        link_index = analytics_indices[index]
        analytics_url = @links[link_index] if link_index
        activity_id = analytics_url&.[](ACTIVITY_ID, 1)
        article_url = @links[link_index - 1] if link_index&.positive?
        article_url = nil unless article_url.to_s.include?("/pulse/") && used_article_urls.add?(article_url)

        {
          activity_id: activity_id,
          title: article ? title_lines.last : title_lines.first&.slice(0, 120),
          newsletter_name: (title_lines[-2] if article),
          kind: article ? "article" : "post",
          relative_time: (lines[time_index] if time_index),
          impressions: block[/노출\s*([\d,]+)/, 1]&.delete(",")&.to_i,
          posted_at: (Time.at((activity_id.to_i >> 22) / 1000.0).utc if activity_id),
          post_url: ("https://www.linkedin.com/feed/update/urn:li:activity:#{activity_id}/" if activity_id),
          analytics_url: analytics_url,
          article_url: article_url
        }
      end
    end

    private

    def title_content(lines, time_index)
      return [ [], false ] unless time_index

      body = lines.drop(time_index + 1)
      # LinkedIn also inserts a blank separator between each line of some cards.
      if time_index > 1 && lines[1].empty? && lines[time_index - 1].empty?
        body = body.reject.with_index { |line, index| index.even? && line.empty? }
      end
      title_lines = body.take_while { |line| line != lines.first && !line.match?(END_OF_BODY) }
      [ title_lines, body[title_lines.length] == lines.first ]
    end
  end
end
