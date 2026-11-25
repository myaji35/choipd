module ScanOrganizer
  def self.enabled? = ENV["IMPD_SCAN_ORGANIZER_ENABLED"] == "1"

  def self.ai_provider_for(setting)
    AiProviders.for(setting.ai_provider)
  end
end
