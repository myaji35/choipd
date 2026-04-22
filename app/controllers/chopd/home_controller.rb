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
  end
end
