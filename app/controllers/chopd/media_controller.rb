class Chopd::MediaController < Chopd::BaseController
  def index
    @media_posts = Post.published.by_category("media").recent.limit(10)
  end

  def greeting
  end
end
