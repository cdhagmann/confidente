class CreateHypothesisSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :hypothesis_suggestions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :suggested_food, null: false, foreign_key: { to_table: :foods }
      t.references :reason_category, null: false, foreign_key: { to_table: :food_sensitivity_categories }
      t.string :status, null: false, default: "pending"  # pending, accepted, rejected

      t.timestamps
    end

    add_index :hypothesis_suggestions, [:user_id, :suggested_food_id, :reason_category_id],
              unique: true,
              name: "index_hypothesis_suggestions_unique"
    add_index :hypothesis_suggestions, [:user_id, :status]
  end
end
