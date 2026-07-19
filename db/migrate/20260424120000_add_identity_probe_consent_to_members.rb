# frozen_string_literal: true

# ISS-401: Identity Probe 동의 시각을 Member에 기록한다.
# 선택 항목. 체크하지 않은 회원은 기존 가입 플로우를 그대로 사용한다.
class AddIdentityProbeConsentToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :identity_probe_consent_at, :datetime
    add_index  :members, :identity_probe_consent_at
  end
end
