class MealPlanSlot < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :meal, optional: true

  MEAL_TIMES = %w[breakfast lunch dinner].freeze

  validates :scheduled_for, presence: true
  validates :meal_time, presence: true, inclusion: { in: MEAL_TIMES }
  validates :meal_time, uniqueness: { scope: [:meal_plan_id, :scheduled_for] }
end
