class InterviewAnswer < ApplicationRecord
  belongs_to :interview_question

  validates :score, numericality: { in: 0..100 }
  validates :interview_question_id, uniqueness: true

  def matched_keywords
    Array(evaluation["matched"])
  end

  def missed_keywords
    Array(evaluation["missed"])
  end

  def verdict
    evaluation["verdict"].presence || "unscored"
  end
end
