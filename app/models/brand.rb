class Brand < ApplicationRecord
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def marketing_handoff_url
    return if website_url.blank?

    uri = URI.parse(ENV.fetch("SOCIALDOCTORS_BASE_URL", "https://app-socialdoctors.158.247.235.31.nip.io"))
    uri.path = "/admin/campaigns/new"
    uri.query = URI.encode_www_form(
      source: "impd",
      brandId: id,
      slug: slug,
      name: name,
      website: website_url,
      businessType: business_type,
      region: region
    )
    uri.to_s
  end

  private

  def generate_slug
    base_slug = name.parameterize
    if base_slug.blank? && website_url.present?
      begin
        host = URI.parse(website_url).host.to_s.downcase.sub(/\Awww\./, "")
        base_slug = host.split(".").first.to_s.gsub(/[^a-z0-9-]/, "")
      rescue URI::InvalidURIError
        base_slug = ""
      end
    end
    base_slug = "brand" if base_slug.blank?

    candidate = base_slug
    suffix = 2

    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
