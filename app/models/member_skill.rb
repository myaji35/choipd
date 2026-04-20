class MemberSkill < ApplicationRecord
  belongs_to :member
  belongs_to :skill

  LEVELS = %w[novice intermediate expert].freeze
  SOURCES = %w[self document review verified].freeze

  validates :level, inclusion: { in: LEVELS }
  validates :source, inclusion: { in: SOURCES }
  validates :weight, numericality: { in: 0..100 }
  validates :member_id, uniqueness: { scope: :skill_id }
end
