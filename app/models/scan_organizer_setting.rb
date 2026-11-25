class ScanOrganizerSetting < ApplicationRecord
  AI_PROVIDERS = %w[gemini openai anthropic].freeze
  SECRET_ATTRIBUTES = %i[ai_api_key].freeze
  RUN_FREQUENCIES = { "daily" => "매일", "weekly" => "매주" }.freeze

  belongs_to :member

  encrypts :ai_api_key
  self.filter_attributes += SECRET_ATTRIBUTES

  validates :cloud_provider, inclusion: { in: ->(_) { ScanOrganizer::Clouds.available_keys } }
  validates :run_frequency, inclusion: { in: RUN_FREQUENCIES.keys }
  validates :ai_provider, inclusion: { in: AI_PROVIDERS }, allow_nil: true

  def ai_key_last4
    super if ai_api_key.to_s.length >= 12
  end

  def ai_api_key=(value)
    self.ai_key_last4 = value.to_s.length >= 12 ? value.to_s.last(4) : nil
    super
  end

  def serializable_hash(options = nil)
    options = (options || {}).dup
    if options[:only]
      options[:only] = Array(options[:only]).map(&:to_s) - SECRET_ATTRIBUTES.map(&:to_s)
    end
    options[:except] = Array(options[:except]) + SECRET_ATTRIBUTES
    super(options).except(*SECRET_ATTRIBUTES.map(&:to_s))
  end
end
