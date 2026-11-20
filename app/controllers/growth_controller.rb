class GrowthController < ApplicationController
  layout "impd"
  def show
    @now = Time.current
    new_members = Member.where(created_at: @now.beginning_of_month..@now)
    @new_member_count = new_members.count
    previous_month = @now.prev_month
    @new_member_delta = @new_member_count - Member.where(created_at: previous_month.beginning_of_month...@now.beginning_of_month).count
    @recent_professions = new_members.order(created_at: :desc, id: :desc).limit(3).map(&:profession_label)
    @weeks = params[:weeks] == "26" ? 26 : 12
    @series = BrandOps::WeeklyStats.platform(weeks: @weeks, now: @now)
    @summary = BrandOps::WeeklyStats.summary(@series)
    ids = ProConsent.granted.where(consent_type: "socialdoctors_exposure").select(:owner_id)
    @members = Member.where(status: "approved").where(id: ids).order(Arel.sql("CASE WHEN slug = 'kang-seung-sig' THEN 0 ELSE 1 END"), :name).to_a
    @member_series = @members.index_with { |m| BrandOps::WeeklyStats.member(m, now: @now) }
    @members = @members.sort_by { |m| [ m.slug == "kang-seung-sig" ? 0 : 1, -@member_series[m].last(4).sum { |row| %i[visits inquiries reviews posts sns_posts].sum { |key| row[key].to_i } }, m.name ] }.first(6)
  end
end
