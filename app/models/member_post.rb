class MemberPost < ApplicationRecord
  belongs_to :member
  validates :title, :content, presence: true
  scope :published, -> { where(is_published: 1) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
end
