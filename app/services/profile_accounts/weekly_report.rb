module ProfileAccounts
  class WeeklyReport
    TIME_ZONE = Linkedin::Monitor::TIME_ZONE
    NETWORK_LABELS = {
      connections: "1촌", following: "팔로우 중", invitations_sent: "보낸 초대",
      unread_messages: "새 메시지", unread_notifications: "새 알림"
    }.freeze
    APPLICATION_STATUSES = { "ING" => :in_progress, "END" => :completed }.freeze
    APPLICATION_LABELS = { in_progress: "진행 중", completed: "완료" }.freeze
    APPLICATION_CHANGE_LABELS = { "new" => "새 신청", "status_changed" => "상태 변경", "finished" => "완료" }.freeze

    def self.today
      Time.current.in_time_zone(TIME_ZONE).to_date
    end

    def initialize(tenant_id: 1, week_end: self.class.today)
      @tenant_id = tenant_id
      @week_end = week_end
      @week_start = week_end - 6
      @start_at = @week_start.in_time_zone(TIME_ZONE)
      @cutoff = (@week_end + 1).in_time_zone(TIME_ZONE)
    end

    def to_h
      @report ||= begin
        accounts = ProfileAccount.active.where(tenant_id: @tenant_id).order(:display_name, :id).group_by(&:platform)
        {
          week_start: @week_start, week_end: @week_end,
          linkedin: accounts.fetch("linkedin", []).map { |account| account_report(account) { |snapshots| linkedin_report(snapshots) } },
          naver_people: accounts.fetch("naver_people", []).map { |account| account_report(account) { |snapshots| naver_report(snapshots) } }
        }
      end
    end

    def to_text
      report = to_h
      lines = [ "인물정보 주간 리포트 #{@week_start} ~ #{@week_end}" ]
      { linkedin: "LinkedIn", naver_people: "네이버 인물정보" }.each do |platform, label|
        lines << "" << label
        lines << "활성 계정이 없습니다." if report[platform].empty?
        report[platform].each do |account|
          lines << account[:display_name]
          lines.concat(if !account[:has_snapshot]
            [ "이 기간의 사본이 없습니다." ]
          elsif platform == :linkedin
            linkedin_lines(account)
          else
            naver_lines(account)
          end)
        end
      end
      lines.join("\n")
    end

    private

    def account_report(account)
      snapshots = account.profile_snapshots.where("captured_at < ?", @cutoff).recent.order(id: :desc).to_a
      has_snapshot = snapshots.first.present? && snapshots.first.captured_at >= @start_at
      { account_id: account.id, display_name: account.display_name, has_snapshot: has_snapshot }
        .merge(yield(has_snapshot ? snapshots : []))
    end

    def comparison(snapshots)
      ending = snapshots.first
      starting = snapshots.find { |snapshot| snapshot.captured_at < @start_at } || snapshots.last
      [ (starting unless starting == ending), ending ]
    end

    def page_comparison(snapshots, key)
      comparison(snapshots.select { |snapshot| Linkedin::Monitor.page(snapshot, key) })
    end

    def counts(start, finish)
      { start: start, end: finish, delta: (finish - start if finish && start) }
    end

    def linkedin_report(snapshots)
      start, finish = page_comparison(snapshots, "dashboard").map do |snapshot|
        Linkedin::DashboardParser.new(Linkedin::Monitor.page(snapshot, "dashboard")&.fetch("text"))
      end
      previous_metrics = start.metrics
      metrics = finish.metrics.to_h do |key, metric|
        [ key, counts(previous_metrics[key][:value], metric[:value]).merge(label: metric[:label]) ]
      end
      posts = weekly_posts(snapshots)

      {
        metrics: metrics, network: weekly_network(snapshots), newsletters: weekly_newsletters(snapshots),
        posts: posts, weekly_goal: { posted: posts.any?, linkedin_weekly: finish.weekly }
      }
    end

    def weekly_network(snapshots)
      start, finish = page_comparison(snapshots, "network").map do |snapshot|
        Linkedin::NetworkParser.new(snapshot&.data&.fetch("pages", nil), nil).to_h
      end
      counts_by_key = Linkedin::Monitor::NETWORK_SERIES_KEYS.index_with { |key| counts(start[key], finish[key]) }
      data = snapshots.first&.data
      nav_badges = data["nav_badges"] if data.is_a?(Hash)
      badges = Linkedin::NetworkParser.new(nil, nav_badges).to_h
      counts_by_key.merge(badges.slice(:unread_messages, :unread_notifications))
    end

    def weekly_newsletters(snapshots)
      start, finish = page_comparison(snapshots, "newsletters").map do |snapshot|
        Linkedin::NewsletterParser.new(snapshot&.data&.fetch("pages", nil)).to_h[:newsletters]
      end
      previous = start.index_by { |entry| entry[:name] }
      finish.map do |entry|
        before = previous.dig(entry[:name], :subscribers)
        after = entry[:subscribers]
        entry.slice(:name, :role).merge(start_subscribers: before, end_subscribers: after, delta: counts(before, after)[:delta])
      end
    end

    def weekly_posts(snapshots)
      snapshots.flat_map do |snapshot|
        page = Linkedin::Monitor.page(snapshot, "activity")
        next [] unless page

        Linkedin::ActivityParser.new(page["text"], page["links"]).posts.select do |post|
          post[:posted_at] && (@start_at...@cutoff).cover?(post[:posted_at])
        end
      end.uniq { |post| post[:activity_id] }.sort_by { |post| post[:posted_at] }.reverse.map do |post|
        post.slice(:title, :kind, :posted_at, :impressions).merge(url: post[:article_url] || post[:post_url])
      end
    end

    def naver_report(snapshots)
      start, finish = comparison(snapshots.select do |snapshot|
        snapshot.data.is_a?(Hash) && snapshot.data["people"].is_a?(Hash) && !snapshot.data["people"].key?("error")
      end)
      changes = start ? NaverPeople::Differ.new(start.data, finish.data).changes : []
      scores = [ start, finish ].map { |snapshot| NaverPeople::Presenter.new(snapshot.data).completeness_score if snapshot }

      { changes: changes, completeness: counts(*scores), applications: weekly_applications(snapshots) }
    end

    def weekly_applications(snapshots)
      start, finish = Array.new(2) { { "applications" => {} } }
      APPLICATION_STATUSES.each_key do |status|
        valid = snapshots.select do |snapshot|
          data = snapshot.data
          data.is_a?(Hash) && data["applications"].is_a?(Hash) && data["applications"].key?(status) &&
            !NaverPeople::Applications.new(data).errors.key?(status)
        end
        before, after = comparison(valid)
        start["applications"][status] = before.data["applications"][status] if before
        finish["applications"][status] = after.data["applications"][status] if after
      end
      applications = NaverPeople::Applications.new(finish)
      counts_by_status = APPLICATION_STATUSES.to_h do |status, key|
        [ key, (applications.public_send(key).size if finish["applications"].key?(status)) ]
      end
      counts_by_status.merge(changes: applications.changes_from(start))
    end

    def value_text(value, suffix = "")
      value.nil? ? "자료 없음" : "#{value}#{suffix}"
    end

    def count_text(value, delta)
      return "자료 없음" if value.nil?

      return "#{value} (변화 없음)" if delta&.zero?

      "#{value} (#{delta.nil? ? '자료 없음' : format('%+d', delta)})"
    end

    def linkedin_lines(account)
      lines = account[:metrics].values.map { |row| "#{row[:label]} #{count_text(row[:end], row[:delta])}" }
      account[:network].each do |key, row|
        value = row.is_a?(Hash) ? count_text(row[:end], row[:delta]) : value_text(row)
        lines << "#{NETWORK_LABELS.fetch(key)} #{value}"
      end
      account[:newsletters].each do |row|
        lines << "뉴스레터 #{row[:name]} 구독자 #{count_text(row[:end_subscribers], row[:delta])}"
      end
      lines << "이번 주 게시물이 없습니다." if account[:posts].empty?
      account[:posts].each do |post|
        date = post[:posted_at].in_time_zone(TIME_ZONE).to_date
        lines << "#{date} · #{post[:title].presence || '자료 없음'} · 노출 #{value_text(post[:impressions])}"
      end
      goal = account[:weekly_goal]
      lines << "주간 목표 · 이번 주 게시 #{goal[:posted] ? '달성' : '미달성'}"
      weekly = goal[:linkedin_weekly]
      statuses = { true => "달성", false => "미달성", nil => "자료 없음" }
      lines << "LinkedIn 주간 목표 · 게시 #{statuses[weekly&.dig(:posted)]} · 댓글 #{statuses[weekly&.dig(:commented)]}"
    end

    def naver_lines(account)
      completeness = account[:completeness]
      lines = [ "완성도 #{value_text(completeness[:start], '%')} → #{value_text(completeness[:end], '%')}" ]
      lines << "이번 주 변경이 없습니다." if account[:changes].empty?
      account[:changes].each do |change|
        lines << "#{change[:label]} · #{value_text(change[:before].presence)} → #{value_text(change[:after].presence)}"
      end
      applications = account[:applications]
      APPLICATION_LABELS.each { |key, label| lines << "신청 #{label} #{value_text(applications[key], '건')}" }
      applications[:changes].each do |change|
        lines << "#{APPLICATION_CHANGE_LABELS.fetch(change[:kind])} · #{value_text(change[:item])} · #{value_text(change[:before].presence)} → #{value_text(change[:after].presence)}"
      end
      lines
    end
  end
end
