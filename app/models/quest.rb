class Quest < ApplicationRecord
  belongs_to :user
  belongs_to :quest_template

  enum :status, { open: 0, completed: 1, expired: 2 }, suffix: :quest, validate: true

  has_many :quest_steps, -> { order(:position) }, dependent: :destroy

  validates :scheduled_on, presence: true,
                           uniqueness: { scope: :user_id,
                                         message: "already has a quest for this day" }

  scope :for_day, ->(day) { where(scheduled_on: day) }
  scope :today, -> { for_day(Date.current) }

  def completed_steps_count
    quest_steps.count(&:completed)
  end

  def total_steps_count
    quest_steps.size
  end

  def progress_percent
    return 0 if total_steps_count.zero?

    ((completed_steps_count.to_f / total_steps_count) * 100).round
  end

  def all_steps_complete?
    total_steps_count.positive? && completed_steps_count == total_steps_count
  end
end
