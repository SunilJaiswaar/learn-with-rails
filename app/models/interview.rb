class Interview < ApplicationRecord
  include ExperienceBanded

  belongs_to :user
  belongs_to :interview_template, optional: true

  enum :status, { in_progress: 0, completed: 1, abandoned: 2 },
       suffix: :interview, validate: true

  # Spec 44.
  PRESSURE_MODES = {
    normal: 0,
    timed: 1,
    rapid_fire: 2,
    no_hint: 3,
    senior: 4,
    expert: 5,
    production_incident: 6
  }.freeze

  # Per-mode seconds allowed per question; nil means untimed.
  PRESSURE_TIME_LIMITS = {
    "normal" => nil,
    "timed" => 120,
    "rapid_fire" => 45,
    "no_hint" => nil,
    "senior" => 180,
    "expert" => 150,
    "production_incident" => 240
  }.freeze

  enum :pressure_mode, PRESSURE_MODES, suffix: :mode, validate: true

  has_many :interview_rounds, -> { order(:position) }, dependent: :destroy
  has_many :interview_questions, -> { order(:position) }, dependent: :destroy
  has_many :questions, through: :interview_questions
  has_many :interview_answers, through: :interview_questions

  scope :recent, -> { order(created_at: :desc) }

  # Competencies are scored separately (spec 45) so feedback is specific.
  COMPETENCIES = %w[
    technical_accuracy problem_solving depth communication
    tradeoffs performance_awareness security_awareness architecture debugging
  ].freeze

  def seconds_per_question
    PRESSURE_TIME_LIMITS[pressure_mode]
  end

  def hints_allowed?
    !no_hint_mode? && !expert_mode?
  end

  def answered_count
    interview_answers.count
  end

  def total_count
    interview_questions.count
  end

  def progress_percent
    return 0 if total_count.zero?

    ((answered_count.to_f / total_count) * 100).round
  end

  def current_question
    interview_questions.includes(:question, :question_follow_up)
                       .left_joins(:interview_answer)
                       .where(interview_answers: { id: nil })
                       .order(:position)
                       .first
  end

  def competency_score(name)
    competency_scores[name.to_s]
  end

  def overall_score
    scores = competency_scores.values.compact
    return 0 if scores.empty?

    (scores.sum / scores.size.to_f).round
  end
end
