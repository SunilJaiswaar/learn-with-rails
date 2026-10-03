class InterviewQuestion < ApplicationRecord
  belongs_to :interview
  belongs_to :interview_round, optional: true
  belongs_to :question
  # Set when this slot is a probe generated from a previous answer (spec 43).
  belongs_to :question_follow_up, optional: true

  has_one :interview_answer, dependent: :destroy

  validates :position, uniqueness: { scope: :interview_id }

  scope :ordered, -> { order(:position) }
  scope :unanswered, -> { left_joins(:interview_answer).where(interview_answers: { id: nil }) }

  def follow_up?
    question_follow_up_id.present?
  end

  def prompt
    follow_up? ? question_follow_up.body : question.body
  end

  def answered?
    interview_answer.present?
  end
end
