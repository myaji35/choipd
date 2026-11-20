class GrowthController < ApplicationController
  layout "impd"
  def show
    @now = Time.current
    @weeks = params[:weeks] == "26" ? 26 : 12
    @series = BrandOps::WeeklyStats.platform(weeks: @weeks, now: @now)
    @summary = BrandOps::WeeklyStats.summary(@series)
    ids = ProConsent.granted.where(consent_type: "socialdoctors_exposure").select(:owner_id)
    @members = Member.where(status: "approved").where(id: ids).order(Arel.sql("CASE WHEN slug = 'kang-seung-sig' THEN 0 ELSE 1 END"), :name).to_a
    @member_series = @members.index_with { |m| BrandOps::WeeklyStats.member(m, now: @now) }
    @members = @members.sort_by { |m| [ m.slug == "kang-seung-sig" ? 0 : 1, -@member_series[m].last(4).sum { |row| %i[visits inquiries reviews posts sns_posts].sum { |key| row[key].to_i } }, m.name ] }.first(6)
  end
end
