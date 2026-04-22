class AddOauthFieldsToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :provider, :string                 # 'google_oauth2' 등
    add_column :members, :uid, :string                      # provider 계정 고유 ID
    add_column :members, :oauth_email_verified, :integer, default: 0
    add_column :members, :oauth_connected_at, :datetime
    add_column :members, :oauth_raw, :text                  # JSON (raw_info, 디버깅/감사용)

    add_index :members, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
  end
end
