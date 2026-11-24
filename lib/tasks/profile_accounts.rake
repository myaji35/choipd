namespace :profile_accounts do
  desc "게시 시각이 지난 승인된 LinkedIn 게시물 게시"
  task publish_due: :environment do
    Linkedin::SharePublishing.new.publish_due.each do |id, result|
      puts({ id: id, **result }.to_json)
    end
  end

  desc "LinkedIn 게시 화면 점검 (publish_probe[profile_account_id])"
  task :publish_probe, [ :profile_account_id ] => :environment do |_task, args|
    accounts = ProfileAccount.for_platform("linkedin").order(:id)
    account = args[:profile_account_id].present? ? accounts.find(args[:profile_account_id]) : accounts.first!
    publisher = EgoProfile::LinkedinPublisher.new
    %w[post article].each do |kind|
      puts({ kind: kind, **publisher.call(kind: kind, account: account, probe: true) }.to_json)
    end
  end

  desc "인물정보 주간 리포트 출력"
  task :weekly_report, [ :week_end ] => :environment do |_task, args|
    week_end = args[:week_end].present? ? Date.iso8601(args[:week_end]) : ProfileAccounts::WeeklyReport.today
    puts ProfileAccounts::WeeklyReport.new(week_end: week_end).to_text
  end

  desc "인물정보 계정 로그인 상태 점검"
  task :check, [ :platform ] => :environment do |_task, args|
    platforms = args[:platform].presence ? [ args[:platform] ] : ProfileAccount::PLATFORMS.keys
    checker = EgoProfile::Checker.new
    platforms.each { |platform| puts checker.call(platform).summary }
  end
end
