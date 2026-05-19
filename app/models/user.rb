class User < ApplicationRecord
  has_many :user_suspect_foods, dependent: :destroy
  has_many :suspect_foods, through: :user_suspect_foods, source: :food
  has_many :meals, dependent: :destroy
  has_many :meal_plans, dependent: :destroy
  has_many :symptom_logs, dependent: :destroy
  has_many :daily_controls, dependent: :destroy
  has_many :hypothesis_suggestions, dependent: :destroy
  has_many :connected_integrations, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
