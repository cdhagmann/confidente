class CreateMealIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_ingredients do |t|
      t.references :meal, null: false, foreign_key: true
      t.references :ingredient, null: false, foreign_key: true
      t.references :food, null: true, foreign_key: true

      t.timestamps
    end

    add_index :meal_ingredients, [:meal_id, :ingredient_id]
  end
end
