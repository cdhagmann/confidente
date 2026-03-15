class CreateIntegrationSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :integration_sync_logs do |t|
      t.references :connected_integration, null: false, foreign_key: true
      t.timestamp :synced_at, null: false
      t.integer :records_imported, default: 0
      t.string :status, null: false  # success, partial, failed

      t.timestamps
    end

    add_index :integration_sync_logs, [:connected_integration_id, :synced_at]
  end
end
