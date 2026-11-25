class LayoutPreset
  LAYOUT_PRESETS = [
    { key: "editorial", name: "길게 읽는 형", desc: "기본 · 위에서 아래로 읽는 소개" },
    { key: "grid",      name: "카드 모음형",     desc: "카드로 한눈에 · 링크·사진·서비스" }
  ].freeze

  def self.find(key)
    LAYOUT_PRESETS.find { |preset| preset[:key] == key }
  end
end
