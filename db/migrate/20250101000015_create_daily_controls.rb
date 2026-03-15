class CreateDailyControls < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_controls do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :sleep_hours, precision: 4, scale: 1
      t.integer :sleep_quality   # 1-5
      t.integer :stress_level    # 1-5
      t.string :exercise_intensity  # none, light, moderate, intense
      t.text :notes

      t.timestamps
    end

    add_index :daily_controls, [:user_id, :date], unique: true
  end
end
