module Linkedin
  class DashboardParser
    LABELS = {
      post_impressions_7d: "7일 동안 게시물 노출수",
      followers_total: "총 팔로워",
      profile_viewers_90d: "90일 동안 프로필 조회자수",
      search_appearances: "검색 결과 노출",
      newsletter_views_7d: "7일 동안 뉴스레터 글 조회수",
      newsletter_subscribers_7d: "7일 동안 신규 뉴스레터 구독자수"
    }.freeze

    def initialize(text)
      @lines = text.to_s.lines.map(&:strip).reject(&:empty?)
    end

    def metrics
      LABELS.to_h do |key, label|
        index = @lines.index do |line|
          key == :search_appearances ? line.start_with?(label) : line == label
        end
        value = @lines[index - 1].delete(",")[/\A\d+\z/]&.to_i if index&.positive?
        change = @lines[index + 1]&.gsub(/[[:space:]\u200B]/, "")&.[](/\A(-?\d+)%\z/, 1)&.to_i if index
        period = @lines[index].split(":", 2).last&.strip if key == :search_appearances && index && @lines[index].include?(":")
        [ key, { label: label, value: value, linkedin_change_pct: change, period: period } ]
      end
    end

    def weekly
      index = @lines.index("주간 진행 상황")
      return unless index

      range = @lines[index + 1]
      section = @lines.slice(index + 2, 12) || []
      {
        range: range,
        posted: weekly_status(section, "게시물 없음", /게시물|글/),
        commented: weekly_status(section, "댓글 없음", /댓글/)
      }
    end

    private

    def weekly_status(section, absent, evidence)
      return false if section.include?(absent)

      true if section.any? { |line| line.match?(evidence) }
    end
  end
end
