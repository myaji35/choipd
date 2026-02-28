class Admin::CoursesController < Admin::BaseController
  before_action :set_course, only: [ :show, :edit, :update, :destroy ]

  def index
    @pagy, @courses = pagy(Course.recent, items: 20)
  end

  def show; end

  def new
    @course = Course.new
  end

  def create
    @course = Course.new(course_params)
    if @course.save
      redirect_to admin_course_path(@course), notice: "강좌가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @course.update(course_params)
      redirect_to admin_course_path(@course), notice: "강좌가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @course.destroy
    redirect_to admin_courses_path, notice: "강좌가 삭제되었습니다."
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def course_params
    params.require(:course).permit(:title, :description, :course_type, :price, :thumbnail_url, :external_link, :published, :thumbnail)
  end
end
