module MemberAdmin::ProfileAccountsHelper
  def korean_time_ago(time)
    elapsed = Time.current - time
    return "방금 전" if elapsed < 1.minute
    return "#{(elapsed / 1.minute).floor}분 전" if elapsed < 1.hour
    return "#{(elapsed / 1.hour).floor}시간 전" if elapsed < 1.day
    return "#{(elapsed / 1.day).floor}일 전" if elapsed < 30.days
    return "#{(elapsed / 30.days).floor}개월 전" if elapsed < 365.days

    "#{(elapsed / 365.days).floor}년 전"
  end

  def masked_login_id(value)
    return if value.blank?

    login_id = value.to_s.strip
    email = /\A([^@\s]+)@([^@\s]+)\z/.match(login_id)
    return "#{email[1][0, 2]}***@#{email[2]}" if email

    "#{login_id[0, 2]}***"
  end
end
