module Algorithms
  module Tracers
    class QuickSort < Base
      def trace(input)
        array = input.dup
        emit("Quick sort partitions around a pivot, then recurses on each side.",
             data: array.dup)
        sort(array, 0, array.length - 1)
        emit("Sorted.", data: array.dup, markers: { sorted: (0...array.length).to_a })
      end

      private

      def sort(array, low, high)
        return if low >= high

        pivot_index = partition(array, low, high)
        emit("Pivot #{array[pivot_index]} is now in its final position.",
             data: array.dup, markers: { pivot: pivot_index, sorted: [ pivot_index ] })
        sort(array, low, pivot_index - 1)
        sort(array, pivot_index + 1, high)
      end

      # Lomuto partition scheme, using the last element as the pivot.
      def partition(array, low, high)
        pivot = array[high]
        emit("Partition #{low}..#{high} around pivot #{pivot}.",
             data: array.dup, markers: { pivot: high, window: [ low, high ] })
        boundary = low - 1

        (low...high).each do |i|
          count_comparison!
          emit("Is #{array[i]} <= pivot #{pivot}?",
               data: array.dup,
               markers: { compare: [ i, high ], pivot: high, window: [ low, high ] })
          next unless array[i] <= pivot

          boundary += 1
          if boundary != i
            array[boundary], array[i] = array[i], array[boundary]
            count_swap!
            emit("Yes, move it into the left group.",
                 data: array.dup,
                 markers: { swap: [ boundary, i ], pivot: high, window: [ low, high ] })
          end
        end

        array[boundary + 1], array[high] = array[high], array[boundary + 1]
        count_swap!
        [ boundary + 1 ].first
      end
    end
  end
end
