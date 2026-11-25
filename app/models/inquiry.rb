class Inquiry < ApplicationRecord
  enum :inquiry_type, { b2b: "b2b", contact: "contact" }, prefix: true
  enum :status, {
    pending: "pending",
    in_progress: "in_progress",
    contacted: "contacted",
    resolved: "resolved",
    closed: "closed"
  }, prefix: true

  validates :name, presence: { message: "이름을 입력해 주세요." }
  validates :email, presence: { message: "이메일을 입력해 주세요." },
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true, message: "이메일 주소 형식이 올바르지 않습니다." }
  validates :message, presence: { message: "문의 내용을 입력해 주세요." }
  validates :inquiry_type, presence: { message: "문의 유형을 선택해 주세요." }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(s) { where(status: s) }
end
