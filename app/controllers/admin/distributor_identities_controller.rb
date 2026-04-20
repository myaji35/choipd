class Admin::DistributorIdentitiesController < Admin::BaseController
  MAX_BYTES = 512 * 1024
  ALLOWED_EXT = %w[.md .markdown .txt].freeze

  before_action :set_distributor

  def show
    parsed = if @distributor.identity_json.present?
      JSON.parse(@distributor.identity_json) rescue nil
    end
    if parsed.nil? && @distributor.identity_md.present?
      parsed = IdentityParser.parse(@distributor.identity_md)
      @distributor.update_columns(
        identity_json: parsed.to_json,
        identity_parsed_at: Time.current
      )
    end

    render json: {
      success: true,
      identity: {
        content: @distributor.identity_md.to_s,
        filename: @distributor.identity_filename,
        updatedAt: @distributor.identity_updated_at,
        parsed: parsed,
        parsedAt: @distributor.identity_parsed_at
      }
    }
  end

  def update
    content = params[:content].to_s
    filename = (params[:filename].presence || "identity.md").to_s

    if content.bytesize > MAX_BYTES
      return render json: { success: false, error: "FILE_TOO_LARGE" }, status: :unprocessable_entity
    end

    ext = File.extname(filename.downcase)
    unless ALLOWED_EXT.include?(ext) || ext.empty?
      return render json: { success: false, error: "INVALID_EXT" }, status: :unprocessable_entity
    end

    parsed = IdentityParser.parse(content)
    @distributor.update!(
      identity_md: content,
      identity_filename: filename,
      identity_updated_at: Time.current,
      identity_json: parsed.to_json,
      identity_parsed_at: Time.current
    )

    @distributor.log_activity("identity_update", "identity.md 업데이트", actor: current_admin_user.id)

    render json: {
      success: true,
      identity: {
        content: @distributor.identity_md,
        filename: @distributor.identity_filename,
        updatedAt: @distributor.identity_updated_at,
        parsed: parsed,
        parsedAt: @distributor.identity_parsed_at
      }
    }
  end

  def destroy
    @distributor.update!(
      identity_md: nil,
      identity_filename: nil,
      identity_updated_at: nil,
      identity_json: nil,
      identity_parsed_at: nil
    )
    @distributor.log_activity("identity_delete", "identity.md 삭제", actor: current_admin_user.id)
    render json: { success: true }
  end

  private

  def set_distributor
    @distributor = Distributor.where(tenant_id: 1).find_by(id: params[:distributor_id]) ||
                   Distributor.where(tenant_id: 1).find_by!(slug: params[:distributor_id])
  end
end
