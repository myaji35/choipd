class HeroImage < ApplicationRecord
  has_one_attached :image

  validates :alt_text, presence: true

  scope :active, -> { where(is_active: true).order(display_order: :asc) }
  scope :ordered, -> { order(display_order: :asc) }

  def self.activate(id)
    where.not(id: id).update_all(is_active: false)
    find(id).update!(is_active: true)
  end
end
