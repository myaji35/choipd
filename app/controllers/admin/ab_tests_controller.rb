class Admin::AbTestsController < Admin::BaseController
  before_action :set_test, only: [ :show, :edit, :update, :destroy, :start, :pause, :complete ]

  def index
    @tests = AbTest.for_tenant.recent
  end

  def show
    @participants_count = @test.ab_test_participants.count
    @variants_stats = @test.variants_list.map { |v|
      parts = @test.ab_test_participants.where(variant: v)
      {
        variant: v,
        count: parts.count,
        converted: parts.where(converted: true).count,
        rate: @test.conversion_rate(v),
        revenue: parts.where(converted: true).sum(:conversion_value)
      }
    }
  end

  def new; @test = AbTest.new; end

  def create
    variants = (params[:variants_text] || "control,variant_a").split(",").map(&:strip)
    alloc = variants.each_with_object({}) { |v, h| h[v] = (100.0 / variants.size).round(2) }
    @test = AbTest.new(
      tenant_id: 1,
      name: params[:name],
      description: params[:description],
      hypothesis: params[:hypothesis],
      target_metric: params[:target_metric] || "conversion_rate",
      variants: variants.to_json,
      traffic_allocation: alloc.to_json,
      status: "draft",
      created_by: current_admin_user.email
    )
    if @test.save
      redirect_to admin_ab_test_path(@test), notice: "AB 테스트가 생성되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @test.update!(params.permit(:name, :description, :hypothesis, :status, :target_metric, :winner))
    redirect_to admin_ab_test_path(@test)
  end

  def destroy
    @test.destroy
    redirect_to admin_ab_tests_path
  end

  def start
    @test.update!(status: "running", start_date: Time.current)
    redirect_to admin_ab_test_path(@test), notice: "테스트 시작"
  end

  def pause
    @test.update!(status: "paused")
    redirect_to admin_ab_test_path(@test), notice: "테스트 일시 정지"
  end

  def complete
    @test.update!(status: "completed", end_date: Time.current)
    redirect_to admin_ab_test_path(@test), notice: "테스트 완료"
  end

  private

  def set_test
    @test = AbTest.for_tenant.find(params[:id])
  end
end
