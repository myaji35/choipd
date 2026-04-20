class Phase1AlignWithNextjsSchema < ActiveRecord::Migration[8.1]
  # Next.js (LibSQL) → Rails 스키마 정합화
  # Phase 1 P0 — content (9) + distribution (6) + sns (3) = 18 테이블
  #
  # 변경 원칙:
  # 1. tenant_id 컬럼 추가 (default: 1) — Phase 4에서 멀티테넌시 본격 활성화
  # 2. Next.js에 있는데 Rails에 없는 컬럼 추가
  # 3. unique index / 복합 index 보강
  # 4. enrollments 테이블 신규 생성 (외부 결제 webhook 대장)

  def change
    # ── content (9) ────────────────────────────────────────────

    # courses: tenant_id 추가
    add_column :courses, :tenant_id, :integer, default: 1, null: false unless column_exists?(:courses, :tenant_id)
    add_index :courses, :tenant_id unless index_exists?(:courses, :tenant_id)

    # posts: tenant_id 추가
    add_column :posts, :tenant_id, :integer, default: 1, null: false unless column_exists?(:posts, :tenant_id)
    add_index :posts, :tenant_id unless index_exists?(:posts, :tenant_id)

    # works: tenant_id 추가
    add_column :works, :tenant_id, :integer, default: 1, null: false unless column_exists?(:works, :tenant_id)
    add_index :works, :tenant_id unless index_exists?(:works, :tenant_id)

    # inquiries: tenant_id 추가
    add_column :inquiries, :tenant_id, :integer, default: 1, null: false unless column_exists?(:inquiries, :tenant_id)
    add_index :inquiries, :tenant_id unless index_exists?(:inquiries, :tenant_id)

    # leads: tenant_id + 복합 unique
    add_column :leads, :tenant_id, :integer, default: 1, null: false unless column_exists?(:leads, :tenant_id)
    add_index :leads, [:tenant_id, :email], unique: true, name: 'idx_leads_tenant_email' unless index_exists?(:leads, [:tenant_id, :email])

    # settings: tenant_id + 복합 unique
    add_column :settings, :tenant_id, :integer, default: 1, null: false unless column_exists?(:settings, :tenant_id)
    add_index :settings, [:tenant_id, :key], unique: true, name: 'idx_settings_tenant_key' unless index_exists?(:settings, [:tenant_id, :key])

    # hero_images: 누락 컬럼 6개 추가 + tenant_id
    add_column :hero_images, :tenant_id, :integer, default: 1, null: false unless column_exists?(:hero_images, :tenant_id)
    add_column :hero_images, :url, :string unless column_exists?(:hero_images, :url)
    add_column :hero_images, :file_size, :integer unless column_exists?(:hero_images, :file_size)
    add_column :hero_images, :width, :integer unless column_exists?(:hero_images, :width)
    add_column :hero_images, :height, :integer unless column_exists?(:hero_images, :height)
    add_column :hero_images, :upload_status, :string, default: 'pending', null: false unless column_exists?(:hero_images, :upload_status)
    add_column :hero_images, :uploaded_at, :datetime unless column_exists?(:hero_images, :uploaded_at)
    add_index :hero_images, :tenant_id unless index_exists?(:hero_images, :tenant_id)

    # enrollments: 신규 테이블 (Next.js 외부 결제 webhook 대장)
    unless table_exists?(:enrollments)
      create_table :enrollments do |t|
        t.integer :tenant_id, default: 1, null: false
        t.string :user_id, null: false                  # session.userId
        t.references :course, foreign_key: { on_delete: :cascade }, null: false
        t.string :provider, null: false                  # toss / stripe / manual
        t.string :external_order_id                       # 멱등키
        t.integer :amount                                  # KRW
        t.string :status, default: 'pending', null: false # pending/paid/refunded/canceled
        t.datetime :paid_at
        t.datetime :refunded_at
        t.json :metadata                                   # webhook payload snapshot
        t.timestamps
      end
      add_index :enrollments, :tenant_id
      add_index :enrollments, :user_id
      add_index :enrollments, [:provider, :external_order_id], unique: true, name: 'uq_enrollments_provider_order'
    end

    # ── distribution (6) ────────────────────────────────────────

    add_column :distributors, :tenant_id, :integer, default: 1, null: false unless column_exists?(:distributors, :tenant_id)
    add_index  :distributors, :tenant_id unless index_exists?(:distributors, :tenant_id)

    add_column :distributor_activity_logs, :tenant_id, :integer, default: 1, null: false unless column_exists?(:distributor_activity_logs, :tenant_id)
    add_index  :distributor_activity_logs, :tenant_id unless index_exists?(:distributor_activity_logs, :tenant_id)

    add_column :distributor_resources, :tenant_id, :integer, default: 1, null: false unless column_exists?(:distributor_resources, :tenant_id)
    add_index  :distributor_resources, :tenant_id unless index_exists?(:distributor_resources, :tenant_id)

    add_column :subscription_plans, :tenant_id, :integer, default: 1, null: false unless column_exists?(:subscription_plans, :tenant_id)
    add_index  :subscription_plans, :tenant_id unless index_exists?(:subscription_plans, :tenant_id)

    add_column :payments, :tenant_id, :integer, default: 1, null: false unless column_exists?(:payments, :tenant_id)
    add_index  :payments, :tenant_id unless index_exists?(:payments, :tenant_id)

    add_column :invoices, :tenant_id, :integer, default: 1, null: false unless column_exists?(:invoices, :tenant_id)
    add_index  :invoices, :tenant_id unless index_exists?(:invoices, :tenant_id)

    # ── sns (3) ────────────────────────────────────────────────

    add_column :sns_accounts, :tenant_id, :integer, default: 1, null: false unless column_exists?(:sns_accounts, :tenant_id)
    add_index  :sns_accounts, :tenant_id unless index_exists?(:sns_accounts, :tenant_id)

    add_column :sns_scheduled_posts, :tenant_id, :integer, default: 1, null: false unless column_exists?(:sns_scheduled_posts, :tenant_id)
    add_index  :sns_scheduled_posts, :tenant_id unless index_exists?(:sns_scheduled_posts, :tenant_id)

    add_column :sns_post_histories, :tenant_id, :integer, default: 1, null: false unless column_exists?(:sns_post_histories, :tenant_id)
    add_index  :sns_post_histories, :tenant_id unless index_exists?(:sns_post_histories, :tenant_id)
  end
end
