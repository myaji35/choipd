# 파트너 상태 추가
#   none      (nil · 기본) : 일반 회원 (soft 활동 - status=approved면 본인 페이지만)
#   pending   : Townin 파트너 등록 대기 (관리자가 towningraph_user_id만 입력한 상태)
#   active    : Townin에서 파트너 검증 완료 · 공개 페이지에 파트너 섹션 표시
#   suspended : 파트너 자격 일시 중지
class AddPartnerStatusToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :partner_status, :string, default: "none"
    add_column :members, :partner_promoted_at, :datetime
    add_column :members, :partner_notes, :text

    add_index :members, :partner_status
  end
end
