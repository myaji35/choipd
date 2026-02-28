class DistributorResource < ApplicationRecord
  has_one_attached :file

  CATEGORIES = %w[marketing training template guide].freeze
  PLANS = %w[basic standard premium].freeze

  validates :title, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :by_plan, ->(plan) { where(required_plan: plan) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(created_at: :desc) }

  def increment_download_count!
    increment!(:download_count)
  end
end
