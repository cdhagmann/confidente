class ConnectedIntegration < ApplicationRecord
  belongs_to :user
  has_many :integration_sync_logs, dependent: :destroy

  PROVIDERS = %w[apple_health google_fit cronometer clue].freeze

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider, uniqueness: { scope: :user_id }
end
