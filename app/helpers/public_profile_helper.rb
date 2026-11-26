module PublicProfileHelper
  PHOTO_CATEGORY_LABELS = { "daily" => "일상", "workshop" => "작품", "product" => "작품", "press" => "이력", "people" => "일상" }.freeze

  # 사진 분류를 방문 고객이 읽는 우리말로. 모르는 값·빈 값은 "사진".
  def photo_category_label(category)
    PHOTO_CATEGORY_LABELS[category.to_s] || "사진"
  end

  def public_share_title(member)
    member.profession.present? ? "#{member.name} · #{member.profession_label}" : member.name.to_s
  end

  def public_share_description(member, services, limit = 100)
    bio = member.bio.to_s.squish
    if services.empty?
      return bio_excerpt(bio, limit) if bio.present?

      return "#{member.name}님에게 상담·문의를 남길 수 있는 페이지예요."
    end

    offer = "하는 일: #{services.first(3).map(&:title).join(" · ")}"
    offer += " 외 #{services.size - 3}개" if services.size > 3
    remaining = limit - offer.length - " — ".length
    return "#{offer} — #{bio_excerpt(bio, remaining)}" if bio.present? && remaining >= 20

    offer.truncate(limit, omission: "…")
  end

  # 소개 글을 limit 자 안에서 '문장이 끝나는 곳' 까지만 보여 준다. 글자를 바꾸거나 지어내지 않는다.
  def bio_excerpt(text, limit = 140)
    text = text.to_s.squish
    return text if text.length <= limit

    excerpt = +""
    text.split(/(?<=[.!?]) /).each do |sentence|
      break unless sentence.end_with?(".", "!", "?")

      separator = excerpt.empty? ? "" : " "
      break if excerpt.length + separator.length + sentence.length > limit

      excerpt << separator << sentence
    end
    excerpt.presence || text.truncate(limit, separator: " ", omission: "…")
  end

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
