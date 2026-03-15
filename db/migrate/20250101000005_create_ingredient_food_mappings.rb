class CreateIngredientFoodMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredient_food_mappings do |t|
      t.references :ingredient, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true

      t.timestamps
    end

    add_index :ingredient_food_mappings, [:ingredient_id, :food_id], unique: true
  end
end
