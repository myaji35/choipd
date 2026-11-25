module ScanOrganizer
  def self.enabled? = ENV["IMPD_SCAN_ORGANIZER_ENABLED"] == "1"

  def self.ai_provider_for(setting)
    AiProviders.for(setting.ai_provider)
  end

  def self.cloud_for(setting)
    Cloud::GoogleDrive.new(refresh_token: setting.cloud_refresh_token, scan_folder_id: setting.scan_folder_id)
  end
end
