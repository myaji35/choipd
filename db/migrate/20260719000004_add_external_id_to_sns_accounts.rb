class AddExternalIdToSnsAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :sns_accounts, :external_id, :string
    # SnsScheduledPost가 belongs_to :sns_account를 선언했으나 컬럼이 없던 기존 불일치 보강(ISS-110).
    add_reference :sns_scheduled_posts, :sns_account, foreign_key: true, null: true unless column_exists?(:sns_scheduled_posts, :sns_account_id)
  end
end
