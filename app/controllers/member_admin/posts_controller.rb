class MemberAdmin::PostsController < MemberAdmin::BaseController
  before_action :set_post, only: [ :update, :toggle_publish, :destroy ]

  def index
    @posts = @member.member_posts.recent
  end

  def create
    post = @member.member_posts.new(post_params)
    post.published_at = Time.current if post.is_published.to_i == 1

    if post.save
      flash[:saved_item] = "post-#{post.id}"
      message = post.is_published.to_i == 1 ? "소식을 올렸어요. 내 페이지에 바로 보여요." : "소식을 저장했어요. 아직 나만 볼 수 있어요."
      redirect_to slug_admin_posts_path(slug: @member.slug), notice: message
    else
      @posts = @member.member_posts.recent
      @new_post = post
      render :index, status: :unprocessable_entity
    end
  end

  def update
    attributes = post_params.to_h.symbolize_keys
    if @post.is_published.to_i != 1 && attributes[:is_published].to_i == 1
      attributes[:published_at] = Time.current
    end

    if @post.update(attributes)
      flash[:saved_item] = "post-#{@post.id}"
      redirect_to slug_admin_posts_path(slug: @member.slug), notice: "소식을 고쳤어요."
    else
      @posts = @member.member_posts.recent
      render :index, status: :unprocessable_entity
    end
  end

  def toggle_publish
    publishing = @post.is_published.to_i != 1
    attributes = { is_published: publishing ? 1 : 0 }
    attributes[:published_at] = Time.current if publishing
    @post.update!(attributes)
    flash[:saved_item] = "post-#{@post.id}"

    message = publishing ? "소식을 내 페이지에 보이게 했어요." : "소식을 내 페이지에서 숨겼어요."
    redirect_to slug_admin_posts_path(slug: @member.slug), notice: message, status: :see_other
  end

  def destroy
    @post.destroy!
    redirect_to slug_admin_posts_path(slug: @member.slug), notice: "소식을 지웠어요.", status: :see_other
  end

  private

  def set_post
    @post = @member.member_posts.find(params[:id])
  end

  def post_params
    params.require(:member_post).permit(:title, :content, :category, :thumbnail_url, :is_published)
  end
end
