# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_20_103700) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "admin"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "courses", force: :cascade do |t|
    t.string "course_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_link"
    t.integer "price"
    t.boolean "published", default: false, null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["course_type"], name: "index_courses_on_course_type"
    t.index ["published"], name: "index_courses_on_published"
    t.index ["tenant_id"], name: "index_courses_on_tenant_id"
  end

  create_table "distributor_activity_logs", force: :cascade do |t|
    t.string "activity_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "distributor_id", null: false
    t.text "metadata"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["distributor_id"], name: "index_distributor_activity_logs_on_distributor_id"
    t.index ["tenant_id"], name: "index_distributor_activity_logs_on_tenant_id"
  end

  create_table "distributor_resources", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.integer "download_count", default: 0, null: false
    t.string "file_type"
    t.string "file_url"
    t.string "required_plan"
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_distributor_resources_on_category"
    t.index ["required_plan"], name: "index_distributor_resources_on_required_plan"
    t.index ["tenant_id"], name: "index_distributor_resources_on_tenant_id"
  end

  create_table "distributors", force: :cascade do |t|
    t.datetime "approved_at"
    t.string "business_type"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "region"
    t.string "slug"
    t.string "status"
    t.string "subscription_plan"
    t.integer "tenant_id", default: 1, null: false
    t.decimal "total_revenue", precision: 15, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_distributors_on_email", unique: true
    t.index ["slug"], name: "index_distributors_on_slug", unique: true
    t.index ["status"], name: "index_distributors_on_status"
    t.index ["subscription_plan"], name: "index_distributors_on_subscription_plan"
    t.index ["tenant_id"], name: "index_distributors_on_tenant_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.integer "amount"
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.string "external_order_id"
    t.json "metadata"
    t.datetime "paid_at"
    t.string "provider", null: false
    t.datetime "refunded_at"
    t.string "status", default: "pending", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["provider", "external_order_id"], name: "uq_enrollments_provider_order", unique: true
    t.index ["tenant_id"], name: "index_enrollments_on_tenant_id"
    t.index ["user_id"], name: "index_enrollments_on_user_id"
  end

  create_table "hero_images", force: :cascade do |t|
    t.string "alt_text"
    t.datetime "created_at", null: false
    t.integer "display_order"
    t.integer "file_size"
    t.string "filename"
    t.integer "height"
    t.boolean "is_active"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.string "upload_status", default: "pending", null: false
    t.datetime "uploaded_at"
    t.string "url"
    t.integer "width"
    t.index ["tenant_id"], name: "index_hero_images_on_tenant_id"
  end

  create_table "inquiries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "inquiry_type"
    t.text "message"
    t.string "name"
    t.string "phone"
    t.string "status", default: "pending"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["inquiry_type"], name: "index_inquiries_on_inquiry_type"
    t.index ["status"], name: "index_inquiries_on_status"
    t.index ["tenant_id"], name: "index_inquiries_on_tenant_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.integer "distributor_id", null: false
    t.datetime "issued_at"
    t.integer "payment_id", null: false
    t.string "status"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["distributor_id"], name: "index_invoices_on_distributor_id"
    t.index ["payment_id"], name: "index_invoices_on_payment_id"
    t.index ["tenant_id"], name: "index_invoices_on_tenant_id"
  end

  create_table "kanban_columns", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kanban_project_id", null: false
    t.integer "position"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["kanban_project_id"], name: "index_kanban_columns_on_kanban_project_id"
  end

  create_table "kanban_projects", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "kanban_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.integer "kanban_column_id", null: false
    t.text "labels"
    t.integer "position"
    t.string "priority"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["kanban_column_id"], name: "index_kanban_tasks_on_kanban_column_id"
  end

  create_table "leads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "subscribed_at"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_leads_on_email", unique: true
    t.index ["tenant_id", "email"], name: "idx_leads_tenant_email", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.integer "distributor_id", null: false
    t.datetime "paid_at"
    t.string "payment_method"
    t.string "status"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["distributor_id"], name: "index_payments_on_distributor_id"
    t.index ["tenant_id"], name: "index_payments_on_tenant_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "category"
    t.text "content"
    t.datetime "created_at", null: false
    t.boolean "published", default: false, null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_posts_on_category"
    t.index ["published"], name: "index_posts_on_published"
    t.index ["tenant_id"], name: "index_posts_on_tenant_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_settings_on_key", unique: true
    t.index ["tenant_id", "key"], name: "idx_settings_tenant_key", unique: true
  end

  create_table "sns_accounts", force: :cascade do |t|
    t.text "access_token_encrypted"
    t.string "account_name"
    t.datetime "created_at", null: false
    t.boolean "is_active"
    t.string "platform"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_sns_accounts_on_tenant_id"
  end

  create_table "sns_post_histories", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.text "response"
    t.integer "sns_scheduled_post_id", null: false
    t.string "status"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["sns_scheduled_post_id"], name: "index_sns_post_histories_on_sns_scheduled_post_id"
    t.index ["tenant_id"], name: "index_sns_post_histories_on_tenant_id"
  end

  create_table "sns_scheduled_posts", force: :cascade do |t|
    t.integer "content_id"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.text "message"
    t.string "platform"
    t.datetime "scheduled_at"
    t.string "status"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_sns_scheduled_posts_on_tenant_id"
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "features"
    t.integer "max_distributors"
    t.string "name"
    t.integer "price"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_subscription_plans_on_tenant_id"
  end

  create_table "works", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_works_on_tenant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "distributor_activity_logs", "distributors"
  add_foreign_key "enrollments", "courses", on_delete: :cascade
  add_foreign_key "invoices", "distributors"
  add_foreign_key "invoices", "payments"
  add_foreign_key "kanban_columns", "kanban_projects"
  add_foreign_key "kanban_tasks", "kanban_columns"
  add_foreign_key "payments", "distributors"
  add_foreign_key "sns_post_histories", "sns_scheduled_posts"
end
