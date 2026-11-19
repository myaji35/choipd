class Api::Socialdoctors::ConsentedBrandsController < Api::Socialdoctors::BaseController
  def index
    synced_at = Time.current
    since = Time.iso8601(params[:since]) if params[:since].present?
    consents = ProConsent.where(consent_type: ProConsent::BRAND_CONSENT_TEXTS.keys).order(consented_at: :desc, id: :desc).group_by(&:owner_id)
    ids = consents.keys.select { |id| id.match?(/\A[1-9]\d*\z/) }
    brands_by_member = Brand.where(member_id: ids).group_by(&:member_id)
    items = Member.where(id: ids).filter_map do |member|
      records = consents[member.id.to_s]
      exposure = records.find { |c| c.consent_type == "socialdoctors_exposure" && c.consented_at.present? }
      next unless exposure

      brands = brands_by_member[member.id] || []
      changed_at = [ member.updated_at, member.withdrawn_at, *records.flat_map { |c| [ c.consented_at, c.revoked_at ] }, *brands.map(&:updated_at) ].compact.max
      next if since && changed_at <= since

      townin = records.find { |c| c.consent_type == "townin_local_ads" && c.consented && c.revoked_at.nil? }
      {
        externalId: "m_#{member.id}", slug: member.slug, name: member.name, bio: member.bio,
        profession: member.profession_label, businessType: member.business_type, region: member.region,
        profileImage: member.profile_image, coverImage: member.cover_image, socialLinks: member.social.is_a?(Hash) ? member.social.except("email", "phone", "telephone") : {},
        consentedAt: exposure.consented_at&.iso8601(6), revokedAt: exposure.revoked_at&.iso8601(6),
        withdrawnAt: member.withdrawn_at&.iso8601(6), townInLocalAds: townin.present?,
        brands: brands.map { |brand| { id: brand.id, slug: brand.slug, name: brand.name, businessType: brand.business_type,
                                       region: brand.region, description: brand.description, websiteUrl: brand.website_url, logoUrl: brand.logo_url } }
      }
    end
    render json: { brands: items, syncedAt: synced_at.iso8601(6) }
  rescue ArgumentError
    render json: { error: "since는 ISO8601 형식이어야 합니다." }, status: :bad_request
  end
end
