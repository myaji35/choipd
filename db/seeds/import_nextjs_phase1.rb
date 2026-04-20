# Phase 1 데이터 import: Next.js → Rails
# 사용: bin/rails runner db/seeds/import_nextjs_phase1.rb
#
# tmp/nextjs_export/json/*.json 의 18개 P0 테이블 데이터를 Rails DB로 import.
# 멱등성: 기존 데이터는 id 기반으로 update, 없으면 insert.

require "json"

EXPORT_DIR = Rails.root.join("tmp/nextjs_export/json")

def load_json(filename)
  path = EXPORT_DIR.join(filename)
  return [] unless path.exist?
  JSON.parse(path.read)
end

def import_table(model_class, filename, mapper: nil)
  rows = load_json(filename)
  if rows.empty?
    puts "  skip: #{filename} (no data)"
    return 0
  end

  imported = 0
  rows.each do |row|
    attrs = mapper ? mapper.call(row) : row
    record = model_class.find_or_initialize_by(id: attrs[:id] || attrs["id"])
    record.assign_attributes(attrs.except(:id, "id"))
    record.save!
    imported += 1
  rescue ActiveRecord::RecordInvalid => e
    puts "    ✗ #{filename} id=#{row['id']}: #{e.message}"
  end
  puts "  ✓ #{filename}: #{imported}/#{rows.size} imported"
  imported
end

# 타입 변환 헬퍼
def to_time(val)
  return nil if val.nil?
  return val if val.is_a?(Time) || val.is_a?(DateTime)
  Time.at(val.to_i) rescue Time.parse(val.to_s) rescue nil
end

def to_bool(val)
  return false if val.nil?
  val == 1 || val == true || val.to_s == "1" || val.to_s == "true"
end

# ── content (9) ────────────────────────────────────────
puts "📦 Phase 1: content domain"

import_table(Course, "courses.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    title: r["title"],
    description: r["description"],
    course_type: r["type"],
    price: r["price"],
    thumbnail_url: r["thumbnail_url"],
    external_link: r["external_link"],
    published: to_bool(r["published"]),
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

import_table(Post, "posts.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    title: r["title"],
    content: r["content"],
    category: r["category"],
    published: to_bool(r["published"]),
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

import_table(Work, "works.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    title: r["title"],
    description: r["description"],
    image_url: r["image_url"],
    category: r["category"],
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

import_table(Inquiry, "inquiries.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    name: r["name"],
    email: r["email"],
    phone: r["phone"],
    message: r["message"],
    inquiry_type: r["type"],
    status: r["status"] || "pending",
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

import_table(HeroImage, "hero_images.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    filename: r["filename"],
    url: r["url"],
    alt_text: r["alt_text"],
    file_size: r["file_size"],
    width: r["width"],
    height: r["height"],
    upload_status: r["upload_status"] || "completed",
    uploaded_at: to_time(r["uploaded_at"]) || Time.current,
    is_active: to_bool(r["is_active"]),
    display_order: r["display_order"] || 0,
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

# ── distribution (6) ───────────────────────────────────
puts "📦 Phase 1: distribution domain"

import_table(Distributor, "distributors.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    name: r["name"],
    email: r["email"],
    phone: r["phone"],
    business_type: r["business_type"] || "etc",
    region: r["region"],
    status: r["status"] || "pending",
    subscription_plan: r["subscription_plan"],
    total_revenue: r["total_revenue"] || 0,
    slug: r["slug"],
    approved_at: to_time(r["approved_at"]),
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

# ── sns (3) ────────────────────────────────────────────
puts "📦 Phase 1: sns domain"

import_table(SnsAccount, "sns_accounts.json", mapper: ->(r) {
  {
    id: r["id"],
    tenant_id: r["tenant_id"] || 1,
    platform: r["platform"],
    account_name: r["account_name"],
    access_token_encrypted: r["access_token"],
    is_active: to_bool(r["is_active"]),
    created_at: to_time(r["created_at"]) || Time.current,
    updated_at: to_time(r["updated_at"]) || Time.current
  }
})

puts "✅ Phase 1 데이터 import 완료"
puts "   Course: #{Course.count}"
puts "   Post: #{Post.count}"
puts "   Work: #{Work.count}"
puts "   Inquiry: #{Inquiry.count}"
puts "   HeroImage: #{HeroImage.count}"
puts "   Distributor: #{Distributor.count}"
puts "   SnsAccount: #{SnsAccount.count}"
