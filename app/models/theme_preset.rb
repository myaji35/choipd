class ThemePreset
  THEME_PRESETS = [
    { key: "editorial", name: "잡지형", desc: "기본 · 차분한 잡지 느낌", accent: "#3a2af0", ink: "#0f0d0b", paper: "#efece4" },
    { key: "clean", name: "깔끔한", desc: "사업·상담용 · 파란 포인트", accent: "#00A1E0", ink: "#16325C", paper: "#ffffff" },
    { key: "warm", name: "따뜻한", desc: "공방·강사 · 따뜻한 크림색", accent: "#ff5a1f", ink: "#1a1a1a", paper: "#fbf8f1" },
    { key: "nightlab", name: "어두운 밤", desc: "어두운 배경 · 밝은 포인트", accent: "#22d3ee", ink: "#efece4", paper: "#0f172a" },
    { key: "polaroid", name: "사진 앨범", desc: "일상 사진 중심 · 부드러운 초록", accent: "#2a9d8f", ink: "#0f0d0b", paper: "#fff8e7" }
  ].freeze

  def self.find(key)
    THEME_PRESETS.find { |preset| preset[:key] == key }
  end
end
