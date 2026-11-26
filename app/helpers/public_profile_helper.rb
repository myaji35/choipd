module PublicProfileHelper
  def service_price_text(service)
    price = service.price.to_s.strip
    unit = service.price_label.to_s.strip
    price = "#{number_with_delimiter(price.delete(','))}원" if price.match?(/\A\d[\d,]*\z/)
    [price.presence, unit.presence].compact.join(" · ").presence || "가격 문의"
  end

  def portfolio_media(item)
    url = item.media_url.to_s.strip
    path = url.split(/[?#]/, 2).first.to_s.sub(%r{\A[a-z][a-z0-9+.-]*://[^/]*}i, "")
    image_like = url.start_with?("/") ||
      path.match?(/\.(jpe?g|png|gif|webp|avif|svg)\z/i) ||
      path.include?("/rails/active_storage/")
    return { media_url: url } if image_like && item.media_type.to_s != "link"
    return {} unless url.match?(%r{\Ahttps?://}i)

    host = begin
      URI.parse(url).host
    rescue URI::InvalidURIError
      url[%r{\Ahttps?://([^/?#]+)}i, 1]
    end
    { link_url: url, link_host: host }
  end
end
