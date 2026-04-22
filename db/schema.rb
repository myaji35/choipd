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

ActiveRecord::Schema[8.1].define(version: 2026_04_22_020411) do
  create_table "ab_test_participants", force: :cascade do |t|
    t.integer "ab_test_id", null: false
    t.datetime "assigned_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "conversion_value"
    t.boolean "converted", default: false
    t.datetime "converted_at"
    t.text "metadata"
    t.string "session_id", null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "user_id"
    t.string "variant", null: false
    t.index ["ab_test_id", "variant"], name: "index_ab_test_participants_on_ab_test_id_and_variant"
    t.index ["ab_test_id"], name: "index_ab_test_participants_on_ab_test_id"
    t.index ["session_id"], name: "index_ab_test_participants_on_session_id"
  end

  create_table "ab_tests", force: :cascade do |t|
    t.integer "confidence_level", default: 95
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "description"
    t.datetime "end_date"
    t.text "hypothesis"
    t.string "name", null: false
    t.text "results"
    t.datetime "start_date"
    t.string "status", default: "draft", null: false
    t.string "target_metric", null: false
    t.integer "tenant_id", default: 1, null: false
    t.integer "total_participants", default: 0
    t.text "traffic_allocation", null: false
    t.datetime "updated_at", null: false
    t.text "variants", null: false
    t.string "winner"
    t.index ["status"], name: "index_ab_tests_on_status"
    t.index ["tenant_id"], name: "index_ab_tests_on_tenant_id"
  end

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

  create_table "ai_generated_contents", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.text "generated_text", null: false
    t.integer "max_tokens"
    t.text "metadata"
    t.string "model", null: false
    t.text "prompt", null: false
    t.string "status", default: "draft", null: false
    t.integer "temperature"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.integer "used_in_content_id"
    t.string "user_id", null: false
    t.string "user_type", null: false
    t.index ["tenant_id"], name: "index_ai_generated_contents_on_tenant_id"
  end

  create_table "ai_recommendations", force: :cascade do |t|
    t.boolean "clicked", default: false
    t.datetime "clicked_at"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "metadata"
    t.text "reason"
    t.string "recommendation_type", null: false
    t.integer "score", null: false
    t.integer "target_id", null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "user_id", null: false
    t.string "user_type", null: false
    t.index ["user_id", "recommendation_type"], name: "index_ai_recommendations_on_user_id_and_recommendation_type"
  end

  create_table "analytics_events", force: :cascade do |t|
    t.string "browser"
    t.string "city"
    t.string "country"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "device_type"
    t.string "event_action"
    t.string "event_category", null: false
    t.string "event_label"
    t.string "event_name", null: false
    t.integer "event_value"
    t.string "ip_address"
    t.text "metadata"
    t.string "os"
    t.string "page_path"
    t.string "page_title"
    t.string "referrer"
    t.string "session_id"
    t.integer "tenant_id", default: 1, null: false
    t.string "user_agent"
    t.string "user_id"
    t.string "user_type"
    t.index ["event_name"], name: "index_analytics_events_on_event_name"
    t.index ["tenant_id", "created_at"], name: "index_analytics_events_on_tenant_id_and_created_at"
    t.index ["user_id"], name: "index_analytics_events_on_user_id"
  end

  create_table "automation_templates", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "description", null: false
    t.string "difficulty", default: "beginner", null: false
    t.integer "estimated_time"
    t.string "icon", default: "zap"
    t.boolean "is_public", default: true, null: false
    t.string "name", null: false
    t.integer "popularity", default: 0, null: false
    t.text "required_integrations"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.text "workflow_template", null: false
    t.index ["category"], name: "index_automation_templates_on_category"
    t.index ["tenant_id"], name: "index_automation_templates_on_tenant_id"
  end

  create_table "chatbot_conversations", force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "intent"
    t.text "message", null: false
    t.text "metadata"
    t.string "role", null: false
    t.string "session_id", null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "user_id"
    t.string "user_type", null: false
    t.index ["session_id", "created_at"], name: "index_chatbot_conversations_on_session_id_and_created_at"
  end

  create_table "cohort_users", force: :cascade do |t|
    t.integer "cohort_id", null: false
    t.datetime "joined_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "metadata"
    t.integer "tenant_id", default: 1, null: false
    t.string "user_email"
    t.string "user_id", null: false
    t.index ["cohort_id"], name: "index_cohort_users_on_cohort_id"
  end

  create_table "cohorts", force: :cascade do |t|
    t.string "cohort_type", null: false
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "criteria", null: false
    t.text "description"
    t.datetime "end_date", null: false
    t.text "metrics"
    t.string "name", null: false
    t.datetime "start_date", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.integer "user_count", default: 0, null: false
    t.index ["tenant_id"], name: "index_cohorts_on_tenant_id"
  end

  create_table "content_embeddings", force: :cascade do |t|
    t.integer "content_id", null: false
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.text "embedding", null: false
    t.string "embedding_model", null: false
    t.text "metadata"
    t.integer "tenant_id", default: 1, null: false
    t.text "text_content", null: false
    t.datetime "updated_at", null: false
    t.index ["content_type", "content_id"], name: "index_content_embeddings_on_content_type_and_content_id"
  end

  create_table "content_quality_scores", force: :cascade do |t|
    t.datetime "analyzed_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "analyzed_by", null: false
    t.integer "content_id", null: false
    t.string "content_type", null: false
    t.integer "engagement_score"
    t.text "keyword_density"
    t.integer "overall_score", null: false
    t.integer "readability_score"
    t.integer "sentiment_score"
    t.integer "seo_score"
    t.text "suggestions"
    t.integer "tenant_id", default: 1, null: false
    t.index ["content_type", "content_id"], name: "index_content_quality_scores_on_content_type_and_content_id"
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

  create_table "custom_reports", force: :cascade do |t|
    t.text "chart_config"
    t.string "chart_type"
    t.text "columns", null: false
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.string "data_source", null: false
    t.text "description"
    t.text "filters"
    t.text "group_by"
    t.boolean "is_public", default: false
    t.string "name", null: false
    t.text "order_by"
    t.text "recipients"
    t.string "report_type", null: false
    t.text "schedule"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_custom_reports_on_tenant_id"
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
    t.string "identity_filename"
    t.text "identity_json"
    t.text "identity_md"
    t.datetime "identity_parsed_at"
    t.datetime "identity_updated_at"
    t.string "name"
    t.string "phone"
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

  create_table "faq_knowledge_bases", force: :cascade do |t|
    t.text "answer", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.integer "helpful_count", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.text "keywords", null: false
    t.integer "match_count", default: 0, null: false
    t.integer "not_helpful_count", default: 0, null: false
    t.integer "priority", default: 0, null: false
    t.text "question", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "category"], name: "index_faq_knowledge_bases_on_tenant_id_and_category"
  end

  create_table "funnels", force: :cascade do |t|
    t.text "conversion_data"
    t.integer "conversion_window", default: 7
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "description"
    t.string "name", null: false
    t.text "steps", null: false
    t.integer "tenant_id", default: 1, null: false
    t.integer "total_users", default: 0
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_funnels_on_tenant_id"
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

  create_table "image_auto_tags", force: :cascade do |t|
    t.boolean "adult_content", default: false
    t.text "categories", null: false
    t.text "colors"
    t.integer "confidence", null: false
    t.integer "content_id", null: false
    t.string "content_type", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "image_url", null: false
    t.string "model", null: false
    t.text "objects"
    t.text "ocr_text"
    t.text "tags", null: false
    t.integer "tenant_id", default: 1, null: false
    t.index ["content_type", "content_id"], name: "index_image_auto_tags_on_content_type_and_content_id"
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

  create_table "integrations", force: :cascade do |t|
    t.text "config"
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "credentials", null: false
    t.text "error_message"
    t.boolean "is_enabled", default: true, null: false
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.string "provider", null: false
    t.text "scopes"
    t.string "sync_status", default: "active"
    t.integer "tenant_id", default: 1, null: false
    t.string "type_name", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_url"
    t.index ["provider"], name: "index_integrations_on_provider"
    t.index ["tenant_id"], name: "index_integrations_on_tenant_id"
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

  create_table "kakao_alerts", force: :cascade do |t|
    t.boolean "acknowledged", default: false
    t.datetime "acknowledged_at"
    t.string "alert_type", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "kakao_channel_id", null: false
    t.integer "kakao_message_id", null: false
    t.string "keyword"
    t.text "reason"
    t.integer "severity", default: 1
    t.integer "tenant_id", default: 1, null: false
    t.index ["kakao_channel_id", "acknowledged"], name: "index_kakao_alerts_on_kakao_channel_id_and_acknowledged"
    t.index ["kakao_channel_id"], name: "index_kakao_alerts_on_kakao_channel_id"
    t.index ["kakao_message_id"], name: "index_kakao_alerts_on_kakao_message_id"
  end

  create_table "kakao_channels", force: :cascade do |t|
    t.string "access_token_encrypted"
    t.string "channel_id", null: false
    t.string "channel_name"
    t.datetime "connected_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "last_sync_at"
    t.string "owner_id", null: false
    t.string "owner_type", default: "AdminUser"
    t.string "refresh_token_encrypted"
    t.string "status", default: "pending", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["channel_id"], name: "index_kakao_channels_on_channel_id", unique: true
    t.index ["owner_id"], name: "index_kakao_channels_on_owner_id"
    t.index ["tenant_id"], name: "index_kakao_channels_on_tenant_id"
  end

  create_table "kakao_keywords", force: :cascade do |t|
    t.string "category", default: "general"
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true
    t.string "keyword", null: false
    t.string "owner_id", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.integer "weight", default: 50
    t.index ["owner_id", "keyword"], name: "index_kakao_keywords_on_owner_id_and_keyword", unique: true
  end

  create_table "kakao_messages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "kakao_channel_id", null: false
    t.string "message_type", default: "text"
    t.boolean "purged", default: false
    t.string "question_kind"
    t.datetime "received_at", null: false
    t.boolean "replied", default: false, null: false
    t.datetime "replied_at"
    t.string "sender_display"
    t.string "sender_kakao_id", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.integer "urgency_score", default: 0
    t.index ["kakao_channel_id", "received_at"], name: "index_kakao_messages_on_kakao_channel_id_and_received_at"
    t.index ["kakao_channel_id"], name: "index_kakao_messages_on_kakao_channel_id"
    t.index ["replied", "urgency_score"], name: "index_kakao_messages_on_replied_and_urgency_score"
  end

  create_table "kakao_summaries", force: :cascade do |t|
    t.text "daily_summary_lines", null: false
    t.datetime "generated_at", null: false
    t.integer "kakao_channel_id", null: false
    t.string "model", default: "stub-1.0"
    t.text "must_reply_lines", null: false
    t.boolean "pushed", default: false
    t.datetime "pushed_at"
    t.date "summary_date", null: false
    t.integer "tenant_id", default: 1, null: false
    t.integer "total_messages", default: 0
    t.integer "unanswered_count", default: 0
    t.integer "urgent_count", default: 0
    t.index ["kakao_channel_id", "summary_date"], name: "index_kakao_summaries_on_kakao_channel_id_and_summary_date", unique: true
    t.index ["kakao_channel_id"], name: "index_kakao_summaries_on_kakao_channel_id"
  end

  create_table "kanban_columns", force: :cascade do |t|
    t.string "color", default: "#6b7280"
    t.datetime "created_at", null: false
    t.integer "kanban_project_id", null: false
    t.integer "sort_order"
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["kanban_project_id"], name: "index_kanban_columns_on_kanban_project_id"
    t.index ["tenant_id"], name: "index_kanban_columns_on_tenant_id"
  end

  create_table "kanban_projects", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon", default: "folder"
    t.boolean "is_archived", default: false
    t.integer "sort_order", default: 0
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_kanban_projects_on_tenant_id"
  end

  create_table "kanban_tasks", force: :cascade do |t|
    t.string "assignee"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "due_date"
    t.boolean "is_completed", default: false
    t.integer "kanban_column_id", null: false
    t.text "labels"
    t.string "priority"
    t.integer "project_id"
    t.integer "sort_order"
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["kanban_column_id"], name: "index_kanban_tasks_on_kanban_column_id"
    t.index ["project_id"], name: "index_kanban_tasks_on_project_id"
    t.index ["tenant_id"], name: "index_kanban_tasks_on_tenant_id"
  end

  create_table "leads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "subscribed_at"
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "email"], name: "idx_leads_tenant_email", unique: true
  end

  create_table "member_bookings", force: :cascade do |t|
    t.string "booking_type"
    t.text "description"
    t.string "external_url"
    t.integer "member_id", null: false
    t.integer "tenant_id", default: 1, null: false
    t.index ["member_id"], name: "index_member_bookings_on_member_id"
    t.index ["tenant_id"], name: "index_member_bookings_on_tenant_id"
  end

  create_table "member_documents", force: :cascade do |t|
    t.string "category", default: "other", null: false
    t.string "content_hash", null: false
    t.text "content_md", null: false
    t.text "extracted_entities", default: "{}"
    t.integer "extracted_skills_count", default: 0
    t.string "filename", null: false
    t.integer "member_id", null: false
    t.datetime "parsed_at"
    t.integer "size_bytes", default: 0
    t.text "tags", default: "[]", null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "title"
    t.datetime "uploaded_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["member_id", "content_hash"], name: "idx_member_documents_hash", unique: true
    t.index ["member_id"], name: "index_member_documents_on_member_id"
  end

  create_table "member_gap_reports", force: :cascade do |t|
    t.integer "completeness_score", default: 0
    t.text "gaps_json", default: "[]", null: false
    t.datetime "generated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "growth_path_json", default: "[]", null: false
    t.integer "member_id", null: false
    t.text "opportunities_json", default: "[]", null: false
    t.integer "peer_sample_size", default: 0
    t.string "profession", null: false
    t.text "radar_median", null: false
    t.text "radar_self", null: false
    t.text "radar_top10", null: false
    t.integer "tenant_id", default: 1, null: false
    t.index ["member_id"], name: "index_member_gap_reports_on_member_id"
  end

  create_table "member_inquiries", force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.integer "is_read", default: 0
    t.integer "member_id", null: false
    t.text "message", null: false
    t.string "sender_email", null: false
    t.string "sender_name", null: false
    t.integer "tenant_id", default: 1, null: false
    t.index ["member_id"], name: "index_member_inquiries_on_member_id"
    t.index ["tenant_id"], name: "index_member_inquiries_on_tenant_id"
  end

  create_table "member_photos", force: :cascade do |t|
    t.string "caption"
    t.string "category", default: "daily"
    t.datetime "created_at", null: false
    t.integer "file_size"
    t.integer "height"
    t.integer "member_id", null: false
    t.integer "sort_order", default: 0
    t.datetime "taken_at"
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at"
    t.integer "width"
    t.index ["member_id", "category"], name: "index_member_photos_on_member_id_and_category"
    t.index ["member_id", "uploaded_at"], name: "index_member_photos_on_member_id_and_uploaded_at"
    t.index ["member_id"], name: "index_member_photos_on_member_id"
  end

  create_table "member_portfolio_items", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.text "description"
    t.string "media_type"
    t.string "media_url", null: false
    t.integer "member_id", null: false
    t.integer "sort_order", default: 0
    t.integer "tenant_id", default: 1, null: false
    t.string "title", null: false
    t.index ["member_id"], name: "index_member_portfolio_items_on_member_id"
    t.index ["tenant_id"], name: "index_member_portfolio_items_on_tenant_id"
  end

  create_table "member_posts", force: :cascade do |t|
    t.string "category"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "is_published", default: 0
    t.integer "member_id", null: false
    t.datetime "published_at"
    t.integer "tenant_id", default: 1, null: false
    t.string "thumbnail_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_member_posts_on_member_id"
    t.index ["tenant_id"], name: "index_member_posts_on_tenant_id"
  end

  create_table "member_reviews", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "is_approved", default: 0
    t.integer "member_id", null: false
    t.integer "rating", null: false
    t.string "reviewer_email"
    t.string "reviewer_name", null: false
    t.string "source", default: "public_form"
    t.string "status", default: "new", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_member_reviews_on_member_id"
    t.index ["status"], name: "index_member_reviews_on_status"
    t.index ["tenant_id"], name: "index_member_reviews_on_tenant_id"
  end

  create_table "member_services", force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.string "cta_label"
    t.string "cta_url"
    t.text "description"
    t.string "image_url"
    t.integer "is_active", default: 1
    t.integer "member_id", null: false
    t.string "price"
    t.string "price_label"
    t.integer "sort_order", default: 0
    t.integer "tenant_id", default: 1, null: false
    t.string "title", null: false
    t.index ["member_id"], name: "index_member_services_on_member_id"
    t.index ["tenant_id"], name: "index_member_services_on_tenant_id"
  end

  create_table "member_skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "level", default: "intermediate", null: false
    t.integer "member_id", null: false
    t.integer "skill_id", null: false
    t.string "source", default: "self", null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.integer "weight", default: 50, null: false
    t.integer "years_experience"
    t.index ["member_id", "skill_id"], name: "idx_member_skills_unique", unique: true
    t.index ["member_id"], name: "index_member_skills_on_member_id"
    t.index ["skill_id"], name: "index_member_skills_on_skill_id"
  end

  create_table "members", force: :cascade do |t|
    t.text "bio"
    t.string "business_type"
    t.string "cover_image"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.text "enabled_modules", default: "[]"
    t.integer "featured_order", default: 0
    t.datetime "impd_completed_at"
    t.datetime "impd_started_at"
    t.string "impd_status", default: "none", null: false
    t.text "impd_steps_data", default: "{}"
    t.string "impd_verification_id"
    t.integer "is_featured", default: 0
    t.datetime "last_sign_in_at"
    t.string "name", null: false
    t.string "password_digest"
    t.string "phone"
    t.string "profession"
    t.string "profile_image"
    t.string "region"
    t.text "rejection_reason"
    t.string "slug", null: false
    t.text "social_links"
    t.string "status", default: "pending_approval", null: false
    t.string "subscription_plan", default: "basic"
    t.integer "tenant_id", default: 1, null: false
    t.text "theme_config", default: "{}"
    t.string "townin_email"
    t.string "townin_name"
    t.string "townin_role"
    t.string "towningraph_user_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_members_on_email"
    t.index ["impd_status"], name: "index_members_on_impd_status"
    t.index ["impd_verification_id"], name: "index_members_on_impd_verification_id", unique: true
    t.index ["slug"], name: "index_members_on_slug", unique: true
    t.index ["tenant_id"], name: "index_members_on_tenant_id"
    t.index ["towningraph_user_id"], name: "index_members_on_towningraph_user_id", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.boolean "is_read", default: false, null: false
    t.string "link"
    t.text "message"
    t.string "notification_type"
    t.datetime "read_at"
    t.integer "related_id"
    t.string "related_type"
    t.integer "tenant_id", default: 1, null: false
    t.string "title", null: false
    t.integer "user_id"
    t.index ["tenant_id", "user_id", "is_read"], name: "idx_notifications_user_unread"
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

  create_table "pro_consents", force: :cascade do |t|
    t.text "consent_text"
    t.string "consent_type", null: false
    t.boolean "consented", default: false, null: false
    t.datetime "consented_at"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "ip_address"
    t.string "owner_id", null: false
    t.datetime "revoked_at"
    t.integer "tenant_id", default: 1, null: false
    t.string "user_agent"
    t.index ["owner_id", "consent_type"], name: "index_pro_consents_on_owner_id_and_consent_type"
  end

  create_table "pro_subscriptions", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.text "metadata"
    t.string "owner_id", null: false
    t.string "owner_type", default: "AdminUser"
    t.string "payment_method"
    t.integer "price_krw"
    t.string "status", default: "trial", null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "tier", default: "pro", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_pro_subscriptions_on_owner_id", unique: true
  end

  create_table "rfm_segments", force: :cascade do |t|
    t.datetime "calculated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "frequency_score", null: false
    t.datetime "last_activity_at"
    t.integer "monetary_score", null: false
    t.integer "recency_score", null: false
    t.string "rfm_segment", null: false
    t.integer "tenant_id", default: 1, null: false
    t.integer "total_revenue", default: 0
    t.integer "total_transactions", default: 0
    t.string "user_id", null: false
    t.string "user_type", null: false
    t.index ["rfm_segment"], name: "index_rfm_segments_on_rfm_segment"
    t.index ["tenant_id"], name: "index_rfm_segments_on_tenant_id"
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

  create_table "skills", force: :cascade do |t|
    t.text "aliases", default: "[]", null: false
    t.string "axis"
    t.string "canonical_name", null: false
    t.string "category", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "description"
    t.integer "tenant_id", default: 1, null: false
    t.index ["axis"], name: "index_skills_on_axis"
    t.index ["tenant_id", "canonical_name"], name: "index_skills_on_tenant_id_and_canonical_name", unique: true
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

  create_table "user_activity_patterns", force: :cascade do |t|
    t.text "active_days_of_week"
    t.text "active_hours"
    t.integer "average_session_duration"
    t.string "churn_risk", default: "low"
    t.datetime "created_at", null: false
    t.integer "engagement_score", default: 0, null: false
    t.string "last_activity_type"
    t.datetime "last_analyzed_at"
    t.text "preferred_categories"
    t.integer "tenant_id", default: 1, null: false
    t.integer "total_sessions", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.string "user_type", null: false
    t.index ["user_id"], name: "index_user_activity_patterns_on_user_id", unique: true
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.integer "attempt_number", default: 1, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "error"
    t.string "event", null: false
    t.text "payload", null: false
    t.text "response_body"
    t.integer "response_code"
    t.string "status", null: false
    t.integer "tenant_id", default: 1, null: false
    t.integer "webhook_id", null: false
    t.index ["webhook_id", "created_at"], name: "index_webhook_logs_on_webhook_id_and_created_at"
    t.index ["webhook_id"], name: "index_webhook_logs_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "events", null: false
    t.integer "failure_count", default: 0, null: false
    t.text "headers"
    t.boolean "is_active", default: true, null: false
    t.datetime "last_triggered_at"
    t.string "name", null: false
    t.text "retry_config"
    t.string "secret", null: false
    t.integer "success_count", default: 0, null: false
    t.integer "tenant_id", default: 1, null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["tenant_id"], name: "index_webhooks_on_tenant_id"
  end

  create_table "workflow_executions", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "duration"
    t.text "error"
    t.text "metadata"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.text "steps"
    t.integer "tenant_id", default: 1, null: false
    t.string "trigger", null: false
    t.text "trigger_data"
    t.integer "workflow_id", null: false
    t.index ["workflow_id", "created_at"], name: "index_workflow_executions_on_workflow_id_and_created_at"
    t.index ["workflow_id"], name: "index_workflow_executions_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.text "actions", null: false
    t.datetime "created_at", null: false
    t.string "created_by", null: false
    t.text "description"
    t.integer "execution_count", default: 0, null: false
    t.integer "failure_count", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "last_executed_at"
    t.string "name", null: false
    t.integer "success_count", default: 0, null: false
    t.integer "tenant_id", default: 1, null: false
    t.string "trigger", null: false
    t.text "trigger_config", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_workflows_on_tenant_id"
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

  add_foreign_key "ab_test_participants", "ab_tests", on_delete: :cascade
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cohort_users", "cohorts", on_delete: :cascade
  add_foreign_key "distributor_activity_logs", "distributors"
  add_foreign_key "enrollments", "courses", on_delete: :cascade
  add_foreign_key "invoices", "distributors"
  add_foreign_key "invoices", "payments"
  add_foreign_key "kakao_alerts", "kakao_channels", on_delete: :cascade
  add_foreign_key "kakao_alerts", "kakao_messages", on_delete: :cascade
  add_foreign_key "kakao_messages", "kakao_channels", on_delete: :cascade
  add_foreign_key "kakao_summaries", "kakao_channels", on_delete: :cascade
  add_foreign_key "kanban_columns", "kanban_projects"
  add_foreign_key "kanban_tasks", "kanban_columns"
  add_foreign_key "member_bookings", "members", on_delete: :cascade
  add_foreign_key "member_documents", "members", on_delete: :cascade
  add_foreign_key "member_gap_reports", "members", on_delete: :cascade
  add_foreign_key "member_inquiries", "members", on_delete: :cascade
  add_foreign_key "member_photos", "members"
  add_foreign_key "member_portfolio_items", "members", on_delete: :cascade
  add_foreign_key "member_posts", "members", on_delete: :cascade
  add_foreign_key "member_reviews", "members", on_delete: :cascade
  add_foreign_key "member_services", "members", on_delete: :cascade
  add_foreign_key "member_skills", "members", on_delete: :cascade
  add_foreign_key "member_skills", "skills", on_delete: :cascade
  add_foreign_key "payments", "distributors"
  add_foreign_key "sns_post_histories", "sns_scheduled_posts"
  add_foreign_key "webhook_logs", "webhooks", on_delete: :cascade
  add_foreign_key "workflow_executions", "workflows", on_delete: :cascade
end
