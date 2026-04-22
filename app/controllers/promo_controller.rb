class PromoController < ApplicationController
  # 30초 시네마틱 홍보 영상 — 레이아웃 없이 전체 풀페이지 렌더링
  layout false

  def show
    # 정적 HTML/CSS 애니메이션. 모델/DB 접근 없음.
  end
end
