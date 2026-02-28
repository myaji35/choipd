# 시드 데이터 - imPD Rails
puts "🌱 시드 데이터 생성 중..."

# AdminUser 생성
AdminUser.find_or_create_by!(email: "admin@choipd.com") do |u|
  u.password = "Admin1234!"
  u.password_confirmation = "Admin1234!"
  u.role = "admin"
end
puts "✅ Admin 계정: admin@choipd.com / Admin1234!"

AdminUser.find_or_create_by!(email: "pd@choipd.com") do |u|
  u.password = "PD1234!pd"
  u.password_confirmation = "PD1234!pd"
  u.role = "pd"
end
puts "✅ PD 계정: pd@choipd.com / PD1234!pd"

# 강좌
[
  { title: "스마트폰 창업 입문", description: "스마트폰 하나로 시작하는 나만의 창업 여정.", course_type: "online", price: 99000, published: true },
  { title: "SNS 마케팅 실전 과정", description: "인스타그램, 유튜브를 활용한 실전 마케팅 전략.", course_type: "online", price: 149000, published: true },
  { title: "B2G 영업 전략 특강", description: "지자체, 공공기관 대상 교육 프로그램 수주 전략.", course_type: "b2b", price: 0, published: true },
  { title: "모바일 콘텐츠 제작", description: "스마트폰으로 제작하는 전문가 수준의 영상 콘텐츠.", course_type: "offline", price: 89000, published: true },
].each { |attrs| Course.find_or_create_by!(title: attrs[:title]) { |c| c.assign_attributes(attrs) } }
puts "✅ 강좌 4개 생성"

# 게시글
[
  { title: "2026년 스마트폰 창업 트렌드", content: "올해 주목해야 할 스마트폰 창업 트렌드를 소개합니다. AI 기반 콘텐츠 제작, 숏폼 영상 마케팅이 핵심입니다.", category: "notice", published: true },
  { title: "수강생 후기 - 실제로 창업에 성공했어요!", content: "최PD 강좌를 통해 SNS 마케팅을 배운 후 실제로 온라인 쇼핑몰을 오픈했습니다. 월 매출 300만원을 달성했어요!", category: "review", published: true },
  { title: "한국환경저널 특집호 발간", content: "2026년 봄 특집호가 발간되었습니다. 기후변화와 도시 녹화 프로젝트를 심층 취재했습니다.", category: "media", published: true },
].each { |attrs| Post.find_or_create_by!(title: attrs[:title]) { |p| p.assign_attributes(attrs) } }
puts "✅ 게시글 3개 생성"

# 작품
[
  { title: "모바일 스케치 - 한강의 봄", description: "스마트폰으로 그린 한강의 봄 풍경", category: "gallery" },
  { title: "모바일 스케치 - 북촌 한옥마을", description: "서울 북촌 한옥마을 골목 스케치", category: "gallery" },
  { title: "조선일보 - 스마트폰 창업 전문가 인터뷰", description: "조선일보 경제면 기획 인터뷰", category: "press" },
].each { |attrs| Work.find_or_create_by!(title: attrs[:title]) { |w| w.assign_attributes(attrs) } }
puts "✅ 작품 3개 생성"

# 설정
{ "site_name" => "최PD의 스마트폰 연구소", "site_description" => "스마트폰 창업 전략가 최범희 PD의 통합 브랜드 허브" }.each { |k, v| Setting.set(k, v) }
puts "✅ 사이트 설정"

# 구독 플랜
[
  { name: "basic", price: 99000, max_distributors: 1, features: "기본 자료 접근" },
  { name: "standard", price: 199000, max_distributors: 5, features: "전체 자료 접근, 교육 지원" },
  { name: "premium", price: 399000, max_distributors: 20, features: "모든 자료 무제한, 1:1 컨설팅" },
].each { |attrs| SubscriptionPlan.find_or_create_by!(name: attrs[:name]) { |p| p.assign_attributes(attrs) } }
puts "✅ 구독 플랜 3개 생성"

# 샘플 유통사
Distributor.find_or_create_by!(email: "seoul@partner.com") do |d|
  d.name = "서울 창업 파트너스"; d.business_type = "교육업"; d.region = "서울"; d.status = "approved"; d.subscription_plan = "standard"
end
puts "✅ 샘플 유통사 생성"

# 칸반 프로젝트
project = KanbanProject.find_or_create_by!(title: "2026 콘텐츠 플랜") do |p|
  p.description = "2026년 SNS 콘텐츠 및 강좌 개발 계획"; p.color = "#00A1E0"
end
if project.kanban_columns.empty?
  todo = project.kanban_columns.create!(title: "할 일", position: 1)
  doing = project.kanban_columns.create!(title: "진행 중", position: 2)
  project.kanban_columns.create!(title: "완료", position: 3)
  todo.kanban_tasks.create!(title: "스마트폰 창업 2.0 강좌 기획", priority: "high", position: 1)
  doing.kanban_tasks.create!(title: "SNS 마케팅 과정 업데이트", priority: "high", position: 1)
end
puts "✅ 칸반 프로젝트 생성"

puts "\n🎉 시드 데이터 생성 완료!"
puts "Admin: http://localhost:3000/admin"
puts "PD:    http://localhost:3000/pd"
puts "공개:  http://localhost:3000"
