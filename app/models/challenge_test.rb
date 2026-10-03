# A single assertion against a learner's submission.
#
# For a Ruby challenge, `call_expression` is evaluated inside the sandbox
# against the submitted code and the result is compared to `expected` by
# inspect-string, so any Ruby value can be asserted without eval-ing authored
# data.
#
# For a SQL challenge the learner's whole query *is* the answer, so there is no
# call expression: `expected` holds the expected result set as JSON rows.
class ChallengeTest < ApplicationRecord
  belongs_to :challenge

  validates :name, presence: true
  validates :weight, numericality: { greater_than: 0 }
  validate :has_an_assertion
  validate :expected_rows_parse, if: :sql?

  scope :ordered, -> { order(:position) }
  scope :visible, -> { where(hidden: false) }

  def sql?
    challenge&.sql_language?
  end

  # The expected result set for a SQL challenge, as an array of row arrays.
  def expected_rows
    return [] if expected.blank?

    parsed = JSON.parse(expected)
    Array(parsed).map { |row| Array(row).map { |value| value.nil? ? nil : value.to_s } }
  rescue JSON::ParserError
    []
  end

  private

  def has_an_assertion
    return if sql?
    return if call_expression.present? || setup_sql.present?

    errors.add(:call_expression, "is required unless the test provides setup SQL")
  end

  def expected_rows_parse
    return if expected.blank?

    JSON.parse(expected)
  rescue JSON::ParserError
    errors.add(:expected, "must be valid JSON: an array of row arrays")
  end
end
