class Admin::MembersController < Admin::BaseController
  before_action :set_member, only: [ :show, :edit, :update, :destroy, :approve, :reject, :suspend, :activate ]

  def index
    @members = Member.for_tenant.recent
                     .by_status(params[:status])
                     .by_impd(params[:impd])
                     .by_profession(params[:profession])
                     .search(params[:q])
    @pagy, @members = pagy(@members, items: 20) if respond_to?(:pagy)
  end

  def show
    @portfolio_count = @member.member_portfolio_items.count
    @services_count  = @member.member_services.count
    @posts_count     = @member.member_posts.count
    @reviews         = @member.member_reviews.recent.limit(10)
    @inquiries       = @member.member_inquiries.recent.limit(10)
    @documents       = @member.member_documents.order(uploaded_at: :desc)
    @skills          = @member.member_skills.includes(:skill).order(weight: :desc).limit(20)
    @gap_report      = @member.member_gap_reports.order(generated_at: :desc).first
  end

  def new
    @member = Member.new(tenant_id: 1, status: "pending_approval")
  end

  def create
    @member = Member.new(member_params.merge(tenant_id: 1))
    if @member.save
      redirect_to admin_member_path(@member), notice: "회원이 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @member.update(member_params)
      redirect_to admin_member_path(@member), notice: "회원 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @member.destroy
    redirect_to admin_members_path, notice: "회원이 삭제되었습니다."
  end

  def approve
    @member.update!(status: "approved")
    redirect_to admin_member_path(@member), notice: "#{@member.name} 승인 완료"
  end

  def reject
    @member.update!(status: "rejected", rejection_reason: params[:reason])
    redirect_to admin_member_path(@member), notice: "#{@member.name} 거부 완료"
  end

  def suspend
    @member.update!(status: "suspended")
    redirect_to admin_member_path(@member), notice: "#{@member.name} 정지 완료"
  end

  def activate
    @member.update!(status: "approved")
    redirect_to admin_member_path(@member), notice: "#{@member.name} 재활성화 완료"
  end

  # 소셜 로그인(OAuth) 연결 해제 — 회원은 비밀번호 재설정 후 로그인해야 함.
  def unlink_oauth
    provider = @member.provider
    @member.update!(provider: nil, uid: nil, oauth_connected_at: nil, oauth_email_verified: 0, oauth_raw: nil)
    redirect_to admin_member_path(@member), notice: "#{@member.name} 의 #{provider} 소셜 연결이 해제되었습니다."
  end

  # ── Townin 파트너 관리 ─────────────────────────
  # ISS-321: 이메일로 Townin 계정 조회 (JSON) — "조회" 버튼이 호출
  def lookup_townin
    email = params[:email].to_s.strip.downcase
    if email.blank? || !email.include?("@")
      render json: { found: false, error: "이메일을 입력하세요" }, status: :bad_request and return
    end
    result = TowninClient.lookup_by_email(email)
    render json: result
  rescue TowninClient::Unauthorized => e
    render json: { found: false, error: "Townin API 키 설정 오류: #{e.message}" }, status: :service_unavailable
  rescue TowninClient::Error => e
    render json: { found: false, error: e.message }, status: :service_unavailable
  end

  # Townin user_id/이메일/역할 등록 (또는 수정)
  def link_townin
    permitted = params.permit(:towningraph_user_id, :townin_email, :townin_name, :townin_role)
    if permitted[:towningraph_user_id].blank?
      redirect_to admin_member_path(@member), alert: "Townin User ID는 필수입니다." and return
    end
    # 최초 등록 시 pending, 이미 active면 유지
    new_partner_status = @member.partner_active? ? @member.partner_status : "pending"
    @member.update!(permitted.merge(partner_status: new_partner_status))
    redirect_to admin_member_path(@member), notice: "#{@member.name} 의 Townin 정보가 등록되었습니다. 검증 후 '파트너 승급'을 눌러주세요."
  end

  # ISS-321: 파트너 승급 — Townin API 호출로 실제 users.role = partner 전환 + partners 레코드 생성
  def promote_partner
    unless @member.partner_connected?
      redirect_to admin_member_path(@member), alert: "먼저 Townin User ID를 등록해주세요." and return
    end

    # Townin API 호출 (실패해도 로컬 상태는 업데이트하지 않음 — 양성화 원칙)
    if TowninClient.enabled?
      begin
        result = TowninClient.upgrade_role(
          user_id: @member.towningraph_user_id,
          target_role: "partner",
          verification_id: "impd-member-#{@member.id}",
        )
        @member.promote_to_partner!(notes: params[:notes])
        partner_id = result["partnerId"]
        if partner_id.present?
          @member.update(partner_notes: [@member.partner_notes, "[townin.partnerId=#{partner_id}] promoted #{Time.current.iso8601}"].compact.join("\n"))
        end
        redirect_to admin_member_path(@member), notice: "#{@member.name} 을(를) Townin 파트너로 승급했습니다. (partnerId: #{partner_id || '—'})"
      rescue TowninClient::BadRequest => e
        redirect_to admin_member_path(@member), alert: "Townin 승급 거부: #{e.message}"
      rescue TowninClient::NotFound
        redirect_to admin_member_path(@member), alert: "Townin에 해당 User ID가 존재하지 않습니다. User ID를 재확인해주세요."
      rescue TowninClient::Error => e
        redirect_to admin_member_path(@member), alert: "Townin API 호출 실패: #{e.message}"
      end
    else
      # API 키 미설정 시 로컬만 업데이트 (개발 환경용 폴백)
      @member.promote_to_partner!(notes: params[:notes])
      redirect_to admin_member_path(@member), notice: "#{@member.name} 을(를) 로컬 파트너로 승급했습니다. (Townin API 연동 비활성)"
    end
  end

  # 파트너 자격 중지
  def suspend_partner
    @member.demote_from_partner!(reason: params[:reason])
    redirect_to admin_member_path(@member), notice: "#{@member.name} 의 파트너 자격을 중지했습니다."
  end

  # Townin 연결 완전 해제
  def unlink_townin
    @member.update!(
      towningraph_user_id: nil, townin_email: nil, townin_name: nil, townin_role: nil,
      partner_status: "none", partner_promoted_at: nil
    )
    redirect_to admin_member_path(@member), notice: "#{@member.name} 의 Townin 연결이 해제되었습니다."
  end

  private

  def set_member
    @member = Member.for_tenant.find_by(slug: params[:id]) || Member.for_tenant.find(params[:id])
  end

  def member_params
    params.require(:member).permit(
      :name, :email, :phone, :slug, :bio, :profile_image, :cover_image,
      :business_type, :profession, :region, :status, :subscription_plan,
      :is_featured, :featured_order, :impd_status, :rejection_reason
    )
  end
end
