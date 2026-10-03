class Challenge < ApplicationRecord
  include Sluggable
  include DifficultyScale

  slug_from :title

  belongs_to :topic, optional: true
  belongs_to :skill, optional: true

  # Challenge shapes from spec 8.
  CHALLENGE_TYPES = {
    implement: 0,
    debug: 1,
    optimize: 2,
    predict: 3,
    trace: 4,
    explain: 5,
    compare: 6,
    production: 7
  }.freeze

  # Suffixed because an unsuffixed `explain` value would generate a
  # Challenge.explain scope and shadow ActiveRecord::Relation#explain.
  enum :challenge_type, CHALLENGE_TYPES, suffix: :challenge, validate: true
  enum :language, { ruby: 0, sql: 1 }, suffix: :language, validate: true

  has_many :challenge_tests, -> { order(:position) }, dependent: :destroy
  has_many :hints, -> { order(:position) }, dependent: :destroy
  has_many :challenge_attempts, dependent: :delete_all

  validates :title, presence: true
  validates :prompt, presence: true
  validates :time_limit_ms, numericality: { in: 100..30_000 }
  validates :memory_limit_mb, numericality: { in: 64..2048 }
  validates :xp_award, numericality: { greater_than_or_equal_to: 0 }

  scope :published, -> { where(published: true) }
  scope :of_type, ->(kind) { where(challenge_type: kind) }

  # Which mastery dimension passing this challenge proves (spec 48).
  def mastery_dimension
    case challenge_type
    when "debug" then :debugging
    when "predict", "trace" then :prediction
    when "explain", "compare" then :explanation
    when "optimize", "production" then :application
    else :implementation
    end
  end

  def visible_tests
    challenge_tests.where(hidden: false)
  end

  def best_attempt_for(user)
    return nil unless user

    challenge_attempts.where(user_id: user.id).order(tests_passed: :desc, created_at: :desc).first
  end

  def solved_by?(user)
    return false unless user

    challenge_attempts.where(user_id: user.id, status: :passed).exists?
  end
end
