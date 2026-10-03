# The Big-O visualiser (spec 9). Growth is computed, not illustrated, so the
# numbers the learner sees are real.
class ComplexityController < ApplicationController
  INPUT_SIZES = [ 10, 100, 1_000, 10_000, 100_000, 1_000_000 ].freeze

  CURVES = {
    "O(1)" => ->(_n) { 1 },
    "O(log n)" => ->(n) { Math.log2(n).ceil },
    "O(n)" => ->(n) { n },
    "O(n log n)" => ->(n) { (n * Math.log2(n)).round },
    "O(n^2)" => ->(n) { n**2 },
    "O(2^n)" => ->(n) { n <= 40 ? 2**n : Float::INFINITY }
  }.freeze

  # A rough modern figure, used only to turn operation counts into intuition.
  OPS_PER_SECOND = 100_000_000

  def show
    @sizes = INPUT_SIZES
    @rows = CURVES.map do |label, curve|
      {
        label: label,
        points: INPUT_SIZES.map { |n| { n: n, operations: curve.call(n) } }
      }
    end
    @ops_per_second = OPS_PER_SECOND
  end
end
