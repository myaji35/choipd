class CreateShortLinks < ActiveRecord::Migration[8.1]
  # 짧은 URL 테이블. impd.townin.net/s/:hash_code → target_path 리다이렉트.
  # target_path 는 내부 경로만 허용 (ShortLink 모델 validation).
  # QR 코드 내용, 카톡 공유, 명함 등에 사용.
  def change
    create_table :short_links do |t|
      t.string :hash_code, limit: 12, null: false
      t.string :target_path, null: false                    # 예: "/choi-pd", "/promo/watch"
      t.references :member, null: true, foreign_key: true    # nullable: 시스템 생성 short link
      t.integer :click_count, null: false, default: 0
      t.datetime :last_clicked_at
      t.timestamps
    end
    add_index :short_links, :hash_code, unique: true
  end
end
