class MemberAdmin::BrandsController < MemberAdmin::BaseController
  def show
    @series = BrandOps::WeeklyStats.member(@member)
    keys = %i[visits inquiries posts sns_posts]
    @four_week_stats = keys.index_with do |key|
      current = @series.last(4).sum { |row| row[key].to_i }
      previous = @series.last(8).first(4).sum { |row| row[key].to_i }
      { value: current, delta: current - previous }
    end
    now = Time.current.in_time_zone("Asia/Seoul")
    month = now.beginning_of_month..now
    @month_posts = MemberPost.where(member_id: @member.id, is_published: 1, published_at: month).count
    @month_sns_posts = SnsPostHistory.joins(:sns_scheduled_post).where(status: "success", sns_scheduled_posts: { member_id: @member.id }, created_at: month).count
    @consented = ProConsent.has_consent?(owner_id: @member.id, type: "socialdoctors_exposure")
    @brands = @member.brands.personal_first
    @show_brand_channels = current_member&.id == @member.id
    @brands = @brands.includes(:brand_channels) if @show_brand_channels
  end
end
