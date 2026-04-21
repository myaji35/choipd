class Chopd::HomeController < Chopd::BaseController
  layout "impd"

  def index
    @hero_images = HeroImage.active
    @latest_courses = Course.published.recent.limit(6)
    @latest_posts = Post.published.recent.limit(3)
  end
end
