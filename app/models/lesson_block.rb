# Typed content blocks. Prose is deliberately just one of many kinds so a lesson
# can never degrade into "definition, paragraph, next" (spec 4).
class LessonBlock < ApplicationRecord
  belongs_to :lesson

  BLOCK_TYPES = {
    prose: 0,          # short explanation, never the whole lesson
    visual: 1,         # diagram / animated figure
    interactive: 2,    # the learner manipulates something
    prediction: 3,     # "what happens next?" before revealing
    code_demo: 4,      # runnable annotated snippet
    scenario: 5,       # production situation
    interview: 6,      # how an interviewer asks it
    revision: 7,       # spaced-repetition recall prompt
    pitfall: 8,        # what can go wrong / why not
    comparison: 9      # when to use vs when not to
  }.freeze

  enum :block_type, BLOCK_TYPES, validate: true

  validates :payload, presence: true
  validate :payload_shape

  scope :ordered, -> { order(:position) }

  # Each block type declares the keys its renderer relies on, so bad content
  # fails loudly at authoring time instead of rendering a blank panel.
  REQUIRED_KEYS = {
    "prose" => %w[body],
    "visual" => %w[kind],
    "interactive" => %w[kind],
    "prediction" => %w[question options answer],
    "code_demo" => %w[code],
    "scenario" => %w[situation question],
    "interview" => %w[question],
    "revision" => %w[prompt],
    "pitfall" => %w[body],
    "comparison" => %w[rows]
  }.freeze

  def payload_shape
    required = REQUIRED_KEYS[block_type.to_s]
    return if required.blank?

    missing = required.reject { |key| payload.key?(key) && payload[key].present? }
    return if missing.empty?

    errors.add(:payload, "for a #{block_type} block is missing: #{missing.join(', ')}")
  end

  def renderer_partial
    "lesson_blocks/#{block_type}"
  end

  # Prediction blocks award XP only when the learner commits to an answer first.
  def correct_option?(index)
    prediction? && payload["answer"].to_i == index.to_i
  end
end
