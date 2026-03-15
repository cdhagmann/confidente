class DailyControl < ApplicationRecord
  belongs_to :user
  has_many :daily_control_flags, dependent: :destroy

  enum :exercise_intensity, { none: "none", light: "light", moderate: "moderate", intense: "intense" }, prefix: true

  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :sleep_quality, inclusion: { in: 1..5 }, allow_nil: true
  validates :stress_level, inclusion: { in: 1..5 }, allow_nil: true
  validates :sleep_hours, numericality: { greater_than: 0, less_than_or_equal_to: 24 }, allow_nil: true
end
