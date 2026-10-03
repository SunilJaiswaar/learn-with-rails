# Mastery is evidence across six dimensions, never reading alone (spec 48, 65).
class SkillProgress < ApplicationRecord
  belongs_to :user
  belongs_to :skill

  DIMENSIONS = %i[
    understanding prediction implementation debugging explanation application
  ].freeze

  # Dimensions are weighted: being able to build and debug counts for more than
  # having read the lesson.
  DIMENSION_WEIGHTS = {
    understanding: 1.0,
    prediction: 1.25,
    implementation: 1.75,
    debugging: 1.75,
    explanation: 1.25,
    application: 1.5
  }.freeze

  MASTERY_LEVELS = {
    untested: 0,
    weak: 1,
    developing: 2,
    strong: 3,
    mastered: 4
  }.freeze

  enum :mastery_level, MASTERY_LEVELS, suffix: :mastery, validate: true

  validates :skill_id, uniqueness: { scope: :user_id }
  DIMENSIONS.each do |dim|
    validates :"#{dim}_score", numericality: { in: 0..100 }
  end

  scope :weak_first, -> { order(:mastery_level, updated_at: :desc) }

  def dimension_scores
    DIMENSIONS.index_with { |dim| public_send("#{dim}_score") }
  end

  # Weighted composite used for the dashboard bars and the adaptive engine.
  def composite_score
    total_weight = DIMENSION_WEIGHTS.values.sum
    weighted = DIMENSION_WEIGHTS.sum { |dim, w| public_send("#{dim}_score") * w }
    (weighted / total_weight).round
  end

  def accuracy_percent
    return 0 if attempts_count.zero?

    ((correct_count.to_f / attempts_count) * 100).round
  end

  # The weakest dimension is what the next recommendation should target.
  def weakest_dimension
    dimension_scores.min_by { |_dim, score| score }&.first
  end

  def readiness_label
    case mastery_level
    when "mastered", "strong" then "Strong"
    when "developing" then "Developing"
    when "weak" then "Weak"
    else "Not tested"
    end
  end
end
