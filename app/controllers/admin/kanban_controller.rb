class Admin::KanbanController < Admin::BaseController
  before_action :set_project, only: [ :show, :update_project, :destroy_project ]

  def index
    @projects = KanbanProject.for_tenant.active.sorted
  end

  def show
    @columns = @project.kanban_columns.ordered.includes(:kanban_tasks)
  end

  def create_project
    @project = KanbanProject.create!(
      tenant_id: 1,
      title: params[:title].presence || "새 프로젝트",
      description: params[:description],
      color: params[:color] || "#3b82f6",
      icon: params[:icon] || "folder"
    )
    # 기본 컬럼 3개 자동 생성
    %w[할일 진행중 완료].each_with_index do |t, idx|
      @project.kanban_columns.create!(tenant_id: 1, title: t, sort_order: idx, color: %w[#94a3b8 #3b82f6 #10b981][idx])
    end
    redirect_to admin_kanban_project_path(@project)
  end

  def update_project
    @project.update!(project_params)
    respond_to do |f|
      f.html { redirect_to admin_kanban_project_path(@project) }
      f.json { render json: { success: true } }
    end
  end

  def destroy_project
    @project.destroy
    redirect_to admin_kanban_path, notice: "프로젝트가 삭제되었습니다."
  end

  private

  def set_project
    @project = KanbanProject.for_tenant.find(params[:id])
  end

  def project_params
    params.permit(:title, :description, :color, :icon, :is_archived, :sort_order)
  end
end
