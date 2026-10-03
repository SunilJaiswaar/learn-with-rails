# Interview tracks by experience band and company *pattern* category.
# These are interview-pattern categories, never claimed to be any company's
# real proprietary questions (spec 42).
class InterviewTemplate < ApplicationRecord
  include Sluggable
  include ExperienceBanded

  has_many :interviews, dependent: :nullify

  validates :name, presence: true
  validates :question_count, numericality: { in: 1..40 }
  validate :round_specs_present

  scope :active, -> { where(active: true) }

  def rounds
    Array(round_specs)
  end

  private

  def round_specs_present
    errors.add(:round_specs, "must define at least one round") if rounds.empty?
  end
end
