class Chopd::EducationController < Chopd::BaseController
  def index
    @courses = Course.published
    @courses = @courses.by_type(params[:type]) if params[:type].present?
    @courses = @courses.recent

    @inquiry = Inquiry.new
  end
end
