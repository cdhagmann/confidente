class IntegrationSyncLog < ApplicationRecord
  belongs_to :connected_integration

  STATUSES = %w[success partial failed].freeze

  validates :synced_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :records_imported, numericality: { greater_than_or_equal_to: 0 }
end
