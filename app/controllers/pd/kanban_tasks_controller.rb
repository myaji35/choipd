class Pd::KanbanTasksController < Pd::BaseController
  before_action :set_project
  before_action :set_column
  before_action :set_task, only: [ :edit, :update, :destroy ]

  def create
    @task = @column.kanban_tasks.build(task_params)
    @task.position = @column.kanban_tasks.count + 1
    if @task.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to pd_kanban_project_path(@project) }
      end
    else
      redirect_to pd_kanban_project_path(@project), alert: "태스크 추가 실패"
    end
  end

  def update
    if @task.update(task_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to pd_kanban_project_path(@project) }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to pd_kanban_project_path(@project), notice: "태스크가 삭제되었습니다."
  end

  private

  def set_project
    @project = KanbanProject.find(params[:kanban_project_id])
  end

  def set_column
    @column = @project.kanban_columns.find(params[:kanban_column_id])
  end

  def set_task
    @task = @column.kanban_tasks.find(params[:id])
  end

  def task_params
    params.require(:kanban_task).permit(:title, :description, :priority, :due_date, :labels, :position)
  end
end
