class Chopd::CommunityController < Chopd::BaseController
  def index
    @notices = Post.published.by_category("notice").recent.limit(5)
    @reviews = Post.published.by_category("review").recent.limit(3)
    @lead = Lead.new
  end
end
