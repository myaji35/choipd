module ApplicationHelper
  def http_url(value)
    uri = URI.parse(value.to_s)
    value if %w[http https].include?(uri.scheme&.downcase) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
