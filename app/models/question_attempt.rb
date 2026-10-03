class QuestionAttempt < ApplicationRecord
  belongs_to :user
  belongs_to :question
  belongs_to :question_follow_up, optional: true

  validates :score, numericality: { in: 0..100 }

  scope :recent, -> { order(created_at: :desc) }
  scope :correct_only, -> { where(correct: true) }

  def matched_keywords
    Array(evaluation["matched"])
  end

  def missed_keywords
    Array(evaluation["missed"])
  end
end
