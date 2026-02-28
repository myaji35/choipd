class Pd::KanbanColumnsController < Pd::BaseController
  before_action :set_project
  before_action :set_column, only: [ :edit, :update, :destroy ]

  def create
    @column = @project.kanban_columns.build(column_params)
    @column.position = @project.kanban_columns.count + 1
    if @column.save
      redirect_to pd_kanban_project_path(@project), notice: "컬럼이 추가되었습니다."
    else
      redirect_to pd_kanban_project_path(@project), alert: "컬럼 추가 실패"
    end
  end

  def update
    @column.update!(column_params)
    redirect_to pd_kanban_project_path(@project), notice: "컬럼이 수정되었습니다."
  end

  def destroy
    @column.destroy
    redirect_to pd_kanban_project_path(@project), notice: "컬럼이 삭제되었습니다."
  end

  private

  def set_project
    @project = KanbanProject.find(params[:kanban_project_id])
  end

  def set_column
    @column = @project.kanban_columns.find(params[:id])
  end

  def column_params
    params.require(:kanban_column).permit(:title, :position)
  end
end
