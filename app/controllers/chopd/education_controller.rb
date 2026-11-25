class Chopd::EducationController < Chopd::BaseController
  def index
    @course_type = params[:type] if Course.course_types.key?(params[:type])

    @courses = Course.published
    @courses = @courses.by_type(@course_type) if @course_type
    @courses = @courses.recent

    @inquiry = Inquiry.new
  end
end
