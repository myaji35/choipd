class CreateKakaoPro < ActiveRecord::Migration[8.1]
  def change
    # ── 카카오 채널 연결 ────────────────────────────
    create_table :kakao_channels do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :owner_id, null: false                    # admin_user.id 또는 member.id
      t.string :owner_type, default: "AdminUser"
      t.string :channel_id, null: false                  # 카카오 채널 ID (@채널이름)
      t.string :channel_name
      t.string :access_token_encrypted                   # 카카오 OAuth 토큰
      t.string :refresh_token_encrypted
      t.datetime :token_expires_at
      t.string :status, default: "pending", null: false  # pending | connected | revoked | error
      t.datetime :connected_at
      t.datetime :last_sync_at
      t.text :error_message
      t.timestamps
    end
    add_index :kakao_channels, :tenant_id
    add_index :kakao_channels, :channel_id, unique: true
    add_index :kakao_channels, :owner_id

    # ── 카카오 메시지 (수신만, 7일 보관) ──────────────
    create_table :kakao_messages do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :kakao_channel, foreign_key: { on_delete: :cascade }, null: false
      t.string :sender_kakao_id, null: false             # 발신자 (해시된 ID)
      t.string :sender_display
      t.text :body, null: false                           # 원본 메시지 (PII 분리 처리)
      t.string :message_type, default: "text"            # text | image | file | link
      t.boolean :replied, default: false, null: false    # 사장님이 답변했나
      t.datetime :replied_at
      t.string :question_kind                             # question | statement | complaint
      t.integer :urgency_score, default: 0               # 0-100
      t.boolean :purged, default: false                  # 7일 후 원문 자동 파기
      t.datetime :received_at, null: false
      t.timestamps
    end
    add_index :kakao_messages, [:kakao_channel_id, :received_at]
    add_index :kakao_messages, [:replied, :urgency_score]

    # ── 일일 요약 (저녁 8시 자동 생성) ─────────────────
    create_table :kakao_summaries do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :kakao_channel, foreign_key: { on_delete: :cascade }, null: false
      t.date :summary_date, null: false                  # 요약 대상 날짜
      t.text :must_reply_lines, null: false              # JSON: ["사장님이 답해야 할 것 3줄"]
      t.text :daily_summary_lines, null: false           # JSON: ["오늘 요약 3줄"]
      t.integer :total_messages, default: 0
      t.integer :unanswered_count, default: 0
      t.integer :urgent_count, default: 0
      t.string :model, default: "stub-1.0"
      t.datetime :generated_at, null: false
      t.boolean :pushed, default: false                  # 사장님에게 알림 보냈나
      t.datetime :pushed_at
    end
    add_index :kakao_summaries, [:kakao_channel_id, :summary_date], unique: true

    # ── 긴급 알림 (즉시 푸시) ─────────────────────────
    create_table :kakao_alerts do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :kakao_channel, foreign_key: { on_delete: :cascade }, null: false
      t.references :kakao_message, foreign_key: { on_delete: :cascade }, null: false
      t.string :alert_type, null: false                  # urgent_keyword | unanswered_long | complaint
      t.string :keyword                                   # 매칭된 키워드
      t.integer :severity, default: 1                    # 1-5
      t.text :reason
      t.boolean :acknowledged, default: false
      t.datetime :acknowledged_at
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :kakao_alerts, [:kakao_channel_id, :acknowledged]

    # ── 긴급 키워드 사전 (사장님이 커스터마이즈) ──────
    create_table :kakao_keywords do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :owner_id, null: false
      t.string :keyword, null: false
      t.string :category, default: "general"             # refund | complaint | legal | custom
      t.integer :weight, default: 50                     # 0-100 (긴급도 가중치)
      t.boolean :is_active, default: true
      t.timestamps
    end
    add_index :kakao_keywords, [:owner_id, :keyword], unique: true

    # ── Pro 구독 ──────────────────────────────────────
    create_table :pro_subscriptions do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :owner_id, null: false
      t.string :owner_type, default: "AdminUser"
      t.string :tier, default: "pro", null: false         # free | pro | enterprise
      t.integer :price_krw                                # 14900 | 29900
      t.string :status, default: "trial", null: false     # trial | active | past_due | cancelled
      t.datetime :trial_ends_at                           # 14일 무료
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.string :payment_method                            # stub | toss | stripe
      t.text :metadata
      t.timestamps
    end
    add_index :pro_subscriptions, :owner_id, unique: true

    # ── 옵트인 동의 (개인정보처리 동의) ────────────────
    create_table :pro_consents do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :owner_id, null: false
      t.string :consent_type, null: false                 # kakao_data_processing | customer_disclosure | tos
      t.boolean :consented, default: false, null: false
      t.text :consent_text                                # 동의 시점에 보여준 약관 원문
      t.string :ip_address
      t.string :user_agent
      t.datetime :consented_at
      t.datetime :revoked_at
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :pro_consents, [:owner_id, :consent_type]
  end
end
