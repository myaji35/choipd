class MemberAdmin::BrandsController < MemberAdmin::BaseController
  def show
    @series = BrandOps::WeeklyStats.member(@member)
    completed = @series.size > 1 ? @series[0...-1] : @series
    @chart_series = completed
    @current_week = @series.size > 1 ? @series.last : nil
    recent = completed.last(4)
    before = completed.last(8).first([ completed.size - recent.size, 4 ].min.clamp(0, 4))
    @four_week_stats = %i[visits inquiries posts sns_posts].index_with do |key|
      current = recent.sum { |row| row[key].to_i }
      previous = before.sum { |row| row[key].to_i }
      { value: current, delta: current - previous }
    end
    @four_week_range = [ recent.first[:week_start], recent.last[:week_start] + 6 ] if recent.any?
    now = Time.current.in_time_zone("Asia/Seoul")
    month = now.beginning_of_month..now
    @month_posts = MemberPost.where(member_id: @member.id, is_published: 1, published_at: month).count
    @month_sns_posts = BrandOps::WeeklyStats.sns_publications([@member.id], month).size
    @consented = ProConsent.has_consent?(owner_id: @member.id, type: "socialdoctors_exposure")
    @brands = @member.brands.personal_first
    @show_brand_channels = current_member&.id == @member.id
    @brands = @brands.includes(:brand_channels)
  end
end
