class SnsPostHistory < ApplicationRecord
  belongs_to :sns_scheduled_post

  scope :recent, -> { order(created_at: :desc) }
end
