module ApplicationHelper
  def example_profile_path
    @example_profile_path ||= begin
      members = Member.for_tenant.publicly_visible.where.not(slug: [nil, ""])
      slug = members.find_by(slug: "choi-pd")&.slug || members
        .order(Arel.sql("CASE WHEN is_featured = 1 THEN 0 ELSE 1 END"), featured_order: :asc, created_at: :desc)
        .pick(:slug)

      slug ? "/#{slug}" : explore_path
    end
  end

  def http_url(value)
    uri = URI.parse(value.to_s)
    value if %w[http https].include?(uri.scheme&.downcase) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
