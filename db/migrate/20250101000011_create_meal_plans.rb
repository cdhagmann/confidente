class CreateMealPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false

      t.timestamps
    end

    add_index :meal_plans, [:user_id, :starts_on]
  end
end
