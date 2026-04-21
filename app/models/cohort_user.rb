class CohortUser < ApplicationRecord
  belongs_to :cohort
  validates :user_id, presence: true
end
