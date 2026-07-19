class MemberFaq < ApplicationRecord
  belongs_to :member

  validates :question, :answer, presence: true

  scope :published, -> { where(is_published: 1) }
  scope :sorted, -> { order(:sort_order, :id) }
end
