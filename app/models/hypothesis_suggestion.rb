class HypothesisSuggestion < ApplicationRecord
  belongs_to :user
  belongs_to :suggested_food, class_name: "Food"
  belongs_to :reason_category, class_name: "FoodSensitivityCategory"

  enum :status, { pending: "pending", accepted: "accepted", rejected: "rejected" }

  validates :status, presence: true
  validates :suggested_food_id, uniqueness: { scope: [:user_id, :reason_category_id] }

  scope :pending_for_user, ->(user) { where(user: user, status: "pending") }
end
