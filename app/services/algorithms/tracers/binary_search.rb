module Algorithms
  module Tracers
    class BinarySearch < Base
      def initialize(target: nil)
        @target = target
      end

      def trace(input)
        array = input.sort
        target = @target || array[(array.length * 0.7).floor] || array.last
        emit("Binary search needs sorted input, so the array is sorted first. " \
             "Looking for #{target}.",
             data: array.dup)

        low = 0
        high = array.length - 1

        while low <= high
          mid = (low + high) / 2
          count_comparison!
          emit("Search window #{low}..#{high}. Check the middle, index #{mid} (#{array[mid]}).",
               data: array.dup,
               markers: { window: [ low, high ], current: mid,
                          pointers: { "low" => low, "high" => high } })

          if array[mid] == target
            emit("#{array[mid]} == #{target}. Found it at index #{mid} in " \
                 "#{@comparisons} comparisons.",
                 data: array.dup, markers: { found: mid })
            return
          elsif array[mid] < target
            low = mid + 1
            emit("#{array[mid]} < #{target}, so discard the left half including the middle.",
                 data: array.dup, markers: { window: [ low, high ], discarded_below: low })
          else
            high = mid - 1
            emit("#{array[mid]} > #{target}, so discard the right half including the middle.",
                 data: array.dup, markers: { window: [ low, high ], discarded_above: high })
          end
        end

        emit("The window is empty, so #{target} is not present. " \
             "Each step halved the search space: O(log n).",
             data: array.dup)
      end
    end
  end
end
