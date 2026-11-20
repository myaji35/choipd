class MemberAdmin::BrandsController < MemberAdmin::BaseController
  def show
    @series = BrandOps::WeeklyStats.member(@member)
    @consented = ProConsent.has_consent?(owner_id: @member.id, type: "socialdoctors_exposure")
    @brands = Brand.where(member_id: @member.id).order(:name)
  end
end
