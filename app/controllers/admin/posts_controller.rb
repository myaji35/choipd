class Admin::PostsController < Admin::BaseController
  before_action :set_post, only: [ :show, :edit, :update, :destroy ]

  def index
    @posts = Post.recent
    @posts = @posts.where(category: params[:category]) if params[:category].present?
    @posts = @posts.where(published: params[:published] == "true") if params[:published].present?
    @pagy, @posts = pagy(@posts, items: 20) if respond_to?(:pagy)
  end

  def show; end
  def new; @post = Post.new; end

  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to admin_post_path(@post), notice: "게시글이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @post.update(post_params)
      redirect_to admin_post_path(@post), notice: "게시글이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_posts_path, notice: "게시글이 삭제되었습니다."
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content, :category, :published)
  end
end
