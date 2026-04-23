class Chopd::HomeController < Chopd::BaseController
  layout "impd"

  def index
    @hero_images = HeroImage.active
    @latest_courses = Course.published.recent.limit(6)
    @latest_posts = Post.published.recent.limit(3)

    # 우수 회원 갤러리: 승인된 회원들의 최근 사진
    @featured_moments = MemberPhoto
      .joins(:member)
      .where(members: { status: "approved" })
      .includes(:member, image_attachment: :blob)
      .order(uploaded_at: :desc)
      .limit(10)

    # §05 "imPD를 쓰는 사람들" — 승인된 실제 회원. is_featured 우선 + 최근 가입 순.
    # 최PD 포함한 실제 slug로 각 카드 클릭 시 공개 페이지로 이동 가능.
    @featured_members = Member.for_tenant
      .where(status: "approved")
      .order(Arel.sql("CASE WHEN is_featured = 1 THEN 0 ELSE 1 END"), featured_order: :asc, created_at: :desc)
      .limit(6)
  end
end
