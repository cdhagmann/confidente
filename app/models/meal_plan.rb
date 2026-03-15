class MealPlan < ApplicationRecord
  belongs_to :user
  has_many :meal_plan_slots, dependent: :destroy
  has_many :washout_windows, dependent: :destroy

  validates :starts_on, :ends_on, presence: true
  validate :ends_on_after_starts_on

  private

  def ends_on_after_starts_on
    return unless starts_on && ends_on
    errors.add(:ends_on, "must be after start date") if ends_on <= starts_on
  end
end
