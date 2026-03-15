class WashoutWindow < ApplicationRecord
  belongs_to :meal_plan
  belongs_to :food_sensitivity_category

  validates :start_date, :end_date, presence: true

  scope :active_on, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }
  scope :active_for_category, ->(category_id, date) {
    where(food_sensitivity_category_id: category_id)
      .active_on(date)
  }
end
