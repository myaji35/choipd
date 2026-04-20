class MemberInquiry < ApplicationRecord
  belongs_to :member
  validates :sender_name, :sender_email, :message, presence: true
  scope :unread, -> { where(is_read: 0) }
  scope :recent, -> { order(created_at: :desc) }
end
