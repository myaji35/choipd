class NaverPeopleSubmission < ApplicationRecord
  STATUSES = %w[preparing filled failed submitted cancelled].freeze
  CANCELLABLE_STATUSES = %w[filled failed].freeze
  STATUS_LABELS = {
    "preparing" => "입력 중", "filled" => "입력 완료·대표님 제출 대기", "failed" => "실패",
    "submitted" => "제출함", "cancelled" => "취소"
  }.freeze

  belongs_to :profile_account

  serialize :items, coder: JSON, type: Array
  serialize :filled_items, coder: JSON, type: Array
  serialize :manual_items, coder: JSON, type: Array

  validates :status, inclusion: { in: STATUSES }
end
