namespace :profile_accounts do
  desc "인물정보 계정 로그인 상태 점검"
  task :check, [ :platform ] => :environment do |_task, args|
    platforms = args[:platform].presence ? [ args[:platform] ] : ProfileAccount::PLATFORMS.keys
    checker = EgoProfile::Checker.new
    platforms.each { |platform| puts checker.call(platform).summary }
  end
end
