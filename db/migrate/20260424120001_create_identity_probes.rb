# frozen_string_literal: true

# ISS-401: IdentityProbe 엔진의 결과 저장 테이블.
# SQLite이므로 jsonb 대신 text + JSON 직렬화 (모델에서 serialize).
class CreateIdentityProbes < ActiveRecord::Migration[8.1]
  def change
    create_table :identity_probes do |t|
      t.references :member, foreign_key: true, null: false
      t.string   :status,       null: false, default: "pending"
      t.float    :confidence
      t.text     :identity          # JSON hash (display_name/bio_draft/links...)
      t.text     :sources_queried   # JSON array
      t.text     :sources_hit       # JSON array
      t.text     :raw_signals       # JSON array — 30일 후 퍼지
      t.integer  :last_step, default: 0, null: false
      t.text     :step_payloads     # JSON hash — 위자드 스텝별 응답
      t.string   :user_decision     # accepted|partial|rejected|null
      t.datetime :decided_at
      t.datetime :expires_at        # 기본 24h
      t.datetime :raw_purged_at
      t.timestamps
    end

    add_index :identity_probes, [:member_id, :status]
    add_index :identity_probes, :expires_at
    add_index :identity_probes, :status
  end
end
