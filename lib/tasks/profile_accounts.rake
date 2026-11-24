namespace :profile_accounts do
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
