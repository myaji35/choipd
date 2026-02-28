class Course < ApplicationRecord
  has_one_attached :thumbnail

  enum :course_type, { online: "online", offline: "offline", b2b: "b2b" }, prefix: true

  validates :title, presence: true
  validates :course_type, presence: true

  scope :published, -> { where(published: true) }
  scope :by_type, ->(type) { where(course_type: type) }
  scope :recent, -> { order(created_at: :desc) }
end
