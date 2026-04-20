# Identity Markdown Parser — Next.js src/lib/identity/parser.ts (471 lines) 포팅
# 단계적 변환: Phase 1 = 핵심 섹션 추출 + 표/불릿 처리. LLM 미사용.
class IdentityParser
  REQUIRED_FIELDS = %i[agenda tone keywords target usp].freeze

  SECTION_ALIASES = {
    agenda: %w[아젠다 비전 vision agenda 슬로건 slogan 한\ 줄\ 소개 mission 미션 퍼스널\ 슬로건 브랜드\ 아이덴티티 핵심\ 정체성],
    tone: %w[톤 톤\ 앤\ 매너 톤앤매너 tone 보이스 voice 어조 말투 화법 전문\ 스타일],
    keywords: %w[키워드 keywords 핵심\ 키워드 태그 tags 핵심어 전문성\ 키워드 전문\ 영역 전문\ 분야],
    target: %w[타겟 대상 target audience 오디언스 고객 타겟\ 고객 타깃 타겟팅],
    usp: %w[차별점 usp 강점 핵심\ 가치 value\ proposition 경쟁\ 우위 고유\ 가치 활동\ 특징 차별화],
    anti_patterns: %w[피해야 anti avoid 안티\ 패턴 금지 지양]
  }.freeze

  TABLE_KEY_ALIASES = {
    agenda: %w[퍼스널\ 슬로건 슬로건 아젠다 비전 mission 미션 한\ 줄\ 소개 핵심\ 정체성],
    hero_copy: %w[퍼스널\ 슬로건 슬로건 캐치프레이즈 tagline],
    tone: %w[톤앤매너 톤\ 앤\ 매너 톤 voice 어조 화법 전문\ 스타일 스타일],
    keywords: %w[핵심\ 키워드 키워드 전문\ 영역 전문\ 분야 전문성 태그],
    target: %w[타겟 타겟\ 고객 대상 audience 오디언스],
    usp: %w[핵심\ 가치 차별점 강점 usp 활동\ 특징 고유\ 가치 경쟁\ 우위]
  }.freeze

  def self.parse(md)
    new(md).parse
  end

  def initialize(md)
    @md = (md || "").to_s
    @bytes = @md.bytesize
  end

  def parse
    sections = split_sections(@md)
    table_kv = extract_table_kv(@md)

    result = {
      agenda: pick_text(sections, table_kv, :agenda),
      tone: pick_list(sections, table_kv, :tone),
      keywords: pick_list(sections, table_kv, :keywords),
      target: pick_list(sections, table_kv, :target),
      usp: pick_list(sections, table_kv, :usp),
      anti_patterns: pick_list(sections, nil, :anti_patterns),
      hero_copy: pick_text(sections, table_kv, :hero_copy),
      hashtags: extract_hashtags(@md),
      mentions: extract_mentions(@md),
      sections: sections.reject { |s| s[:title] == "__intro__" }.map { |s|
        { title: s[:title], preview: preview_for(s[:body]) }
      },
      summary: build_summary(sections),
      raw_bytes: @bytes,
      parsed_at: Time.current.iso8601
    }

    missing = REQUIRED_FIELDS.select { |f|
      v = result[f]
      v.nil? || (v.is_a?(Array) && v.empty?) || (v.is_a?(String) && v.strip.empty?)
    }
    result[:missing] = missing.map(&:to_s)
    result[:completeness] = ((REQUIRED_FIELDS.size - missing.size) * 100.0 / REQUIRED_FIELDS.size).round
    result
  end

  private

  def split_sections(md)
    sections = []
    current = nil
    md.each_line do |raw|
      line = raw.chomp
      if (h = line.match(/\A(#{1,4})\s+(.+?)\s*\z/) || line.match(/\A(#{1,4})\s+(.+?)\s*\z/))
        # heading match
      end
      m = line.match(/\A(#+)\s+(.+?)\s*\z/)
      if m && m[1].length.between?(1, 4)
        sections << current if current
        current = { title: m[2].strip, body: +"", level: m[1].length }
      elsif current
        current[:body] << line << "\n"
      else
        current = { title: "__intro__", body: line + "\n", level: 0 }
      end
    end
    sections << current if current
    sections
  end

  def extract_table_kv(md)
    kv = {}
    md.each_line do |line|
      next unless line.include?("|")
      parts = line.split("|").map(&:strip).reject(&:empty?)
      next if parts.size < 2
      next if parts.first.match?(/\A[-:]+\z/)  # separator row
      key = parts[0].downcase
      val = parts[1..].join(" | ")
      kv[key] = val
    end
    kv
  end

  def pick_text(sections, table_kv, field)
    aliases = (TABLE_KEY_ALIASES[field] || []) + (SECTION_ALIASES[field] || [])
    if table_kv
      table_kv.each do |k, v|
        return v if aliases.any? { |a| k.include?(a.downcase) }
      end
    end
    sec = find_section(sections, field)
    return nil unless sec
    body = sec[:body].strip
    return nil if body.empty?
    body.lines.first&.strip&.gsub(/\A[-*•]\s*/, "")
  end

  def pick_list(sections, table_kv, field, max: 8)
    aliases = (TABLE_KEY_ALIASES[field] || []) + (SECTION_ALIASES[field] || [])
    if table_kv
      table_kv.each do |k, v|
        if aliases.any? { |a| k.include?(a.downcase) }
          return split_list(v).first(max)
        end
      end
    end
    sec = find_section(sections, field)
    return [] unless sec
    extract_bullets(sec[:body], max)
  end

  def find_section(sections, field)
    aliases = SECTION_ALIASES[field] || []
    sections.find { |s|
      title = s[:title].downcase
      aliases.any? { |a| title.include?(a.downcase) }
    }
  end

  def extract_bullets(body, max)
    body.lines.map(&:strip).reject(&:empty?)
        .select { |l| l.start_with?("-", "*", "•", "1.", "2.", "3.") || l.include?(",") }
        .map { |l| l.gsub(/\A[-*•\d.]+\s*/, "").strip }
        .flat_map { |l| l.include?(",") ? l.split(",").map(&:strip) : [l] }
        .reject(&:empty?)
        .uniq
        .first(max)
  end

  def split_list(val)
    val.split(/[,、，·•\/]/).map(&:strip).reject(&:empty?)
  end

  def extract_hashtags(md)
    md.scan(/#[\p{Hangul}\w]+/).uniq.first(20)
  end

  def extract_mentions(md)
    md.scan(/@[\p{Hangul}\w]+/).uniq.first(20)
  end

  def preview_for(body)
    lines = body.lines.map(&:strip).reject(&:empty?).first(3)
    lines.join(" ").gsub(/\s+/, " ")[0, 200]
  end

  def build_summary(sections)
    intro = sections.find { |s| s[:title] == "__intro__" }
    src = intro&.dig(:body) || sections.first&.dig(:body) || ""
    src.lines.map(&:strip).reject(&:empty?).first(2).join(" ")[0, 240]
  end
end
