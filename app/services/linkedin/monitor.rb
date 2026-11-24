module Linkedin
  class Monitor
    TIME_ZONE = "Asia/Seoul"

    def initialize(snapshots)
      snapshots = snapshots.to_a
      @dashboard_snapshots = snapshots.select { |snapshot| page(snapshot, "dashboard") }
      @activity_snapshots = snapshots.select { |snapshot| page(snapshot, "activity") }
    end

    def latest_metrics
      latest = @dashboard_snapshots.first
      previous = @dashboard_snapshots.drop(1).find { |snapshot| date(snapshot) < date(latest) }
      previous_metrics = dashboard(previous).metrics
      dashboard(latest).metrics.to_h do |key, metric|
        [ key, metric.merge(delta: difference(metric[:value], previous_metrics[key][:value])) ]
      end
    end

    def daily_series
      today = Time.current.in_time_zone(TIME_ZONE).to_date
      @dashboard_snapshots.uniq { |snapshot| date(snapshot) }.filter_map do |snapshot|
        day = date(snapshot)
        next unless (today - 29..today).cover?(day)

        { date: day, values: dashboard(snapshot).metrics.transform_values { |metric| metric[:value] } }
      end
    end

    def posts
      @posts ||= begin
        previous = activity(@activity_snapshots[1]).index_by { |post| post[:activity_id] }
        activity(@activity_snapshots.first).map do |post|
          before = previous[post[:activity_id]] if post[:activity_id]
          post.merge(impressions_delta: difference(post[:impressions], before&.fetch(:impressions)))
        end
      end
    end

    def weekly_recommendation
      now = Time.current
      posted = posts.any? { |post| post[:posted_at] && (now - 7.days..now).cover?(post[:posted_at]) }
      weekly = dashboard(@dashboard_snapshots.first).weekly
      message = if !posted && !weekly&.fetch(:posted)
        "이번 주에 글을 한 번 올려 보세요."
      elsif weekly&.fetch(:commented).nil?
        "최근 7일 안에 게시했습니다. 댓글 정보는 다음 점검 때 확인합니다."
      elsif !weekly[:commented]
        "이번 주에 관심 있는 글에 댓글을 한 번 남겨 보세요."
      else
        "이번 주 게시와 댓글 목표를 달성했습니다."
      end
      { posted_last_7_days: posted, linkedin_weekly: weekly, message: message }
    end

    private

    def date(snapshot)
      snapshot.captured_at.in_time_zone(TIME_ZONE).to_date
    end

    def page(snapshot, key)
      data = snapshot&.data
      pages = data["pages"] if data.is_a?(Hash)
      page = pages[key] if pages.is_a?(Hash)
      page if page.is_a?(Hash) && !page.key?("error") && page["text"].is_a?(String) && page["text"].present?
    end

    def dashboard(snapshot)
      DashboardParser.new(page(snapshot, "dashboard")&.fetch("text"))
    end

    def activity(snapshot)
      data = page(snapshot, "activity") || {}
      ActivityParser.new(data["text"], data["links"]).posts
    end

    def difference(value, previous)
      value - previous if value && previous
    end
  end
end
