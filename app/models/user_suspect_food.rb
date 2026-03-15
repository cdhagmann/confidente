class UserSuspectFood < ApplicationRecord
  belongs_to :user
  belongs_to :food

  validates :user_id, uniqueness: { scope: :food_id }
  validates :added_at, presence: true

  before_validation :set_added_at

  private

  def set_added_at
    self.added_at ||= Time.current
  end
end
