class MemberAdmin::BrandsController < MemberAdmin::BaseController
  def show
    @brands = Brand.where(member_id: @member.id).order(:name)
  end
end
