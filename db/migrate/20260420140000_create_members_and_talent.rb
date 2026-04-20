class CreateMembersAndTalent < ActiveRecord::Migration[8.1]
  def change
    # ── members 도메인 (7 테이블) ────────────────────────
    create_table :members do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :towningraph_user_id
      t.string :townin_email
      t.string :townin_name
      t.string :townin_role
      t.string :slug, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :profile_image
      t.string :cover_image
      t.text :bio
      t.text :social_links     # JSON
      t.string :business_type  # individual | company | organization
      t.string :profession     # insurance_agent | realtor | educator | author | shopowner | freelancer | custom
      t.string :region
      t.string :status, default: "pending_approval", null: false
      t.string :subscription_plan, default: "basic"
      t.text :enabled_modules, default: "[]"  # JSON
      t.text :theme_config, default: "{}"     # JSON
      t.text :rejection_reason
      t.integer :is_featured, default: 0
      t.integer :featured_order, default: 0
      # IMPD 검증
      t.string :impd_status, default: "none", null: false
      t.datetime :impd_started_at
      t.datetime :impd_completed_at
      t.string :impd_verification_id
      t.text :impd_steps_data, default: "{}"
      t.timestamps
    end
    add_index :members, :tenant_id
    add_index :members, :slug, unique: true
    add_index :members, :email
    add_index :members, :impd_status
    add_index :members, :towningraph_user_id, unique: true
    add_index :members, :impd_verification_id, unique: true

    create_table :member_portfolio_items do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :title, null: false
      t.text :description
      t.string :media_url, null: false
      t.string :media_type
      t.string :category
      t.integer :sort_order, default: 0
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :member_portfolio_items, :tenant_id

    create_table :member_services do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :title, null: false
      t.text :description
      t.string :price
      t.string :price_label
      t.string :cta_url
      t.string :cta_label
      t.string :image_url
      t.integer :sort_order, default: 0
      t.integer :is_active, default: 1
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :member_services, :tenant_id

    create_table :member_posts do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.string :category
      t.string :thumbnail_url
      t.integer :is_published, default: 0
      t.datetime :published_at
      t.timestamps
    end
    add_index :member_posts, :tenant_id

    create_table :member_inquiries do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :sender_name, null: false
      t.string :sender_email, null: false
      t.text :message, null: false
      t.integer :is_read, default: 0
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :member_inquiries, :tenant_id

    create_table :member_reviews do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :reviewer_name, null: false
      t.string :reviewer_email
      t.integer :rating, null: false
      t.text :content
      t.integer :is_approved, default: 0
      t.string :status, default: "new", null: false  # new | triaged | responded | archived
      t.string :source, default: "public_form"        # public_form | admin_submitted
      t.timestamps
    end
    add_index :member_reviews, :tenant_id
    add_index :member_reviews, :status

    create_table :member_bookings do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :booking_type
      t.string :external_url
      t.text :description
    end
    add_index :member_bookings, :tenant_id

    # ── talent 도메인 (4 테이블) ────────────────────────
    create_table :skills do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :canonical_name, null: false
      t.text :aliases, default: "[]", null: false  # JSON
      t.string :category, null: false               # hard | meta | context
      t.string :axis                                 # expertise | communication | marketing | operations | data | network
      t.text :description
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :skills, [:tenant_id, :canonical_name], unique: true
    add_index :skills, :axis

    create_table :member_skills do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.references :skill, foreign_key: { on_delete: :cascade }, null: false
      t.string :level, default: "intermediate", null: false  # novice | intermediate | expert
      t.integer :years_experience
      t.integer :weight, default: 50, null: false
      t.string :source, default: "self", null: false  # self | document | review | verified
      t.datetime :verified_at
      t.timestamps
    end
    add_index :member_skills, [:member_id, :skill_id], unique: true, name: "idx_member_skills_unique"

    create_table :member_documents do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :filename, null: false
      t.string :title
      t.string :category, default: "other", null: false  # bio | portfolio | curriculum | awards | interview | other
      t.text :tags, default: "[]", null: false
      t.text :content_md, null: false
      t.string :content_hash, null: false
      t.integer :size_bytes, default: 0
      t.datetime :parsed_at
      t.integer :extracted_skills_count, default: 0
      t.text :extracted_entities, default: "{}"
      t.datetime :uploaded_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :member_documents, [:member_id, :content_hash], unique: true, name: "idx_member_documents_hash"

    create_table :member_gap_reports do |t|
      t.integer :tenant_id, default: 1, null: false
      t.references :member, foreign_key: { on_delete: :cascade }, null: false
      t.string :profession, null: false
      t.integer :completeness_score, default: 0
      t.text :radar_self, null: false
      t.text :radar_median, null: false
      t.text :radar_top10, null: false
      t.text :gaps_json, default: "[]", null: false
      t.text :opportunities_json, default: "[]", null: false
      t.text :growth_path_json, default: "[]", null: false
      t.integer :peer_sample_size, default: 0
      t.datetime :generated_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
  end
end
