class ThemePreset
  THEME_PRESETS = [
    { key: "editorial", name: "에디토리얼", desc: "기본값 · Inter Tight + 세리프 이탤릭", accent: "#3a2af0", ink: "#0f0d0b", paper: "#efece4" },
    { key: "clean", name: "클린", desc: "명료한 사업용 · 시안 포인트", accent: "#00A1E0", ink: "#16325C", paper: "#ffffff" },
    { key: "warm", name: "따뜻한", desc: "공방/강사 · 크림 베이지", accent: "#ff5a1f", ink: "#1a1a1a", paper: "#fbf8f1" },
    { key: "nightlab", name: "나이트랩", desc: "크리에이터 다크 · 네온 포인트", accent: "#22d3ee", ink: "#efece4", paper: "#0f172a" },
    { key: "polaroid", name: "폴라로이드", desc: "일상 사진 중심 · 부드러운 그린", accent: "#2a9d8f", ink: "#0f0d0b", paper: "#fff8e7" },
  ].freeze

  def self.find(key)
    THEME_PRESETS.find { |preset| preset[:key] == key }
  end
end
