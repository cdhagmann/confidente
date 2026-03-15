class CreateMeals < ActiveRecord::Migration[8.1]
  def change
    create_table :meals do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamp :eaten_at, null: false
      t.boolean :planned, null: false, default: false
      t.text :notes

      t.timestamps
    end

    add_index :meals, [:user_id, :eaten_at]
  end
end
