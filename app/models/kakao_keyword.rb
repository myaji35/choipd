class KakaoKeyword < ApplicationRecord
  CATEGORIES = %w[refund complaint legal custom general].freeze

  validates :keyword, :owner_id, presence: true
  validates :keyword, uniqueness: { scope: :owner_id }
  validates :category, inclusion: { in: CATEGORIES }
  validates :weight, inclusion: { in: 0..100 }

  scope :for_owner, ->(oid) { where(owner_id: oid) }
  scope :active, -> { where(is_active: true) }

  # 기본 긴급 키워드 사전
  DEFAULT_KEYWORDS = [
    { keyword: "환불", category: "refund", weight: 80 },
    { keyword: "취소", category: "refund", weight: 70 },
    { keyword: "법적", category: "legal", weight: 95 },
    { keyword: "고소", category: "legal", weight: 100 },
    { keyword: "신고", category: "legal", weight: 90 },
    { keyword: "사기", category: "complaint", weight: 95 },
    { keyword: "최악", category: "complaint", weight: 70 },
    { keyword: "별로", category: "complaint", weight: 40 },
    { keyword: "실망", category: "complaint", weight: 60 }
  ].freeze

  def self.seed_for!(owner_id, tenant_id: 1)
    DEFAULT_KEYWORDS.each do |k|
      find_or_create_by!(owner_id: owner_id, keyword: k[:keyword]) do |kw|
        kw.tenant_id = tenant_id
        kw.category = k[:category]
        kw.weight = k[:weight]
      end
    end
  end
end
