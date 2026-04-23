# 회원별 디지털 명함 SVG.
# 카톡·SNS 공유 시 OG 이미지로 사용되는 1200x630 명함 디자인.
# 회원 페이지의 hero/직함/지역/QR 을 한 장에 통합.
#
# 왜 SVG 인가:
# - ImageMagick/libvips 의존 0 (rqrcode 도 순수 Ruby)
# - 텍스트가 벡터 → 해상도 무한대, 확대/축소 깨짐 없음
# - 파일 크기 작음 (PNG 대비 1/5 ~ 1/10)
# - 브라우저/카톡 OG 이미지로 동작 확인 필요. SVG 미지원 채널은 PNG 변환 후속 과제(P1).
class BusinessCardsController < ApplicationController
  PROFESSION_LABELS = {
    "insurance_agent" => "보험 설계사",
    "realtor"         => "공인중개사",
    "educator"        => "강사",
    "author"          => "작가",
    "shopowner"       => "자영업자",
    "freelancer"      => "프리랜서",
    "custom"          => "크리에이터",
  }.freeze

  def show
    member = Member.find_by(slug: params[:slug])
    head :not_found and return if member.blank? || member.status != "approved"

    svg = render_card_svg(member)

    expires_in 6.hours, public: true
    response.set_header("Content-Type", "image/svg+xml")
    render plain: svg, content_type: "image/svg+xml"
  rescue => e
    Rails.logger.error "[BusinessCard] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    head :internal_server_error
  end

  private

  def render_card_svg(member)
    name       = escape(member.name.to_s)
    profession = escape(PROFESSION_LABELS[member.profession.to_s] || "크리에이터")
    region     = escape(member.region.presence || "")
    bio        = escape(member.bio.to_s.gsub(/\s+/, " ").strip[0, 80])
    short_url  = short_url_for(member)
    short_url_display = escape(short_url.sub(%r{^https?://}, ""))
    qr_path    = qr_path_d(short_url)

    # 1200x630 — 카톡/페북/트위터 OG 표준.
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" width="1200" height="630">
        <defs>
          <style>
            .bg { fill: #efece4; }
            .ink { fill: #0f0d0b; }
            .accent { fill: #3a2af0; }
            .mono { font-family: "JetBrains Mono","SF Mono",ui-monospace,monospace; }
            .serif { font-family: "Noto Serif KR","Noto Serif",serif; font-style: italic; }
            .sans { font-family: "Pretendard Variable","Pretendard",-apple-system,system-ui,sans-serif; }
            .display { font-family: "Inter Tight","Inter","Pretendard",system-ui,sans-serif; font-weight: 800; letter-spacing: -2px; }
            .rule { stroke: #0f0d0b; stroke-width: 1; }
          </style>
        </defs>

        <!-- 배경 종이 + 세로 격자 (에디토리얼 시그니처) -->
        <rect class="bg" width="1200" height="630"/>
        <g stroke="#0f0d0b" stroke-width="0.5" opacity="0.08">
          #{(80..1200).step(80).map { |x| %(<line x1="#{x}" y1="0" x2="#{x}" y2="630"/>) }.join}
        </g>

        <!-- 좌측 상단 브랜드 + 라벨 -->
        <g transform="translate(60, 60)">
          <text class="display ink" font-size="34">imPD<tspan class="accent">.</tspan></text>
          <text class="mono ink" font-size="11" y="24" letter-spacing="2" opacity="0.55">§ DIGITAL CARD · imPD 검증 회원</text>
        </g>

        <!-- 이름 + 직함 (대형 타이포그래피) -->
        <g transform="translate(60, 220)">
          <text class="display ink" font-size="88" text-anchor="start">#{name}</text>
          <text class="serif accent" font-size="72" y="96">#{profession}.</text>
          #{region.empty? ? "" : %(<text class="mono ink" font-size="16" y="150" letter-spacing="1.5" opacity="0.7">#{region}</text>)}
        </g>

        <!-- 하단 메타: 짧은 URL (경로) -->
        <g transform="translate(60, 560)">
          <line class="rule" x1="0" y1="-20" x2="740" y2="-20"/>
          <text class="mono ink" font-size="14" letter-spacing="1.2">#{short_url_display}</text>
          <text class="mono ink" font-size="10" y="22" letter-spacing="1.5" opacity="0.55">흩어진 내 일, 하나의 주소로.</text>
        </g>

        <!-- 우측: QR 코드 (흰 카드 + 폴라로이드 느낌) -->
        <g transform="translate(880, 160)">
          <rect x="-20" y="-20" width="280" height="340" fill="#ffffff" stroke="#0f0d0b" stroke-width="1.5" transform="rotate(2 120 150)"/>
          <g transform="translate(0, 0) scale(0.24)">
            #{qr_path}
          </g>
          <text class="mono ink" x="120" y="310" text-anchor="middle" font-size="10" letter-spacing="2" opacity="0.6">SCAN · 모바일 연결</text>
        </g>
      </svg>
    SVG
  end

  def short_url_for(member)
    # 짧은 URL 기본 타겟 = 요약 카드 뷰. 사용자는 명함부터 보고 원할 때만 전체 프로필.
    sl = ShortLink.resolve_or_create(target_path: "/#{member.slug}/card", member: member)
    host = request.host_with_port.presence || "impd.townin.net"
    proto = request.protocol.presence || "http://"
    sl ? "#{proto}#{host}/s/#{sl.hash_code}" : "#{proto}#{host}/#{member.slug}"
  end

  # RQRCode 로 QR 을 생성하고 <svg> 내부 <path ...> 만 추출 (outer <svg> 태그 제거).
  def qr_path_d(text)
    qr = RQRCode::QRCode.new(text, level: :m)
    svg = qr.as_svg(offset: 0, color: "0f172a", module_size: 10, standalone: false, use_path: true)
    svg.to_s
  end

  def escape(str)
    CGI.escapeHTML(str.to_s)
  end
end
