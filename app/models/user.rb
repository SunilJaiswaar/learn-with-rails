class User < ApplicationRecord
  include ExperienceBanded

  has_secure_password

  MAX_FAILED_LOGINS = 10
  LOCKOUT_PERIOD = 15.minutes

  enum :role, { learner: 0, author: 1, admin: 2 }, validate: true
  enum :theme, { dark: "dark", light: "light", system: "system" }, validate: true

  has_many :sessions, dependent: :delete_all
  has_many :xp_transactions, dependent: :delete_all
  has_many :skill_progresses, dependent: :delete_all
  has_many :skills, through: :skill_progresses
  has_many :challenge_attempts, dependent: :delete_all
  has_many :question_attempts, dependent: :delete_all
  has_many :hint_reveals, dependent: :delete_all
  has_many :topic_completions, dependent: :delete_all
  has_many :completed_topics, through: :topic_completions, source: :topic
  has_many :user_achievements, dependent: :delete_all
  has_many :achievements, through: :user_achievements
  has_many :review_schedules, dependent: :delete_all
  has_many :quests, dependent: :delete_all
  has_many :boss_attempts, dependent: :delete_all
  has_many :interviews, dependent: :delete_all
  has_one  :streak, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 80 }
  validates :password, length: { minimum: 10 }, allow_nil: true
  validates :timezone, presence: true
  validates :xp_total, numericality: { greater_than_or_equal_to: 0 }
  validates :level, numericality: { greater_than_or_equal_to: 1 }

  normalizes :email, with: ->(value) { value.to_s.strip.downcase }
  normalizes :name, with: ->(value) { value.to_s.strip }

  scope :staff, -> { where(role: %i[author admin]) }

  def staff?
    author? || admin?
  end

  def locked?
    locked_until.present? && locked_until.future?
  end

  def display_streak
    streak&.current_length.to_i
  end

  # Level curve: each level costs progressively more XP, so early progress feels
  # quick and later levels stay meaningful (spec 49).
  def xp_for_next_level
    Gamification::LevelCurve.threshold_for(level + 1)
  end

  def xp_into_current_level
    xp_total - Gamification::LevelCurve.threshold_for(level)
  end

  def xp_needed_for_current_level
    xp_for_next_level - Gamification::LevelCurve.threshold_for(level)
  end

  def level_progress_percent
    needed = xp_needed_for_current_level
    return 100 if needed <= 0

    ((xp_into_current_level.to_f / needed) * 100).clamp(0, 100).round
  end

  def rank_title
    Gamification::LevelCurve.title_for(level)
  end

  def prefers_reduced_motion?
    reduced_motion
  end
end
