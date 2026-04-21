class AbTestParticipant < ApplicationRecord
  belongs_to :ab_test
  validates :session_id, :variant, presence: true

  def convert!(value: nil)
    update!(converted: true, conversion_value: value, converted_at: Time.current)
  end
end
