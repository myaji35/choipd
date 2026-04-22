class PromoController < ApplicationController
  # 30초 시네마틱 홍보 영상 — 레이아웃 없이 전체 풀페이지 렌더링
  layout false

  def show
    # 정적 HTML/CSS 애니메이션 (라이브 재생 버전).
  end

  def watch
    # mp4 재생 + 공유 버튼 + OG 메타 (카톡/SNS 썸네일 노출).
    @video_url  = "/promo/impd-promo.mp4"
    @poster_url = "/promo/shot-profile-hero.png"
    @share_url  = request.protocol + request.host_with_port + "/promo/watch"
  end
end
