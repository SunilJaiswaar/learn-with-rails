# One micro-learning mission (spec 5). A topic is only "done" when it carries
# the full learning loop, which `definition_of_done` reports on (spec 80).
class Topic < ApplicationRecord
  include Sluggable
  include DifficultyScale

  belongs_to :curriculum_module
  belongs_to :skill, optional: true
  belongs_to :technology_version, optional: true

  has_one :world, through: :curriculum_module

  has_many :lessons, -> { order(:position) }, dependent: :destroy
  has_many :lesson_blocks, through: :lessons
  has_many :challenges, dependent: :nullify
  has_many :questions, dependent: :nullify
  has_many :algorithms, dependent: :nullify
  has_many :topic_completions, dependent: :delete_all

  validates :name, presence: true
  validates :hook, presence: true
  validates :estimated_minutes, numericality: { in: 1..180 }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }

  def completion_for(user)
    return nil unless user

    topic_completions.find_by(user_id: user.id)
  end

  def completed_by?(user)
    completion_for(user)&.completed_at.present?
  end

  # Spec 80: a topic is not complete until every element of the loop exists.
  def definition_of_done
    # `pluck` already casts an enum column to its string name.
    block_types = lesson_blocks.pluck(:block_type).to_set
    challenge_types = challenges.pluck(:challenge_type).to_set

    {
      "Explanation" => block_types.include?("prose"),
      "Visual" => block_types.include?("visual"),
      "Interactive example" => block_types.include?("interactive"),
      "Prediction" => block_types.include?("prediction"),
      "Coding challenge" => challenge_types.include?("implement"),
      "Debugging challenge" => challenge_types.include?("debug"),
      "Real-world scenario" => block_types.include?("scenario"),
      "Interview question" => questions.exists?,
      "Follow-up question" => QuestionFollowUp.where(question_id: questions.select(:id)).exists?,
      "Revision challenge" => block_types.include?("revision"),
      "Mastery measurement" => skill_id.present?
    }
  end

  def complete_content?
    definition_of_done.values.all?
  end
end
