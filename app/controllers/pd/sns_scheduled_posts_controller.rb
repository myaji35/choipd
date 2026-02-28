class Pd::SnsScheduledPostsController < Pd::BaseController
  before_action :set_post, only: [ :edit, :update, :destroy ]

  def index
    @pagy, @scheduled_posts = pagy(SnsScheduledPost.recent, items: 20)
  end

  def new
    @post = SnsScheduledPost.new
    @sns_accounts = SnsAccount.active
  end

  def create
    @post = SnsScheduledPost.new(post_params)
    if @post.save
      redirect_to pd_scheduled_posts_path, notice: "예약 발행이 등록되었습니다."
    else
      @sns_accounts = SnsAccount.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @sns_accounts = SnsAccount.active
  end

  def update
    if @post.update(post_params)
      redirect_to pd_scheduled_posts_path, notice: "예약 발행이 수정되었습니다."
    else
      @sns_accounts = SnsAccount.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to pd_scheduled_posts_path, notice: "예약 발행이 삭제되었습니다."
  end

  private

  def set_post
    @post = SnsScheduledPost.find(params[:id])
  end

  def post_params
    params.require(:sns_scheduled_post).permit(:message, :platform, :scheduled_at, :status, :sns_account_id)
  end
end
