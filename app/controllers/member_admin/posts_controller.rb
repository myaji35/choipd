class MemberAdmin::PostsController < MemberAdmin::BaseController
  before_action :set_post, only: [ :update, :toggle_publish, :destroy ]

  def index
    @posts = @member.member_posts.recent
  end

  def create
    post = @member.member_posts.new(post_params)
    post.published_at = Time.current if post.is_published.to_i == 1

    if post.save
      redirect_to slug_admin_posts_path(slug: @member.slug), notice: "소식을 등록했습니다."
    else
      @posts = @member.member_posts.recent
      flash.now[:alert] = post.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def update
    attributes = post_params.to_h.symbolize_keys
    if @post.is_published.to_i != 1 && attributes[:is_published].to_i == 1
      attributes[:published_at] = Time.current
    end

    if @post.update(attributes)
      redirect_to slug_admin_posts_path(slug: @member.slug), notice: "소식을 수정했습니다."
    else
      @posts = @member.member_posts.recent
      flash.now[:alert] = @post.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  end

  def toggle_publish
    publishing = @post.is_published.to_i != 1
    attributes = { is_published: publishing ? 1 : 0 }
    attributes[:published_at] = Time.current if publishing
    @post.update!(attributes)

    message = publishing ? "소식을 발행했습니다." : "소식을 비공개로 전환했습니다."
    redirect_to slug_admin_posts_path(slug: @member.slug), notice: message, status: :see_other
  end

  def destroy
    @post.destroy!
    redirect_to slug_admin_posts_path(slug: @member.slug), notice: "소식을 삭제했습니다.", status: :see_other
  end

  private

  def set_post
    @post = @member.member_posts.find(params[:id])
  end

  def post_params
    params.require(:member_post).permit(:title, :content, :category, :thumbnail_url, :is_published)
  end
end
