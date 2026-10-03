class InterviewRound < ApplicationRecord
  belongs_to :interview

  has_many :interview_questions, -> { order(:position) }, dependent: :nullify

  validates :name, presence: true
  validates :position, uniqueness: { scope: :interview_id }

  scope :ordered, -> { order(:position) }
end
