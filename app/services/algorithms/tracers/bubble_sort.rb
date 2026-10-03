module Algorithms
  module Tracers
    class BubbleSort < Base
      def trace(input)
        array = input.dup
        emit("Start with the unsorted array.", data: array.dup)
        n = array.length
        sorted_from = n

        (0...n).each do |pass|
          swapped = false

          (0...(n - pass - 1)).each do |i|
            count_comparison!
            emit("Compare #{array[i]} and #{array[i + 1]}.",
                 data: array.dup,
                 markers: { compare: [ i, i + 1 ], sorted: sorted_range(sorted_from, n) })

            next unless array[i] > array[i + 1]

            array[i], array[i + 1] = array[i + 1], array[i]
            count_swap!
            emit("#{array[i + 1]} > #{array[i]}, so swap them.",
                 data: array.dup,
                 markers: { swap: [ i, i + 1 ], sorted: sorted_range(sorted_from, n) })
            swapped = true
          end

          sorted_from = n - pass - 1
          emit("Largest remaining value is now in place at index #{sorted_from}.",
               data: array.dup, markers: { sorted: sorted_range(sorted_from, n) })

          # The early exit is the whole reason bubble sort is O(n) on sorted input.
          if swapped == false
            emit("A full pass made no swaps, so the array is already sorted. Stop early.",
                 data: array.dup, markers: { sorted: (0...n).to_a })
            break
          end
        end

        emit("Sorted.", data: array.dup, markers: { sorted: (0...array.length).to_a })
      end

      private

      def sorted_range(from, n)
        return [] if from >= n

        (from...n).to_a
      end
    end
  end
end
