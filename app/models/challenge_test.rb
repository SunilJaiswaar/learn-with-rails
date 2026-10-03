# A single assertion run inside the sandbox. `call_expression` is evaluated
# against the learner's submitted code; `expected` is compared by inspect-string
# so that any Ruby value can be asserted without eval-ing authored data.
class ChallengeTest < ApplicationRecord
  belongs_to :challenge

  validates :name, presence: true
  validates :weight, numericality: { greater_than: 0 }
  validate :has_an_assertion

  scope :ordered, -> { order(:position) }
  scope :visible, -> { where(hidden: false) }

  private

  def has_an_assertion
    return if call_expression.present? || setup_sql.present?

    errors.add(:call_expression, "is required unless the test provides setup SQL")
  end
end
