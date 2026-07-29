class LayoutPreset
  LAYOUT_PRESETS = [
    { key: "editorial", name: "에디토리얼", desc: "기본값 · 세로 스크롤 스토리텔링" },
    { key: "grid",      name: "그리드",     desc: "카드 타일 · 한눈에 보는 링크·사진·서비스" },
  ].freeze

  def self.find(key)
    LAYOUT_PRESETS.find { |preset| preset[:key] == key }
  end
end
