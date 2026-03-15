class CreateFoodCategoryMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :food_category_memberships do |t|
      t.references :food, null: false, foreign_key: true
      t.references :food_sensitivity_category, null: false, foreign_key: true
      t.integer :severity, null: false, default: 0 # 0=low, 1=medium, 2=high

      t.timestamps
    end

    add_index :food_category_memberships, [:food_id, :food_sensitivity_category_id],
              unique: true,
              name: "index_food_category_memberships_on_food_and_category"
  end
end
