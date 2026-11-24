namespace :brand_channels do
  desc "브랜드 채널 네이버 로그인 점검 (patrol[brand_id])"
  task :patrol, [ :brand_id ] => :environment do |_task, args|
    puts BrandChannels::SessionPatrol.new.call(brand_id: args[:brand_id])
  end

  desc "게시 시각이 지난 승인된 브랜드 네이버 블로그 게시물 게시"
  task publish_due: :environment do
    BrandChannels::BlogPublishing.new.publish_due.each do |id, result|
      puts({ id: id, **result }.to_json)
    end
  end

  desc "네이버 블로그 글쓰기 화면 점검 (blog_probe[brand_channel_id])"
  task :blog_probe, [ :brand_channel_id ] => :environment do |_task, args|
    channel = BrandChannel.where(platform: "naver_blog").find(args[:brand_channel_id])
    puts EgoProfile::NaverBlogPublisher.new.call(channel: channel, probe: true).to_json
  end
end
