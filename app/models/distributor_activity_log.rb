class DistributorActivityLog < ApplicationRecord
  belongs_to :distributor

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }
end
