class MemberBooking < ApplicationRecord
  belongs_to :member

  validates :external_url,
            presence: true,
            format: { with: /\Ahttps?:\/\/[^\s]+\z/i, message: "은(는) http:// 또는 https://로 시작해야 합니다" }

  # member_bookings 테이블에 timestamps 컬럼이 없어 id 역순으로 최신순 정렬(등록순 = id순).
  scope :recent, -> { order(id: :desc) }
end
