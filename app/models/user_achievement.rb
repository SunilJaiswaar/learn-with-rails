class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement

  validates :achievement_id, uniqueness: { scope: :user_id }
  validates :awarded_at, presence: true

  scope :recent, -> { order(awarded_at: :desc) }
end
