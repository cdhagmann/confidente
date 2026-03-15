class CreateConnectedIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :connected_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false  # apple_health, google_fit, cronometer, clue, etc.
      t.text :access_token
      t.text :refresh_token
      t.string :scopes
      t.timestamp :last_synced_at

      t.timestamps
    end

    add_index :connected_integrations, [:user_id, :provider], unique: true
  end
end
