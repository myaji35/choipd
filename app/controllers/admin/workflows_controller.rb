class Admin::WorkflowsController < Admin::BaseController
  before_action :set_workflow, only: [ :show, :edit, :update, :destroy, :execute, :toggle ]

  def index
    @workflows = Workflow.for_tenant.recent
  end

  def show
    @recent_executions = @workflow.workflow_executions.recent.limit(20)
  end

  def new
    @workflow = Workflow.new(trigger: "manual", trigger_config: "{}", actions: "[]")
  end

  def create
    actions_text = params[:actions_text].to_s
    actions_arr = actions_text.split("\n").reject(&:blank?).map { |line|
      m = line.match(/\A(log|webhook|wait):\s*(.+)\z/)
      m ? { type: m[1], (m[1] == "log" ? "message" : "url") => m[2] } : { type: "log", message: line }
    }
    @workflow = Workflow.new(
      tenant_id: 1,
      name: params[:name],
      description: params[:description],
      trigger: params[:trigger] || "manual",
      trigger_config: (params[:trigger_config].presence || "{}"),
      actions: actions_arr.to_json,
      is_active: true,
      created_by: current_admin_user.email
    )
    if @workflow.save
      redirect_to admin_workflow_path(@workflow), notice: "워크플로우 생성됨"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @workflow.update!(params.permit(:name, :description, :trigger, :is_active))
    redirect_to admin_workflow_path(@workflow)
  end

  def destroy
    @workflow.destroy
    redirect_to admin_workflows_path
  end

  def execute
    exec = @workflow.execute!(trigger_source: "manual")
    redirect_to admin_workflow_path(@workflow), notice: "실행 완료 (id=#{exec.id}, status=#{exec.status})"
  rescue StandardError => e
    redirect_to admin_workflow_path(@workflow), alert: "실행 실패: #{e.message}"
  end

  def toggle
    @workflow.update!(is_active: !@workflow.is_active)
    redirect_to admin_workflow_path(@workflow)
  end

  private

  def set_workflow
    @workflow = Workflow.for_tenant.find(params[:id])
  end
end
