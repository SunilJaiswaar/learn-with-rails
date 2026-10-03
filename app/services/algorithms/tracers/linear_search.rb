module Algorithms
  module Tracers
    class LinearSearch < Base
      def initialize(target: nil)
        @target = target
      end

      def trace(input)
        array = input.dup
        target = @target || array[(array.length * 0.7).floor] || array.last
        emit("Looking for #{target} by checking every element in order.",
             data: array.dup)

        array.each_with_index do |value, index|
          count_comparison!
          emit("Index #{index}: is #{value} == #{target}?",
               data: array.dup, markers: { current: index, checked: (0...index).to_a })

          next unless value == target

          emit("Found #{target} at index #{index} after #{@comparisons} comparisons.",
               data: array.dup, markers: { found: index })
          return
        end

        emit("Reached the end without finding #{target}. " \
             "Linear search always costs O(n) in the worst case.",
             data: array.dup, markers: { checked: (0...array.length).to_a })
      end
    end
  end
end
