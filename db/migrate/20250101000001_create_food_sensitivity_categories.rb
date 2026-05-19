class CreateFoodSensitivityCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :food_sensitivity_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      t.timestamps
    end

    add_index :food_sensitivity_categories, :slug, unique: true
  end
end
