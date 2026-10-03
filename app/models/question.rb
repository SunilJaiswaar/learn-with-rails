class Question < ApplicationRecord
  include DifficultyScale
  include ExperienceBanded

  belongs_to :topic, optional: true
  belongs_to :skill, optional: true

  QUESTION_TYPES = %w[
    mcq coding sql debugging output_prediction
    architecture system_design security scenario optimization
  ].freeze

  COMPANY_TYPES = %w[
    product mnc fintech startup saas service_based
    enterprise consulting backend_heavy frontend_heavy full_stack
  ].freeze

  has_many :question_follow_ups, -> { order(:position) }, dependent: :destroy
  has_many :question_attempts, dependent: :delete_all
  has_many :interview_questions, dependent: :destroy

  validates :body, presence: true
  validates :question_type, presence: true, inclusion: { in: QUESTION_TYPES }
  validates :company_type, inclusion: { in: COMPANY_TYPES }, allow_blank: true
  validate :mcq_requires_options

  scope :published, -> { where(published: true) }
  scope :of_type, ->(kind) { where(question_type: kind) }
  scope :for_band, ->(band) { where(experience_band: band) }
  # Interviews should not drill a senior candidate on syntax (spec 41).
  scope :up_to_band, ->(band) { where(experience_band: ..BANDS.fetch(band.to_sym)) }
  scope :for_company_type, ->(type) { type.present? ? where(company_type: [ type, nil ]) : all }

  def mcq?
    question_type == "mcq"
  end

  def open_ended?
    !mcq?
  end

  def choices
    Array(options)
  end

  def correct_index
    answer_key["correct_index"]
  end

  # Open-ended answers are graded on the concepts they contain.
  def expected_keywords
    Array(answer_key["keywords"])
  end

  def required_keywords
    Array(answer_key["required"])
  end

  private

  def mcq_requires_options
    return unless mcq?

    errors.add(:options, "must list at least two choices") if choices.size < 2
    return if correct_index.is_a?(Integer) && choices[correct_index].present?

    errors.add(:answer_key, "must contain a valid correct_index")
  end
end
