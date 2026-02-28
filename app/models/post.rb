class Post < ApplicationRecord
  enum :category, { notice: "notice", review: "review", media: "media" }, prefix: true

  validates :title, presence: true
  validates :content, presence: true

  scope :published, -> { where(published: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(created_at: :desc) }
end
