class DailyControlFlag < ApplicationRecord
  belongs_to :daily_control

  validates :flag_type, presence: true
  validates :value, presence: true
end
