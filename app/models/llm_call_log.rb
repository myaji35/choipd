# frozen_string_literal: true

class LlmCallLog < ApplicationRecord
  validates :status, presence: true
end
