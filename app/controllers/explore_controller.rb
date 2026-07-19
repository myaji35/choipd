class ExploreController < ApplicationController
  layout "impd"

  def index
    base = Member.active.where(status: "approved")
    base = base.where(profession: params[:profession]) if params[:profession].present? && Member::PROFESSIONS.include?(params[:profession])
    base = base.where(region: params[:region]) if params[:region].present?

    @members = base
      .order(Arel.sql("CASE WHEN is_featured = 1 THEN 0 ELSE 1 END"), featured_order: :asc, created_at: :desc)
      .limit(60)
    @professions = base.distinct.pluck(:profession).compact
    @regions = base.where.not(region: [ nil, "" ]).distinct.pluck(:region).sort
    @current_profession = params[:profession]
    @current_region = params[:region]
  end
end
