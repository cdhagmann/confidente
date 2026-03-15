class SymptomLog < ApplicationRecord
  belongs_to :user
  belongs_to :symptom_type

  validates :logged_at, presence: true
  validates :score, presence: true, inclusion: { in: 1..5 }

  scope :in_range, ->(start_date, end_date) {
    where(logged_at: start_date.beginning_of_day..end_date.end_of_day)
  }
end
