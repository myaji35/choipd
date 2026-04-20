class Work < ApplicationRecord
  has_one_attached :image

  enum :category, { gallery: "gallery", press: "press", book: "book", sketch: "sketch" }, prefix: true

  validates :title, presence: true
  validates :category, presence: true

  scope :gallery, -> { where(category: "gallery") }
  scope :press, -> { where(category: "press") }
  scope :recent, -> { order(created_at: :desc) }
end
