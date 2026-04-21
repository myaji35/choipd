class MemberAdmin::DocumentsController < MemberAdmin::BaseController
  MAX_BYTES = 1 * 1024 * 1024
  ALLOWED_EXT = %w[.md .markdown .txt].freeze

  skip_before_action :verify_authenticity_token, only: [ :create, :destroy, :reparse ]
  before_action :set_document, only: [ :destroy, :reparse ]

  def create
    content = params[:content].to_s
    filename = (params[:filename].presence || "document.md").to_s
    category = (params[:category].presence || "other")
    title = params[:title]

    ext = File.extname(filename.downcase)
    if !ALLOWED_EXT.include?(ext) && !ext.empty?
      return render json: { success: false, error: "INVALID_EXT", message: "#{ext} 확장자는 지원되지 않습니다." }, status: :unprocessable_entity
    end
    if content.bytesize > MAX_BYTES
      return render json: { success: false, error: "FILE_TOO_LARGE", message: "파일이 1MB를 초과합니다." }, status: :unprocessable_entity
    end
    if content.strip.empty?
      return render json: { success: false, error: "EMPTY_FILE", message: "파일 내용이 비어 있습니다." }, status: :unprocessable_entity
    end

    doc = @member.member_documents.new(
      tenant_id: 1,
      filename: filename,
      title: title,
      category: category,
      content_md: content
    )

    if doc.save
      parse_document(doc)
      render json: { success: true, document: doc.reload.as_json }, status: :created
    else
      render json: { success: false, errors: doc.errors.full_messages, message: doc.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { success: false, error: "DUPLICATE_CONTENT", message: "동일한 내용의 파일이 이미 있습니다." }, status: :conflict
  end

  def destroy
    @document.destroy
    render json: { success: true, id: @document.id }
  end

  def reparse
    parse_document(@document)
    render json: { success: true, document: @document.reload.as_json }
  end

  private

  def set_document
    @document = @member.member_documents.find(params[:id])
  end

  def parse_document(doc)
    parsed = IdentityParser.parse(doc.content_md)
    skill_names = (parsed[:keywords] || []) + (parsed[:tone] || [])
    skill_count = 0
    skill_names.first(20).each do |name|
      next if name.blank?
      canonical = name.strip.downcase
      skill = Skill.find_or_create_by!(tenant_id: 1, canonical_name: canonical) do |s|
        s.category = "hard"
        s.aliases = [ name ].to_json
      end
      MemberSkill.find_or_create_by!(member_id: doc.member_id, skill_id: skill.id) do |ms|
        ms.tenant_id = 1
        ms.level = "intermediate"
        ms.weight = 50
        ms.source = "document"
      end
      skill_count += 1
    end
    doc.update!(
      parsed_at: Time.current,
      extracted_skills_count: skill_count,
      extracted_entities: { hashtags: parsed[:hashtags], mentions: parsed[:mentions] }.to_json
    )
  end
end
