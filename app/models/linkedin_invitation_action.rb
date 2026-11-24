class LinkedinInvitationAction < ApplicationRecord
  ACTIONS = %w[accept ignore].freeze

  belongs_to :profile_account

  validates :action, inclusion: { in: ACTIONS }
  validates :status, inclusion: { in: %w[approved done failed] }
end
