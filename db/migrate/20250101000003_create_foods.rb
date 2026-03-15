class CreateFoods < ActiveRecord::Migration[8.1]
  def change
    create_table :foods do |t|
      t.string :name, null: false
      t.string :open_food_facts_id
      t.string :barcode

      t.timestamps
    end

    add_index :foods, :barcode
    add_index :foods, :open_food_facts_id
  end
end
