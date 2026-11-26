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
    photos = MemberPhoto.where(member_id: ids).with_attached_image
      .order(uploaded_at: :desc, id: :desc).limit(ids.size * 6)
    @cover_photo_by_member = gallery_media(photos, members.index_by(&:id))
      .reject(&:video?).group_by(&:member_id).transform_values(&:first)
  end

  def gallery_media(photos, members)
    profile_blobs = members.transform_values do |member|
      signed_id = member.profile_image.to_s[%r{/rails/active_storage/blobs/(?:redirect|proxy)/([^/]+)/}, 1]
      ActiveStorage.verifier.verified(signed_id, purpose: :blob_id) if signed_id
    end

    photos.select do |photo|
      photo.image.attached? && photo.image.blob.id != profile_blobs[photo.member_id]
    end
  end
end
