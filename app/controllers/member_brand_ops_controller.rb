class MemberBrandOpsController < ApplicationController
  layout "impd"
  def show
    @member = Member.find_by!(slug: params[:slug], status: "approved")
    @exposure = ProConsent.has_consent?(owner_id: @member.id, type: "socialdoctors_exposure")
    raise ActiveRecord::RecordNotFound unless @exposure
    @now = Time.current
    @series = BrandOps::WeeklyStats.member(@member, now: @now)
    @brand = Brand.where(member_id: @member.id, published: true).first
    @posts = @member.member_posts.published.where.not(published_at: nil).where("published_at <= ?", @now).recent.limit(5)
    @townin = ProConsent.has_consent?(owner_id: @member.id, type: "townin_local_ads")
  end
end
