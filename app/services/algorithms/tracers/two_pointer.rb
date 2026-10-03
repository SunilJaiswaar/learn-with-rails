module Algorithms
  module Tracers
    # Classic two-pointer pair-sum on a sorted array.
    class TwoPointer < Base
      def initialize(target: nil)
        @target = target
      end

      def trace(input)
        array = input.sort
        target = @target || (array.first.to_i + array.last.to_i)
        emit("Sorted input, one pointer at each end. Target sum is #{target}.",
             data: array.dup, markers: { pointers: { "left" => 0, "right" => array.length - 1 } })

        left = 0
        right = array.length - 1

        while left < right
          sum = array[left] + array[right]
          count_comparison!
          emit("#{array[left]} + #{array[right]} = #{sum}.",
               data: array.dup,
               markers: { compare: [ left, right ], window: [ left, right ],
                          pointers: { "left" => left, "right" => right } })

          if sum == target
            emit("That matches the target. Found the pair in one pass: O(n).",
                 data: array.dup, markers: { found: left, also_found: right })
            return
          elsif sum < target
            left += 1
            emit("#{sum} < #{target}, so move the left pointer right to increase the sum.",
                 data: array.dup,
                 markers: { pointers: { "left" => left, "right" => right } })
          else
            right -= 1
            emit("#{sum} > #{target}, so move the right pointer left to decrease the sum.",
                 data: array.dup,
                 markers: { pointers: { "left" => left, "right" => right } })
          end
        end

        emit("The pointers met without finding the target.", data: array.dup)
      end
    end
  end
end
