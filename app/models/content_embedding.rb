class ContentEmbedding < ApplicationRecord
  validates :content_type, :content_id, :embedding_model, :embedding, :text_content, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }

  def vector
    JSON.parse(embedding || "[]") rescue []
  end

  # 코사인 유사도 (간단 구현)
  def similarity_to(other_vector)
    a = vector; b = other_vector
    return 0 if a.empty? || b.empty? || a.size != b.size
    dot = a.zip(b).sum { |x, y| x * y }
    mag_a = Math.sqrt(a.sum { |x| x**2 })
    mag_b = Math.sqrt(b.sum { |y| y**2 })
    mag_a.zero? || mag_b.zero? ? 0 : dot / (mag_a * mag_b)
  end
end
