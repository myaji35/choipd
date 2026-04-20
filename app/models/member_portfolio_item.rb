class MemberPortfolioItem < ApplicationRecord
  belongs_to :member
  validates :title, :media_url, presence: true
  scope :sorted, -> { order(:sort_order, :created_at) }
end
