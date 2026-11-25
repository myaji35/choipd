namespace :brands do
  desc "승인된 미탈퇴 회원의 개인 브랜드를 생성합니다 (기본 DRY_RUN, APPLY=1 적용)"
  task ensure_personal: :environment do
    members = Member.publicly_visible.where.not(id: Brand.where(personal: true).where.not(member_id: nil).select(:member_id))
    apply = ENV["APPLY"] == "1"
    count = 0

    members.find_each do |member|
      member.ensure_personal_brand! if apply
      puts member.id
      count += 1
    end

    puts "#{apply ? 'APPLY' : 'DRY_RUN'}: #{count}건"
  end
end
