class ImageAutoTag < ApplicationRecord
  validates :image_url, :content_type, :content_id, :tags, :categories, :confidence, :model, presence: true

  scope :for_tenant, ->(tid = 1) { where(tenant_id: tid) }

  def tags_list
    JSON.parse(tags || "[]") rescue []
  end

  def categories_list
    JSON.parse(categories || "[]") rescue []
  end

  def objects_list
    JSON.parse(objects || "[]") rescue []
  end
end
