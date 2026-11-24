class LinkedinNewsletterDraft < ApplicationRecord
  STATUSES = %w[draft archived].freeze

  belongs_to :profile_account

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 100_000 }
  validates :status, inclusion: { in: STATUSES }
end
