class CreateAi < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_recommendations do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :user_id, null: false
      t.string :user_type, null: false   # distributor | pd | customer
      t.string :recommendation_type, null: false # resource | course | post | distributor
      t.integer :target_id, null: false
      t.integer :score, null: false      # 0-100
      t.text :reason
      t.text :metadata
      t.boolean :clicked, default: false
      t.datetime :clicked_at
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :ai_recommendations, [:user_id, :recommendation_type]

    create_table :content_embeddings do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :content_type, null: false  # resource | course | post | work
      t.integer :content_id, null: false
      t.string :embedding_model, null: false
      t.text :embedding, null: false       # JSON array
      t.text :text_content, null: false
      t.text :metadata
      t.timestamps
    end
    add_index :content_embeddings, [:content_type, :content_id]

    create_table :chatbot_conversations do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :session_id, null: false
      t.string :user_id
      t.string :user_type, null: false     # distributor | pd | customer | anonymous
      t.string :role, null: false           # user | assistant | system
      t.text :message, null: false
      t.string :intent
      t.text :metadata
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :chatbot_conversations, [:session_id, :created_at]

    create_table :ai_generated_contents do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :content_type, null: false   # sns_post | email | description | summary | tag
      t.text :prompt, null: false
      t.text :generated_text, null: false
      t.string :model, null: false
      t.integer :temperature
      t.integer :max_tokens
      t.string :user_id, null: false
      t.string :user_type, null: false       # distributor | pd | admin
      t.string :status, default: "draft", null: false # draft | approved | rejected | published
      t.integer :used_in_content_id
      t.text :metadata
      t.timestamps
    end
    add_index :ai_generated_contents, :tenant_id

    create_table :content_quality_scores do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :content_type, null: false
      t.integer :content_id, null: false
      t.integer :overall_score, null: false
      t.integer :readability_score
      t.integer :seo_score
      t.integer :engagement_score
      t.integer :sentiment_score
      t.text :keyword_density
      t.text :suggestions
      t.string :analyzed_by, null: false
      t.datetime :analyzed_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :content_quality_scores, [:content_type, :content_id]

    create_table :image_auto_tags do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :image_url, null: false
      t.string :content_type, null: false
      t.integer :content_id, null: false
      t.text :tags, null: false
      t.text :categories, null: false
      t.text :objects
      t.text :colors
      t.text :ocr_text
      t.boolean :adult_content, default: false
      t.integer :confidence, null: false
      t.string :model, null: false
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end
    add_index :image_auto_tags, [:content_type, :content_id]

    create_table :faq_knowledge_bases do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :category, null: false       # general | distributor | payment | resource | technical
      t.text :question, null: false
      t.text :answer, null: false
      t.text :keywords, null: false
      t.integer :match_count, default: 0, null: false
      t.integer :helpful_count, default: 0, null: false
      t.integer :not_helpful_count, default: 0, null: false
      t.boolean :is_active, default: true, null: false
      t.integer :priority, default: 0, null: false
      t.string :created_by, null: false
      t.timestamps
    end
    add_index :faq_knowledge_bases, [:tenant_id, :category]

    create_table :user_activity_patterns do |t|
      t.integer :tenant_id, default: 1, null: false
      t.string :user_id, null: false
      t.string :user_type, null: false     # distributor | pd | customer
      t.text :preferred_categories
      t.text :active_hours
      t.text :active_days_of_week
      t.integer :average_session_duration
      t.integer :total_sessions, default: 0, null: false
      t.string :last_activity_type
      t.integer :engagement_score, default: 0, null: false
      t.string :churn_risk, default: "low"  # low | medium | high
      t.datetime :last_analyzed_at
      t.timestamps
    end
    add_index :user_activity_patterns, :user_id, unique: true
  end
end
