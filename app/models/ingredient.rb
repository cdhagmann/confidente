class Ingredient < ApplicationRecord
  has_many :ingredient_food_mappings, dependent: :destroy
  has_many :foods, through: :ingredient_food_mappings
  has_many :meal_ingredients, dependent: :destroy
  has_many :meals, through: :meal_ingredients

  validates :name, presence: true
  validates :canonical_name, presence: true

  before_validation :set_canonical_name

  private

  def set_canonical_name
    self.canonical_name ||= name&.downcase&.strip
  end
end
