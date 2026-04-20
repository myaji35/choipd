class Lead < ApplicationRecord
  validates :email, presence: true,
                    uniqueness: { scope: :tenant_id, case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  before_create { self.subscribed_at = Time.current }
  before_save { self.email = email.downcase }
end
