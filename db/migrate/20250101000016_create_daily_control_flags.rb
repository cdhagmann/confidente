class CreateDailyControlFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_control_flags do |t|
      t.references :daily_control, null: false, foreign_key: true
      t.string :flag_type, null: false  # menstrual_phase, illness, medication, alcohol
      t.string :value, null: false

      t.timestamps
    end

    add_index :daily_control_flags, [:daily_control_id, :flag_type]
  end
end
