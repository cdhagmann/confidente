class CreateWashoutWindows < ActiveRecord::Migration[8.1]
  def change
    create_table :washout_windows do |t|
      t.references :meal_plan, null: false, foreign_key: true
      t.references :food_sensitivity_category, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false

      t.timestamps
    end

    add_index :washout_windows, [:meal_plan_id, :food_sensitivity_category_id, :start_date],
              name: "index_washout_windows_on_plan_category_start"
  end
end
