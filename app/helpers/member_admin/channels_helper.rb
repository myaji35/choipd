module MemberAdmin::ChannelsHelper
  def channel_state_label(item)
    { running: "운영 중", preparing: "준비 중", checking: "확인 중" }[item[:state]]
  end

  def channel_state_color(item)
    { running: "var(--impd-accent)", preparing: "var(--impd-muted)", checking: "#b42318" }[item[:state]]
  end

  def channel_state_note(item)
    case item[:state]
    when :running
      "운영팀이 글을 올리고 있어요. 따로 하실 일은 없어요."
    when :preparing
      if item[:channel].delegated?
        "운영팀이 첫 글을 준비하고 있어요. 올리면 여기에 표시돼요."
      else
        "운영 위탁에 동의하면 운영팀이 글을 올리기 시작해요."
      end
    when :checking
      "계정 연결에 문제가 있어 운영팀이 확인하고 있어요. 따로 하실 일은 없어요."
    end
  end

  def channel_management_path(item)
    if (channel = item[:channel])
      edit_admin_brand_brand_channel_path(channel.brand_id, channel)
    elsif (brand = item[:brand])
      new_admin_brand_brand_channel_path(brand)
    else
      admin_brands_path
    end
  end

  def channel_date(time, with_time: false)
    time&.in_time_zone("Asia/Seoul")&.strftime(with_time ? "%Y.%m.%d %H:%M" : "%Y.%m.%d")
  end

  def channel_summary(item)
    [
      ["최근 30일 올린 글", "#{number_with_delimiter(item[:posted_30d])}건"],
      ["마지막으로 올린 날", channel_date(item[:last_posted_at]) || "아직 없어요"],
      ["예약된 글", item[:scheduled_count].zero? ? "없어요" : "#{number_with_delimiter(item[:scheduled_count])}건"],
      ["팔로워", ("#{number_with_delimiter(item[:followers])}명" unless item[:followers].nil?)]
    ]
  end

  def channel_link_style
    "display: inline-flex; align-items: center; min-height: 44px; color: var(--impd-accent); text-decoration: underline;"
  end

  def channel_follower_change(delta)
    return if delta.nil?
    return "지난 기록과 같아요" if delta.zero?

    "지난 기록보다 #{number_with_delimiter(delta.abs)}명 #{delta.positive? ? '늘었어요' : '줄었어요'}"
  end
end
