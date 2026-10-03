# Spaced repetition (spec 47). Wrong concepts return on an expanding ladder;
# a lapse drops the learner back down it.
class ReviewSchedule < ApplicationRecord
  belongs_to :user
  belongs_to :reviewable, polymorphic: true
  belongs_to :skill, optional: true

  INTERVALS = [ 0, 1, 3, 7, 14, 30, 60 ].freeze

  validates :due_on, presence: true
  validates :interval_index, numericality: { greater_than_or_equal_to: 0 }
  validates :reviewable_id, uniqueness: { scope: %i[user_id reviewable_type] }

  scope :due, ->(on = Date.current) { where(due_on: ..on) }
  scope :upcoming, -> { where(due_on: Date.current..) }
  scope :soonest, -> { order(:due_on) }

  def interval_days
    INTERVALS[interval_index] || INTERVALS.last
  end

  def promote!(reviewed_at = Time.current)
    next_index = [ interval_index + 1, INTERVALS.length - 1 ].min
    update!(
      interval_index: next_index,
      successes: successes + 1,
      last_reviewed_at: reviewed_at,
      due_on: Date.current + INTERVALS[next_index].days
    )
  end

  # A miss sends the item back two rungs, never below the start.
  def demote!(reviewed_at = Time.current)
    next_index = [ interval_index - 2, 0 ].max
    update!(
      interval_index: next_index,
      lapses: lapses + 1,
      last_reviewed_at: reviewed_at,
      due_on: Date.current + INTERVALS[next_index].days
    )
  end
end
