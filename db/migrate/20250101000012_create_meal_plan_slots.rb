class CreateMealPlanSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plan_slots do |t|
      t.references :meal_plan, null: false, foreign_key: true
      t.date :scheduled_for, null: false
      t.string :meal_time, null: false  # breakfast, lunch, dinner
      t.references :meal, null: true, foreign_key: true

      t.timestamps
    end

    add_index :meal_plan_slots, [:meal_plan_id, :scheduled_for, :meal_time],
              unique: true,
              name: "index_meal_plan_slots_on_plan_date_mealtime"
  end
end
