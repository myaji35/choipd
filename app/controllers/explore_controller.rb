class ExploreController < ApplicationController
  include MemberCardData
  layout "impd"

  def index
    available = Member.publicly_visible
    @profession_groups = profession_groups(available)
    @total_count = @profession_groups.sum { |group| group[:count] }
    @regions = available.where.not(region: [nil, ""]).group(:region).count.sort.to_h
    @current_region = params[:region].presence
    @selected_profession = @profession_groups.find do |group|
      params[:profession].present? && (group[:key] == params[:profession] || group[:values].include?(params[:profession]))
    end
    @current_profession = @selected_profession&.fetch(:key)

    base = available
    base = base.where(profession: @selected_profession[:values]) if @selected_profession
    base = base.where(region: @current_region) if @current_region
    @members = base.order(FEATURED_FIRST, featured_order: :asc)
      .order(Arel.sql("CASE WHEN #{PROFILE_FILLED} THEN 0 ELSE 1 END"), created_at: :desc)
      .limit(61).to_a
    @more_members = @members.size > 60
    @members = @members.first(60)
    load_member_card_data(@members)
  end
end
