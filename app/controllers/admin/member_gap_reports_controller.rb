class Admin::MemberGapReportsController < Admin::BaseController
  before_action :set_member

  def generate
    skills_count = @member.member_skills.count
    radar = {
      expertise: skills_count > 5 ? 75 : 50,
      communication: 60,
      marketing: skills_count > 3 ? 65 : 45,
      operations: 55,
      data: 40,
      network: @member.is_featured.to_i.positive? ? 70 : 50
    }
    median = { expertise: 55, communication: 60, marketing: 50, operations: 55, data: 45, network: 50 }
    top10 = { expertise: 90, communication: 85, marketing: 88, operations: 80, data: 78, network: 85 }

    gaps = radar.map { |axis, val|
      diff = top10[axis] - val
      next nil if diff < 10
      {
        severity: diff > 30 ? "high" : "medium",
        axis: axis,
        current: val,
        target: top10[axis],
        gap: diff,
        recommendation: "#{axis} 영역 보강 필요"
      }
    }.compact

    report = @member.member_gap_reports.create!(
      tenant_id: 1,
      profession: @member.profession || "custom",
      completeness_score: ((skills_count.to_f / 20) * 100).clamp(0, 100).to_i,
      radar_self: radar.to_json,
      radar_median: median.to_json,
      radar_top10: top10.to_json,
      gaps_json: gaps.to_json,
      opportunities_json: [].to_json,
      growth_path_json: [].to_json,
      peer_sample_size: 100
    )
    render json: { success: true, report: report.as_json }
  end

  private

  def set_member
    @member = Member.for_tenant.find_by(slug: params[:member_id]) || Member.for_tenant.find(params[:member_id])
  end
end
