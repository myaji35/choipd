require "digest"

class MemberDocument < ApplicationRecord
  belongs_to :member

  CATEGORIES = %w[
    bio portfolio curriculum awards interview other
    career certificate review course press
  ].freeze

  validates :filename, :content_md, :content_hash, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :content_hash, uniqueness: { scope: :member_id }

  before_validation :compute_hash_and_size
  before_save :ensure_uploaded_at

  def tags_list
    JSON.parse(tags || "[]") rescue []
  end

  def entities
    JSON.parse(extracted_entities || "{}") rescue {}
  end

  private

  def compute_hash_and_size
    return if content_md.blank?
    self.content_hash ||= Digest::SHA256.hexdigest(content_md)
    self.size_bytes ||= content_md.bytesize
  end

  def ensure_uploaded_at
    if uploaded_at.blank? || uploaded_at < Time.utc(2000)
      self.uploaded_at = Time.current
    end
  end
end
