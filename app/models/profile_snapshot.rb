class ProfileSnapshot < ApplicationRecord
  belongs_to :profile_account
  serialize :data, coder: JSON
  validates :captured_at, presence: true
  scope :recent, -> { order(captured_at: :desc) }
end
