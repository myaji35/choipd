class Admin::MemberDocumentsController < Admin::BaseController
  MAX_BYTES = 1 * 1024 * 1024  # 1MB
  ALLOWED_EXT = %w[.md .markdown .txt].freeze

  before_action :set_member
  before_action :set_document, only: [ :show, :destroy, :parse ]

  def index
    @documents = @member.member_documents.order(uploaded_at: :desc)
    render json: { success: true, documents: @documents.as_json(only: [ :id, :filename, :title, :category, :size_bytes, :uploaded_at, :parsed_at, :extracted_skills_count ]) }
  end

  def show
    render json: { success: true, document: @document.as_json }
  end

  def create
    content = params[:content].to_s
    filename = (params[:filename].presence || "document.md").to_s
    category = (params[:category].presence || "other")
    title = params[:title]

    if content.bytesize > MAX_BYTES
      return render json: { success: false, error: "FILE_TOO_LARGE" }, status: :unprocessable_entity
    end

    ext = File.extname(filename.downcase)
    unless ALLOWED_EXT.include?(ext) || ext.empty?
      return render json: { success: false, error: "INVALID_EXT" }, status: :unprocessable_entity
    end

    doc = @member.member_documents.new(
      tenant_id: 1,
      filename: filename,
      title: title,
      category: category,
      content_md: content
    )

    if doc.save
      # 즉시 파싱 (skills 자동 추출)
      parse_document(doc)
      render json: { success: true, document: doc.reload.as_json }, status: :created
    else
      render json: { success: false, errors: doc.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { success: false, error: "DUPLICATE_CONTENT" }, status: :conflict
  end

  def destroy
    @document.destroy
    render json: { success: true, id: @document.id }
  end

  def parse
    parse_document(@document)
    render json: { success: true, document: @document.reload.as_json }
  end

  private

  def set_member
    @member = Member.for_tenant.find_by(slug: params[:member_id]) || Member.for_tenant.find(params[:member_id])
  end

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
        s.aliases = [name].to_json
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
