# The follow-up engine (spec 43). A follow-up either always fires, fires when
# the learner used a keyword, or fires when they *failed* to mention one.
class QuestionFollowUp < ApplicationRecord
  belongs_to :question
  belongs_to :parent, class_name: "QuestionFollowUp", optional: true

  has_many :children, class_name: "QuestionFollowUp", foreign_key: :parent_id,
                      dependent: :destroy
  has_many :question_attempts, dependent: :nullify

  TRIGGER_KINDS = %w[always keyword missing_keyword].freeze

  validates :body, presence: true
  validates :trigger_kind, inclusion: { in: TRIGGER_KINDS }
  validates :depth, numericality: { in: 1..6 }

  scope :ordered, -> { order(:position) }
  scope :roots, -> { where(parent_id: nil) }

  def keywords
    Array(trigger_keywords).map { |k| k.to_s.downcase }
  end

  def expected_keywords
    Array(answer_key["keywords"])
  end

  # Decides whether this probe is warranted given what the learner just said.
  def triggered_by?(answer_text)
    text = answer_text.to_s.downcase
    case trigger_kind
    when "always" then true
    when "keyword" then keywords.any? { |k| text.include?(k) }
    when "missing_keyword" then keywords.none? { |k| text.include?(k) }
    else false
    end
  end
end
