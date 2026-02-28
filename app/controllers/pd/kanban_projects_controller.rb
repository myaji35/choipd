class Pd::KanbanProjectsController < Pd::BaseController
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @kanban_projects = KanbanProject.recent
  end

  def show
    @columns = @project.kanban_columns.ordered.includes(:kanban_tasks)
  end

  def new
    @project = KanbanProject.new
  end

  def create
    @project = KanbanProject.new(project_params)
    if @project.save
      # 기본 컬럼 생성
      %w[할 일 진행 중 완료].each_with_index do |title, i|
        @project.kanban_columns.create!(title: title, position: i + 1)
      end
      redirect_to pd_kanban_project_path(@project), notice: "칸반 프로젝트가 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @project.update(project_params)
      redirect_to pd_kanban_project_path(@project), notice: "프로젝트가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to pd_kanban_projects_path, notice: "프로젝트가 삭제되었습니다."
  end

  private

  def set_project
    @project = KanbanProject.find(params[:id])
  end

  def project_params
    params.require(:kanban_project).permit(:title, :description, :color)
  end
end
