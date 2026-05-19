class IngredientFoodMapping < ApplicationRecord
  belongs_to :ingredient
  belongs_to :food

  validates :ingredient_id, uniqueness: { scope: :food_id }
end
