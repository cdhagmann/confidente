class CreateUserSuspectFoods < ActiveRecord::Migration[8.1]
  def change
    create_table :user_suspect_foods do |t|
      t.references :user, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true
      t.timestamp :added_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :user_suspect_foods, [:user_id, :food_id], unique: true
  end
end
