class SubscriptionPlan < ApplicationRecord
  has_many :distributors, foreign_key: :subscription_plan, primary_key: :name

  validates :name, presence: true, uniqueness: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  PLANS = %w[basic standard premium].freeze
end
