module BrandOps
  module DemoSeed
    SLUGS = ([ "kang-seung-sig" ] + (1..20).map { |i| "brand-demo-#{i}" }).freeze
    def self.present?
      AnalyticsEvent.where(event_category: "brand_ops_demo").exists?
    end
  end
end
