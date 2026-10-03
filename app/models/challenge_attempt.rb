class ChallengeAttempt < ApplicationRecord
  belongs_to :user
  belongs_to :challenge

  STATUSES = {
    pending: 0,
    passed: 1,
    failed: 2,
    error: 3,
    timed_out: 4,
    rejected: 5    # refused before execution (e.g. static safety check)
  }.freeze

  enum :status, STATUSES, validate: true

  validates :submitted_code, presence: true, length: { maximum: 20_000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: :passed) }

  def score_percent
    return 0 if tests_total.to_i.zero?

    ((tests_passed.to_f / tests_total) * 100).round
  end

  def test_results
    Array(results["tests"])
  end

  def review_findings
    Array(review["findings"])
  end
end
