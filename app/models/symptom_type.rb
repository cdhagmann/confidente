class SymptomType < ApplicationRecord
  has_many :symptom_logs, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: %w[gut systemic] }
end
