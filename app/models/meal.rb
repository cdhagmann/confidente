class Meal < ApplicationRecord
  belongs_to :user
  has_many :meal_ingredients, dependent: :destroy
  has_many :ingredients, through: :meal_ingredients
  has_one :meal_plan_slot, dependent: :nullify

  validates :eaten_at, presence: true
  validates :planned, inclusion: { in: [true, false] }
end
