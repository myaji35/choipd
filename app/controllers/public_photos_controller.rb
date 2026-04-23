# 사진 1장 전용 공개 에디토리얼 페이지.
# /p/:slug/:photo_id → 회원의 사진 한 장을 "미니 잡지 한 면"으로 렌더.
#
# 목적 (대표님 지시): "카톡/SNS 에 사진 원본 올리는 것보다, impd 에 올리고
# 링크를 공유하는 것이 더 있어 보이게."
# 공유 URL: impd.townin.net/p/<slug>/<photo_id>
# 그 URL 의 OG 이미지: 사진 자체 + imPD 워터마크
class PublicPhotosController < ApplicationController
  layout "impd"

  def show
    @member = Member.find_by(slug: params[:slug])
    head :not_found and return if @member.blank? || @member.status != "approved"

    @photo = @member.member_photos.find_by(id: params[:photo_id])
    head :not_found and return if @photo.blank? || !@photo.image.attached?

    # 앞/뒤 사진 네비게이션
    siblings = @member.member_photos.ordered.to_a
    idx = siblings.index { |p| p.id == @photo.id }
    @prev_photo = siblings[idx - 1] if idx && idx > 0
    @next_photo = siblings[idx + 1] if idx
    @photos_total = siblings.size
    @photo_position = idx.to_i + 1

    # 공유용 짧은 URL
    @short_link = ShortLink.resolve_or_create(target_path: "/p/#{@member.slug}/#{@photo.id}", member: @member)

    track_view
  end

  private

  def track_view
    AnalyticsEvent.track(
      event_name: "page_view",
      event_category: "photo",
      page_path: "/p/#{@member.slug}/#{@photo.id}",
      page_title: @photo.caption.presence || "#{@member.name} 사진",
      user_id: session[:member_id]&.to_s,
      user_type: session[:member_id] == @member.id ? "pd" : "anonymous",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      device_type: request.user_agent.to_s.downcase.match?(/mobile|android|iphone/) ? "mobile" : "desktop"
    )
  rescue StandardError => e
    Rails.logger.error "[PublicPhotos.track] #{e.message}"
  end
end
