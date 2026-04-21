class Admin::KanbanColumnsController < Admin::BaseController
  before_action :set_project
  before_action :set_column, only: [ :update, :destroy ]

  def create
    col = @project.kanban_columns.create!(
      tenant_id: 1,
      title: params[:title].presence || "새 컬럼",
      color: params[:color] || "#6b7280",
      sort_order: @project.kanban_columns.maximum(:sort_order).to_i + 1
    )
    render json: { success: true, column: col.as_json }
  end

  def update
    @column.update!(column_params)
    render json: { success: true, column: @column.as_json }
  end

  def destroy
    @column.destroy
    render json: { success: true }
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, idx|
      KanbanColumn.where(kanban_project_id: @project.id, id: id).update_all(sort_order: idx)
    end
    render json: { success: true }
  end

  private

  def set_project
    @project = KanbanProject.for_tenant.find(params[:project_id])
  end

  def set_column
    @column = @project.kanban_columns.find(params[:id])
  end

  def column_params
    params.permit(:title, :color, :sort_order)
  end
end
