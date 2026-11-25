module Pd::MembersHelper
  def profile_account_next_step(account)
    case account.session_status
    when "unknown"
      message = if account.external_id.blank?
        "아직 점검 전입니다. 점검을 돌린 뒤 이 화면으로 돌아오면 찾은 계정으로 바꿀 수 있습니다."
      else
        "아직 점검 전입니다. 점검을 돌리면 회원 화면의 '계정 확인'이 채워집니다."
      end
      [message, "점검하러 가기", pd_profile_accounts_path]
    when "logged_out"
      ["로그인이 풀려 있습니다. ego 브라우저에서 다시 로그인한 뒤 점검해 주세요.", "점검하러 가기", pd_profile_accounts_path]
    when "error"
      ["점검 중 오류가 났습니다. 계정 상세에서 내용을 확인해 주세요.", nil, nil]
    when "logged_in"
      has_content = account.platform == "naver_people" ? account.naver_people_target.present? : account.profile_snapshots.exists?
      if has_content
        ["관리 중 — 회원 화면에도 '관리 중'으로 보입니다.", nil, nil]
      else
        ["계정 확인까지 끝났습니다. 다음은 계정 상세에서 내용 손보기입니다.", nil, nil]
      end
    end
  end

  def brand_channel_next_step(channel, state)
    return [nil, nil, nil] unless channel.delegated?
    return ["운영 중 — 회원 화면에도 '운영 중'으로 보입니다.", nil, nil] if state == :running

    message = case channel.session_status
    when "logged_out", "error"
      "연결에 문제가 있습니다(#{BrandChannel::SESSION_STATUSES.fetch(channel.session_status)}). 회원 화면에는 '확인 중'으로 보입니다."
    when "unknown"
      "동의까지 끝났습니다. 다음은 연결 설정입니다. 연결해야 글을 올릴 수 있습니다."
    when "connected"
      return ["연결까지 끝났습니다. 첫 글을 올리면 회원 화면이 '운영 중'으로 바뀝니다.", nil, nil]
    end

    if current_admin_user.admin?
      [message, "연결 설정 열기", edit_admin_brand_brand_channel_path(channel.brand_id, channel)]
    else
      ["#{message} 연결 설정은 운영자에게 요청해 주세요.", nil, nil]
    end
  end

  def member_login_status_label(member)
    member.withdrawn? ? "탈퇴" : member_status_label(member.status)
  end
end
