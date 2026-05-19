class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.string :name, null: false
      t.string :canonical_name, null: false

      t.timestamps
    end

    add_index :ingredients, :canonical_name
    add_index :ingredients, :name
  end
end
