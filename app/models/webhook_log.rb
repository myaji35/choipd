class WebhookLog < ApplicationRecord
  belongs_to :webhook

  STATUSES = %w[success failed retrying].freeze
  validates :status, inclusion: { in: STATUSES }
end
