class Admin::MemberSkillsController < Admin::BaseController
  before_action :set_member

  def index
    skills = @member.member_skills.includes(:skill).order(weight: :desc)
    render json: {
      success: true,
      skills: skills.map { |ms|
        {
          id: ms.id,
          skill_id: ms.skill_id,
          name: ms.skill.canonical_name,
          category: ms.skill.category,
          axis: ms.skill.axis,
          level: ms.level,
          weight: ms.weight,
          source: ms.source,
          years: ms.years_experience,
          verified_at: ms.verified_at
        }
      }
    }
  end

  private

  def set_member
    @member = Member.for_tenant.find_by(slug: params[:member_id]) || Member.for_tenant.find(params[:member_id])
  end
end
