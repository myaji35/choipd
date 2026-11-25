module BrandOps
  BOT_UA = /bot|crawler|spider|slurp|headless|preview|facebookexternalhit/i

  class WeeklyStats
    KEYS = %i[members_total members_active visits inquiries reviews posts sns_posts].freeze
    ZONE = ActiveSupport::TimeZone["Asia/Seoul"]

    def self.platform(weeks: 12, now: Time.current)
      imported("platform", weeks) || new(weeks, now).series
    end

    def self.member(member, weeks: 12, now: Time.current)
      imported("member", weeks, member.slug) || new(weeks, now, member).series
    end

    def self.imported(key, weeks, slug = nil)
      return unless ENV["BRAND_OPS_IMPORT"].present? && Rails.env.development?
      path = Rails.root.join("tmp/brand_ops_import.json")
      return unless path.file?
      data = JSON.parse(path.read)
      return if slug && data["slug"] != slug
      data.fetch(key).last(weeks).map { |row| row.symbolize_keys.merge(week_start: Date.iso8601(row.fetch("week_start"))) }
    end

    def self.summary(series)
      current, previous = series.last || {}, series[-2] || {}
      KEYS.index_with { |key| { value: current.fetch(key, 0), delta: current.fetch(key, 0) - previous.fetch(key, 0) } }
    end

    def self.sns_publications(member_ids, range)
      owner_id = Arel.sql("COALESCE(sns_scheduled_posts.member_id, brands.member_id, sns_accounts.member_id)")
      posts = SnsScheduledPost.left_joins(:sns_account, brand_channel: :brand).where("#{owner_id} IN (?)", member_ids)
      histories = SnsPostHistory.where(status: %w[success published], created_at: range)
      recorded = posts.joins(:sns_post_histories).merge(histories).pluck(owner_id, "sns_post_histories.created_at")

      publication_time = Arel::Nodes::NamedFunction.new("COALESCE", [ SnsScheduledPost.arel_table[:published_at], SnsScheduledPost.arel_table[:scheduled_at] ])
      unrecorded = posts.where(status: "published").or(posts.where.not(published_at: nil))
        .where(publication_time.between(range))
        .where.not(id: histories.where.not(sns_scheduled_post_id: nil).select(:sns_scheduled_post_id))
        .pluck(owner_id, :published_at, :scheduled_at)

      recorded + unrecorded.map { |id, published_at, scheduled_at| [ id, published_at || scheduled_at ] }
    end

    def initialize(weeks, now, member = nil)
      @weeks, @now, @member = weeks.to_i.clamp(1, 260), now.in_time_zone(ZONE), member
    end

    def series
      members = Member.where.not(status: %w[rejected withdrawn])
      members = members.where(id: @member.id) if @member
      people = members.to_a
      ids = people.map(&:id)
      start_date = @now.to_date.beginning_of_week - 7 * (@weeks - 1)
      from = ZONE.local(start_date.year, start_date.month, start_date.day)
      posts = MemberPost.where(member_id: ids, is_published: 1).where("published_at >= ? AND published_at <= ?", from - 30.days, @now).pluck(:member_id, :published_at)
      inquiries = MemberInquiry.where(member_id: ids).where("created_at >= ? AND created_at <= ?", from - 30.days, @now).to_a
      reviews = MemberReview.where(member_id: ids, is_approved: 1).where(created_at: from..@now).pluck(:member_id, :created_at)
      sns = self.class.sns_publications(ids, (from - 30.days)..@now)
      by_slug = people.index_by(&:slug)
      visits = AnalyticsEvent.where(event_name: "page_view", created_at: from..@now).filter_map do |event|
        slug = event.page_path.to_s.split("/")[1]
        person = by_slug[slug]
        next unless person && (event.page_path == "/#{slug}" || event.page_path.start_with?("/#{slug}/"))
        next if event.user_agent.to_s.match?(BOT_UA) || event.user_type.to_s.downcase.in?(%w[admin adminuser admin_user])
        next if event.user_id.present? && event.user_id.to_s == person.id.to_s && event.user_type.to_s.downcase.in?(%w[member pd])
        [ person.id, event.created_at ]
      end
      @weeks.times.map do |i|
        day = start_date + 7 * i
        first = ZONE.local(day.year, day.month, day.day)
        last = [ first + 7.days, @now + 0.000001 ].min
        active_from = last - 30.days
        within = ->(time) { time && time >= first && time < last }
        active = ->(time) { time && time >= active_from && time < last }
        active_ids = posts.filter_map { |id, time| id if active.call(time) } + sns.filter_map { |id, time| id if active.call(time) }
        active_ids += inquiries.filter_map { |inq| inq.member_id if inq.is_read.to_i == 1 && active.call(inq.has_attribute?(:updated_at) ? inq.updated_at : inq.created_at) }
        active_ids += people.filter_map { |person| person.id if active.call(person.updated_at) || active.call(person.last_sign_in_at) }
        { week_start: day, members_total: people.count { |p| p.created_at < last }, members_active: active_ids.uniq.count { |id| people.any? { |p| p.id == id && p.created_at < last } }, visits: visits.count { |_, t| within.call(t) }, inquiries: inquiries.count { |inq| within.call(inq.created_at) }, reviews: reviews.count { |_, t| within.call(t) }, posts: posts.count { |_, t| within.call(t) }, sns_posts: sns.count { |_, t| within.call(t) } }
      end
    end
  end
end
