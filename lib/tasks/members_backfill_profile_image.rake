namespace :members do
  desc "Backfill blank profile images from OAuth data (dry run unless APPLY=1)"
  task backfill_profile_image: :environment do
    apply = ENV["APPLY"] == "1"
    count = 0

    Member.where.not(oauth_raw: nil).find_each do |member|
      next unless member.profile_image.blank?

      raw = JSON.parse(member.oauth_raw)
      next unless raw.is_a?(Hash)

      picture = raw["picture"]
      eligible = apply ? member.fill_profile_image(picture) : Member.https_profile_image_url?(picture)
      next unless eligible

      puts member.id
      count += 1
    rescue JSON::ParserError
      next
    end

    puts "#{apply ? 'APPLY' : 'DRY_RUN'} count=#{count}"
  end
end
