module MemberCardData
  FEATURED_FIRST = Arel.sql("CASE WHEN is_featured = 1 THEN 0 ELSE 1 END")
  PROFILE_FILLED = "COALESCE(TRIM(bio), '') != '' OR COALESCE(TRIM(profile_image), '') != ''"
  CAREER_FILLED = "COALESCE(TRIM(career_note), '') != ''"

  private

  def profession_groups(scope)
    scope.group(:profession).count.group_by do |raw, _|
      helpers.member_profession_details(raw).first
    end.map do |label, counts|
      values = counts.map(&:first)
      key = if label == "크리에이터"
        "custom"
      else
        values.find { |value| Member::PROFESSIONS.include?(value) } || values.first
      end
      { label: label, icon: helpers.member_profession_details(key)[1],
        count: counts.sum(&:last), values: values, key: key }
    end.sort_by { |group| [-group[:count], group[:label]] }
  end

  def load_member_card_data(members)
    ids = members.map(&:id).uniq
    @first_service_by_member = MemberService.active.sorted.where(member_id: ids)
      .group_by(&:member_id).transform_values(&:first)
    candidates = MemberPhoto.where(member_id: ids).joins(image_attachment: :blob)
      .where(active_storage_blobs: { content_type: MemberPhoto::IMAGE_TYPES })
    members.index_by(&:id).each_value do |member|
      blob_id = profile_blob_id(member)
      candidates = candidates.where.not(member_id: member.id, active_storage_blobs: { id: blob_id }) if blob_id
    end
    ranked = candidates.select(
      "member_photos.*",
      "ROW_NUMBER() OVER (PARTITION BY member_photos.member_id ORDER BY uploaded_at DESC, member_photos.id DESC) AS cover_rank"
    )
    @cover_photo_by_member = MemberPhoto.from(ranked, :member_photos)
      .where("cover_rank = 1").with_attached_image.index_by(&:member_id)
  end

  def gallery_media(photos, members)
    profile_blobs = members.transform_values { |member| profile_blob_id(member) }

    photos.select do |photo|
      photo.image.attached? && photo.image.blob.id != profile_blobs[photo.member_id]
    end
  end

  def profile_blob_id(member)
    signed_id = member.profile_image.to_s[%r{/rails/active_storage/blobs/(?:redirect|proxy)/([^/]+)/}, 1]
    ActiveStorage.verifier.verified(signed_id, purpose: :blob_id) if signed_id
  end
end
