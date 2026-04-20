class MemberService < ApplicationRecord
  belongs_to :member
  validates :title, presence: true
  scope :active, -> { where(is_active: 1) }
  scope :sorted, -> { order(:sort_order, :created_at) }
end
