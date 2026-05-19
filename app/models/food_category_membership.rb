class FoodCategoryMembership < ApplicationRecord
  belongs_to :food
  belongs_to :food_sensitivity_category

  # Migration uses integer: 0=low, 1=medium, 2=high
  enum :severity, { low: 0, medium: 1, high: 2 }

  validates :severity, presence: true
  validates :food_id, uniqueness: { scope: :food_sensitivity_category_id }
end
