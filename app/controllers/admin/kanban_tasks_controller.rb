class Admin::KanbanTasksController < Admin::BaseController
  before_action :set_project
  before_action :set_task, only: [ :update, :destroy, :move, :complete, :reopen ]

  def create
    column = @project.kanban_columns.find(params[:column_id])
    task = column.kanban_tasks.create!(
      tenant_id: 1,
      project_id: @project.id,
      title: params[:title].presence || "새 카드",
      description: params[:description],
      priority: params[:priority] || "medium",
      due_date: params[:due_date],
      assignee: params[:assignee],
      sort_order: column.kanban_tasks.maximum(:sort_order).to_i + 1
    )
    render json: { success: true, task: task.as_json }
  end

  def update
    @task.update!(task_params)
    render json: { success: true, task: @task.as_json }
  end

  def destroy
    @task.destroy
    render json: { success: true }
  end

  # 드래그앤드롭으로 카드 이동
  # POST /admin/kanban/projects/:project_id/tasks/:id/move
  # params: { column_id, sort_order } 또는 { column_id, ordered_ids: [...] }
  def move
    new_col = @project.kanban_columns.find(params[:column_id])
    @task.update!(kanban_column_id: new_col.id)

    if params[:ordered_ids].is_a?(Array)
      params[:ordered_ids].each_with_index do |id, idx|
        KanbanTask.where(kanban_column_id: new_col.id, id: id).update_all(sort_order: idx)
      end
    else
      @task.update!(sort_order: params[:sort_order].to_i)
    end
    render json: { success: true }
  end

  def complete
    @task.complete!
    render json: { success: true, task: @task.as_json }
  end

  def reopen
    @task.reopen!
    render json: { success: true, task: @task.as_json }
  end

  private

  def set_project
    @project = KanbanProject.for_tenant.find(params[:project_id])
  end

  def set_task
    @task = @project.kanban_tasks.find(params[:id])
  end

  def task_params
    params.permit(:title, :description, :priority, :due_date, :assignee, :sort_order, :is_completed)
  end
end
