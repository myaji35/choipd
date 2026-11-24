class LinkedinNewsletterDraft < ApplicationRecord
  STATUSES = %w[draft archived publishing published failed].freeze

  belongs_to :profile_account

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 100_000 }
  validates :status, inclusion: { in: STATUSES }

  before_save :clear_approval

  def publishing_locked? = status.in?(%w[publishing published]) || published_at.present?

  private

  def clear_approval
    if will_save_change_to_title? || will_save_change_to_body? || will_save_change_to_newsletter_name?
      self.approved_at = nil
    end
  end
end
