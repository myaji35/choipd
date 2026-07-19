class Chopd::CommunityController < Chopd::BaseController
  # /community 는 플랫폼 커뮤니티이므로 choi 개인 허브 레이아웃(chopd) 대신
  # 플랫폼 레이아웃(impd)을 사용한다. brand-dna anti-pattern #1 준수.
  layout "impd"

  def index
    @notices = Post.published.by_category("notice").recent.limit(5)
    @reviews = Post.published.by_category("review").recent.limit(3)
    @lead = Lead.new
  end
end
