class Achievement < ApplicationRecord
  include Sluggable

  has_many :user_achievements, dependent: :destroy
  has_many :users, through: :user_achievements

  TIERS = { bronze: 0, silver: 1, gold: 2, legendary: 3 }.freeze

  enum :tier, TIERS, suffix: :tier, validate: true

  validates :name, presence: true
  validates :description, presence: true
  validates :rule_key, presence: true, inclusion: { in: -> (_) { Gamification::AchievementRules.keys } }
  validates :threshold, numericality: { greater_than: 0 }

  scope :visible, -> { where(hidden: false) }
  scope :ordered, -> { order(:tier, :threshold) }
end
