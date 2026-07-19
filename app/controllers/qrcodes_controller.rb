# 회원별 QR 코드 SVG 생성.
# /qr/:slug.svg → impd 도메인 회원 공개 페이지를 가리키는 QR.
# 실제로는 짧은 URL (impd.townin.net/s/<hash>) 을 인코딩해서 QR 스캔 시 즉시 짧은 URL 경유.
class QrcodesController < ApplicationController
  # 공개 엔드포인트. 존재하지 않는 slug 는 404.
  def show
    slug = params[:slug]
    member = Member.find_by(slug: slug)
    # 공개 프로필(#show)과 동일한 접근성 — status 게이트는 회원 자체가 존재하면 QR 제공.
    # (profile 뷰가 렌더되면 QR도 렌더되어야 공유 경로가 깨지지 않음)
    if member.blank?
      head :not_found and return
    end

    target_url = short_link_for(member)

    qr = RQRCode::QRCode.new(target_url, level: :m)
    svg = qr.as_svg(
      offset: 0,
      color: "0f172a",       # brand-dna text_primary 계열
      shape_rendering: "crispEdges",
      module_size: 10,
      standalone: true,
      use_path: true,
    )

    expires_in 24.hours, public: true
    send_data svg, type: "image/svg+xml", disposition: "inline"
  end

  private

  # 회원 공개 페이지로 직행하는 짧은 URL 을 발급하고 절대 URL 반환.
  def short_link_for(member)
    # QR 스캔 기본 타겟 = 요약 카드 뷰. 긴 페이지 스크롤 없이 즉각 명함부터.
    sl = ShortLink.resolve_or_create(target_path: "/#{member.slug}/card", member: member)
    host = request.host_with_port.presence || "impd.townin.net"
    proto = request.protocol.presence || "http://"
    sl ? "#{proto}#{host}/s/#{sl.hash_code}" : "#{proto}#{host}/#{member.slug}"
  end
end
