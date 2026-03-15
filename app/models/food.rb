class Food < ApplicationRecord
  has_many :food_category_memberships, dependent: :destroy
  has_many :sensitivity_categories, through: :food_category_memberships, source: :food_sensitivity_category
  has_many :ingredient_food_mappings, dependent: :destroy
  has_many :ingredients, through: :ingredient_food_mappings
  has_many :user_suspect_foods, dependent: :destroy
  has_many :meal_ingredients, dependent: :nullify
  has_many :hypothesis_suggestions, foreign_key: :suggested_food_id, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
