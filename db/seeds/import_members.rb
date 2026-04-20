# Members + talent 도메인 import
require "json"
EXPORT_DIR = Rails.root.join("tmp/nextjs_export/json")

def to_t(v)
  return nil if v.nil?
  Time.at(v.to_i) rescue Time.parse(v.to_s) rescue nil
end

def imp(file, model, &mapper)
  path = EXPORT_DIR.join(file)
  return puts("  skip #{file} (no file)") unless path.exist?
  rows = JSON.parse(path.read)
  imported = 0
  rows.each do |r|
    attrs = mapper.call(r)
    rec = model.find_or_initialize_by(id: attrs[:id])
    rec.assign_attributes(attrs.except(:id))
    rec.save!
    imported += 1
  rescue ActiveRecord::RecordInvalid => e
    puts "    ✗ #{file} id=#{r['id']}: #{e.message}"
  end
  puts "  ✓ #{file}: #{imported}/#{rows.size}"
end

puts "📦 members + talent import"

imp("members.json", Member) { |r|
  {
    id: r["id"], tenant_id: r["tenant_id"] || 1,
    towningraph_user_id: r["towningraph_user_id"], townin_email: r["townin_email"],
    townin_name: r["townin_name"], townin_role: r["townin_role"],
    slug: r["slug"], name: r["name"], email: r["email"], phone: r["phone"],
    profile_image: r["profile_image"], cover_image: r["cover_image"], bio: r["bio"],
    social_links: r["social_links"], business_type: r["business_type"],
    profession: r["profession"], region: r["region"],
    status: r["status"] || "pending_approval",
    subscription_plan: r["subscription_plan"] || "basic",
    enabled_modules: r["enabled_modules"] || "[]",
    theme_config: r["theme_config"] || "{}",
    rejection_reason: r["rejection_reason"],
    is_featured: r["is_featured"].to_i, featured_order: r["featured_order"].to_i,
    impd_status: r["impd_status"] || "none",
    impd_started_at: to_t(r["impd_started_at"]),
    impd_completed_at: to_t(r["impd_completed_at"]),
    impd_verification_id: r["impd_verification_id"],
    impd_steps_data: r["impd_steps_data"] || "{}",
    created_at: to_t(r["created_at"]) || Time.current,
    updated_at: to_t(r["updated_at"]) || Time.current
  }
}

imp("member_portfolio_items.json", MemberPortfolioItem) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1, member_id: r["member_id"],
    title: r["title"], description: r["description"], media_url: r["media_url"],
    media_type: r["media_type"], category: r["category"],
    sort_order: r["sort_order"].to_i, created_at: to_t(r["created_at"]) || Time.current }
}

imp("member_posts.json", MemberPost) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1, member_id: r["member_id"],
    title: r["title"], content: r["content"], category: r["category"],
    thumbnail_url: r["thumbnail_url"], is_published: r["is_published"].to_i,
    published_at: to_t(r["published_at"]),
    created_at: to_t(r["created_at"]) || Time.current,
    updated_at: to_t(r["updated_at"]) || Time.current }
}

imp("member_inquiries.json", MemberInquiry) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1, member_id: r["member_id"],
    sender_name: r["sender_name"], sender_email: r["sender_email"], message: r["message"],
    is_read: r["is_read"].to_i, created_at: to_t(r["created_at"]) || Time.current }
}

imp("skills.json", Skill) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1, canonical_name: r["canonical_name"],
    aliases: r["aliases"] || "[]", category: r["category"] || "hard", axis: r["axis"],
    description: r["description"], created_at: to_t(r["created_at"]) || Time.current }
}

imp("member_skills.json", MemberSkill) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1,
    member_id: r["member_id"], skill_id: r["skill_id"],
    level: r["level"] || "intermediate", weight: r["weight"].to_i.zero? ? 50 : r["weight"].to_i,
    source: r["source"] || "self", years_experience: r["years_experience"],
    verified_at: to_t(r["verified_at"]),
    created_at: to_t(r["created_at"]) || Time.current,
    updated_at: to_t(r["updated_at"]) || Time.current }
}

imp("member_documents.json", MemberDocument) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1, member_id: r["member_id"],
    filename: r["filename"], title: r["title"], category: r["category"] || "other",
    tags: r["tags"] || "[]", content_md: r["content_md"],
    content_hash: r["content_hash"] || Digest::SHA256.hexdigest(r["content_md"].to_s),
    size_bytes: r["size_bytes"].to_i, parsed_at: to_t(r["parsed_at"]),
    extracted_skills_count: r["extracted_skills_count"].to_i,
    extracted_entities: r["extracted_entities"] || "{}",
    uploaded_at: to_t(r["uploaded_at"]) || Time.current }
}

imp("member_gap_reports.json", MemberGapReport) { |r|
  { id: r["id"], tenant_id: r["tenant_id"] || 1, member_id: r["member_id"],
    profession: r["profession"], completeness_score: r["completeness_score"].to_i,
    radar_self: r["radar_self"], radar_median: r["radar_median"], radar_top10: r["radar_top10"],
    gaps_json: r["gaps_json"] || "[]", opportunities_json: r["opportunities_json"] || "[]",
    growth_path_json: r["growth_path_json"] || "[]",
    peer_sample_size: r["peer_sample_size"].to_i,
    generated_at: to_t(r["generated_at"]) || Time.current }
}

puts "✅ Member: #{Member.count} | Skill: #{Skill.count} | Doc: #{MemberDocument.count}"
