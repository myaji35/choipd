class Admin::WorksController < Admin::BaseController
  before_action :set_work, only: [ :show, :edit, :update, :destroy ]

  def index
    @works = Work.recent
    @works = @works.where(category: params[:category]) if params[:category].present?
    @pagy, @works = pagy(@works, items: 24) if respond_to?(:pagy)
  end

  def show; end
  def new; @work = Work.new; end

  def create
    @work = Work.new(work_params)
    if @work.save
      redirect_to admin_work_path(@work), notice: "작품이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @work.update(work_params)
      redirect_to admin_work_path(@work), notice: "작품이 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @work.destroy
    redirect_to admin_works_path, notice: "작품이 삭제되었습니다."
  end

  private

  def set_work
    @work = Work.find(params[:id])
  end

  def work_params
    params.require(:work).permit(:title, :description, :image_url, :category, :image)
  end
end
