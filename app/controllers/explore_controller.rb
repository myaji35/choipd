class ExploreController < ApplicationController
  layout "impd"

  def index
    available = Member.active.where(status: "approved")
    @total_count = available.count
    @professions = available.distinct.pluck(:profession).compact
    @regions = available.where.not(region: [ nil, "" ]).distinct.pluck(:region).sort
    base = available
    base = base.where(profession: params[:profession]) if params[:profession].present? && Member::PROFESSIONS.include?(params[:profession])
    base = base.where(region: params[:region]) if params[:region].present?

    @members = base
      .order(Arel.sql("CASE WHEN is_featured = 1 THEN 0 ELSE 1 END"), featured_order: :asc, created_at: :desc)
      .limit(60)
    @current_profession = params[:profession]
    @current_region = params[:region]
  end
end
