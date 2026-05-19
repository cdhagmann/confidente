class FoodSensitivityCategory < ApplicationRecord
  has_many :food_category_memberships, dependent: :destroy
  has_many :foods, through: :food_category_memberships
  has_many :washout_windows
  has_many :hypothesis_suggestions, foreign_key: :reason_category_id, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
end
