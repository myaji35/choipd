class Skill < ApplicationRecord
  has_many :member_skills, dependent: :destroy
  has_many :members, through: :member_skills

  CATEGORIES = %w[hard meta context].freeze
  AXES = %w[expertise communication marketing operations data network].freeze

  validates :canonical_name, presence: true, uniqueness: { scope: :tenant_id }
  validates :category, inclusion: { in: CATEGORIES }
  validates :axis, inclusion: { in: AXES, allow_nil: true }

  def aliases_list
    JSON.parse(aliases || "[]") rescue []
  end
end
