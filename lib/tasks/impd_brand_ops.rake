namespace :impd do
  desc "개발용 브랜드 운영 예시 데이터 만들기"
  task demo_brand_ops: :environment do
    abort "개발 환경에서만 실행할 수 있습니다" unless Rails.env.development?
    now = Time.current
    anchor = now.in_time_zone("Asia/Seoul").beginning_of_week
    random = Random.new(481)
    AnalyticsEvent.where(event_category: "brand_ops_demo").delete_all
    BrandOps::DemoSeed::SLUGS.each_with_index do |slug, index|
      email = index.zero? ? "myaji35@gmail.com" : "brand-demo-#{index}@example.invalid"
      member = Member.find_by(slug: slug)
      next if member && member.email != email
      signup_week = index.zero? ? 25 : (25 - index - index / 3).clamp(1, 25)
      member ||= Member.create!(slug: slug, name: index.zero? ? "Kang Seung Sig" : "예시 회원 #{index}", email: email, status: "approved", profession: "크리에이터")
      inactive = index.between?(14, 20)
      member.update_columns(created_at: anchor - signup_week.weeks, updated_at: anchor - (inactive ? 8.weeks : 1.week), last_sign_in_at: anchor - (inactive ? 8.weeks : 1.week))
      Brand.find_or_create_by!(slug: "ops-demo-#{index}") { |b| b.name = index.zero? ? "Kang Seung Sig" : "예시 브랜드 #{index}"; b.member_id = member.id; b.published = true }
      ProConsent.find_or_create_by!(owner_id: member.id.to_s, consent_type: "socialdoctors_exposure", consented: true, revoked_at: nil) { |c| c.consented_at = now }
      member.member_posts.where("title LIKE ?", "예시 소식 %").delete_all
      MemberInquiry.where(member_id: member.id).where("sender_email LIKE ?", "demo-%@example.invalid").delete_all
      MemberReview.where(member_id: member.id).where("reviewer_email LIKE ?", "demo-%@example.invalid").delete_all
      scheduled = SnsScheduledPost.where(member_id: member.id).where("message LIKE ?", "예시 발행 %")
      SnsPostHistory.where(sns_scheduled_post_id: scheduled.select(:id)).delete_all
      scheduled.delete_all
      26.times do |week|
        time = anchor - week.weeks + 12.hours
        next if time < member.created_at || time > now || (inactive && week < 8)
        count = index.zero? ? (6 + (25 - week) / 7 + random.rand(-2..2)).clamp(6, 12) : [ 1 + index % 5 + (25 - week) / 10 + random.rand(-2..2), 0 ].max
        count.times do |n|
          AnalyticsEvent.create!(event_category: "brand_ops_demo", event_label: "ops-demo-#{index}-#{week}-#{n}", event_name: "page_view", page_path: "/#{slug}", metadata: { demo: true }.to_json, created_at: time)
        end
        if random.rand(3).zero?
          MemberPost.create!(member_id: member.id, title: "예시 소식 #{week}", content: "예시 게시물입니다.", is_published: 1, published_at: time, created_at: time, updated_at: time)
        end
        random.rand(4).times do |n|
          MemberInquiry.create!(member_id: member.id, sender_email: "demo-#{week}-#{n}@example.invalid", sender_name: "예시", message: "예시 문의입니다.", created_at: time, is_read: 1)
        end if random.rand(3).zero?
        if random.rand(8).zero?
          MemberReview.create!(member_id: member.id, reviewer_email: "demo-#{week}@example.invalid", reviewer_name: "예시", rating: 5, is_approved: 1, created_at: time, updated_at: time)
        end
        if random.rand(6).zero?
          scheduled_post = SnsScheduledPost.create!(member_id: member.id, message: "예시 발행 #{week}", platform: "instagram", scheduled_at: time, created_at: time, updated_at: time)
          SnsPostHistory.create!(sns_scheduled_post_id: scheduled_post.id, status: "success", created_at: time, updated_at: time)
        end
      end
    end
    puts "브랜드 운영 예시 데이터를 준비했습니다."
  end

  desc "개인정보 없는 주간 활동 합계 내보내기"
  task :export_activity, [ :slug ] => :environment do |_, args|
    member = Member.find_by!(slug: args[:slug])
    now = Time.current
    puts JSON.generate(slug: member.slug, generated_at: now.iso8601, platform: BrandOps::WeeklyStats.platform(weeks: 26, now: now), member: BrandOps::WeeklyStats.member(member, weeks: 26, now: now))
  end

  desc "개발 환경에 주간 활동 합계 가져오기 (BRAND_OPS_IMPORT=1로 사용)"
  task :import_activity, [ :path ] => :environment do |_, args|
    abort "개발 환경에서만 실행할 수 있습니다" unless Rails.env.development?
    data = JSON.parse(File.read(args[:path]))
    abort "올바르지 않은 집계 파일입니다" unless data["slug"].is_a?(String) && %w[platform member].all? { |key| data[key].is_a?(Array) }
    Rails.root.join("tmp/brand_ops_import.json").write(JSON.generate(data))
    puts "집계를 가져왔습니다. BRAND_OPS_IMPORT=1로 서버를 실행하세요."
  end
end
