# 회원 탈퇴 = 물리삭제 아님. 소프트삭제(withdrawn_at) + 개인식별정보 익명화 + 문서 파기.
# 거래/리뷰/문의는 member_id 유지한 채 보존(ISS-112에서 restrict_with_error로 물리삭제 차단됨).
# 정책(대표님 확정): 전체 익명화 + 업로드문서 파기 + 즉시 재가입 허용.
class MemberWithdrawalService
  def initialize(member)
    @member = member
  end

  # 성공 시 true. 트랜잭션으로 원자성 보장.
  def call
    ActiveRecord::Base.transaction do
      purge_documents      # 업로드 문서(개인정보/수료증) 물리 파기
      anonymize_pii        # 개인식별정보 마스킹
      release_public       # slug 해제 → 공개페이지 404
      mark_withdrawn       # withdrawn_at 기록
    end
    true
  rescue => e
    Rails.logger.error("[MemberWithdrawal] member=#{@member.id} #{e.class}: #{e.message}")
    false
  end

  private

  def purge_documents
    @member.member_documents.destroy_all
    @member.member_photos.destroy_all
  end

  def anonymize_pii
    # NOT NULL 컬럼(name/email/slug)은 placeholder로 대체. 재가입 즉시 허용이므로
    # email을 복원불가하게 바꿔 유니크 충돌을 피한다.
    token = "withdrawn-#{@member.id}-#{SecureRandom.hex(4)}"
    @member.update_columns(
      name: "탈퇴한 회원",
      email: "#{token}@withdrawn.impd.invalid",
      phone: nil,
      bio: nil,
      profile_image: nil,
      cover_image: nil,
      social_links: nil,
      region: nil,
      townin_email: nil,
      provider: nil,
      uid: nil,
      oauth_raw: nil,
      password_digest: nil
    )
  end

  def release_public
    # slug도 NOT NULL. 공개 조회가 안 되도록 예약 접두사로 치환.
    @member.update_columns(slug: "withdrawn-#{@member.id}-#{SecureRandom.hex(4)}", status: "rejected")
  end

  def mark_withdrawn
    @member.update_columns(withdrawn_at: Time.current)
  end
end
