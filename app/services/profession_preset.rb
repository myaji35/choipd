class ProfessionPreset
  DIR = Rails.root.join("config", "professions")

  def self.for(code)
    code = code.to_s.presence || "custom"
    return load(code) if Rails.env.development?

    @cache ||= {}
    @cache[code] ||= load(code)
  end

  def self.load(code)
    path = DIR.join("#{code}.json")
    path = DIR.join("custom.json") unless path.exist?
    JSON.parse(File.read(path))
  rescue => e
    Rails.logger.warn("[ProfessionPreset] #{code}: #{e.message}")
    {}
  end

  def self.label(code)
    self.for(code)["label"].presence || code.to_s
  end

  def self.value_cards(code)
    self.for(code)["value_cards"] || []
  end

  def self.cta(code)
    self.for(code)["cta"] || {}
  end
end
