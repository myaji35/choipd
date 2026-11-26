class Chopd::HomeController < Chopd::BaseController
  include MemberCardData
  layout "impd"

  def index
    available = Member.for_tenant.publicly_visible
    recommended = available.order(FEATURED_FIRST, featured_order: :asc)
    @featured_members = recommended.order(created_at: :desc).limit(6).to_a
    @profession_groups = profession_groups(available)
    @member_count = @profession_groups.sum { |group| group[:count] }
    @example_slugs_present = available.where(slug: helpers.example_member_slugs).index_by(&:slug)
    load_recent_activity(available)

    @flow_members = recommended.where("#{PROFILE_FILLED} OR #{CAREER_FILLED}")
      .order(Arel.sql("CASE WHEN #{CAREER_FILLED} THEN 0 ELSE 1 END"),
        Arel.sql("CASE WHEN COALESCE(TRIM(profile_image), '') != '' THEN 0 ELSE 1 END"), created_at: :desc)
      .limit(12).to_a
    load_member_card_data(@flow_members + @featured_members)
  end

  private

  def load_recent_activity(available)
    photos = MemberPhoto.joins(:member).merge(available)
    posts = MemberPost.published.joins(:member).merge(available)
    recent_media = photos.with_attached_image.includes(:member).order(uploaded_at: :desc, id: :desc).limit(30).to_a
    @featured_moments = gallery_media(recent_media, recent_media.map(&:member).index_by(&:id)).first(10)
    @recent_member_posts = posts.includes(:member).recent.limit(4).to_a

    now = Time.current
    recent = 7.days.ago(now)..now
    @recent_photo_count = photos.joins(image_attachment: :blob)
      .where(active_storage_blobs: { content_type: MemberPhoto::IMAGE_TYPES }, uploaded_at: recent).count
    @recent_post_count = posts.where(published_at: recent).count
    @latest_activity_at = [@featured_moments.first&.uploaded_at, @recent_member_posts.first&.published_at].compact.max
  end
end
