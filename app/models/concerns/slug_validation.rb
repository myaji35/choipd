# Slug 검증 — Next.js src/lib/distributors/slug.ts (validateSlug + RESERVED_SLUGS) 포팅
module SlugValidation
  extend ActiveSupport::Concern

  SLUG_REGEX = /\A[a-z0-9][a-z0-9-]{1,28}[a-z0-9]\z/

  RESERVED_SLUGS = %w[
    admin api app pd chopd choi
    login logout register signup onboarding
    settings profile dashboard public static
    assets images media _next help support
    terms privacy pricing docs blog press
    about contact member members users user
    distributors distributor reports impd www
    auth up education works community inquiries leads
    rails
  ].to_set.freeze

  included do
    before_validation :normalize_slug
    validate :slug_format
  end

  class_methods do
    def suggest_slug(email: nil, name: nil)
      if email && email.include?("@")
        local = email.split("@").first.downcase.gsub(/[^a-z0-9\-]/, "-").gsub(/^-+|-+$/, "")
        return local[0, 30] if local.length >= 3
      end
      if name
        roman = name.downcase.gsub(/[^a-z0-9\-]/, "-").gsub(/^-+|-+$/, "")
        return roman[0, 30] if roman.length >= 3
      end
      "user-#{SecureRandom.hex(3)}"
    end
  end

  private

  def normalize_slug
    return if slug.blank?
    self.slug = slug.to_s.strip.downcase.gsub(/\s+/, "-")
  end

  def slug_format
    return if slug.blank?
    if slug.length < 3
      errors.add(:slug, "최소 3자 이상 필요")
    elsif slug.length > 30
      errors.add(:slug, "최대 30자까지 가능")
    elsif !SLUG_REGEX.match?(slug)
      errors.add(:slug, "영문 소문자 · 숫자 · 하이픈만 가능 (양끝 하이픈 금지)")
    elsif RESERVED_SLUGS.include?(slug)
      errors.add(:slug, "예약된 ID입니다")
    end
  end
end
