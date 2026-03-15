class CreateSymptomLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :symptom_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :symptom_type, null: false, foreign_key: true
      t.timestamp :logged_at, null: false
      t.integer :score, null: false  # 1-5
      t.text :notes

      t.timestamps
    end

    add_index :symptom_logs, [:user_id, :logged_at]
  end
end
