module Algorithms
  module Tracers
    class MergeSort < Base
      def trace(input)
        array = input.dup
        emit("Merge sort splits the array until each piece has one element.",
             data: array.dup)
        sort(array, 0, array.length - 1, 0)
        emit("Sorted.", data: array.dup, markers: { sorted: (0...array.length).to_a })
      end

      private

      def sort(array, low, high, depth)
        return if low >= high

        mid = (low + high) / 2
        emit("Split indices #{low}..#{high} into #{low}..#{mid} and #{mid + 1}..#{high}.",
             data: array.dup,
             markers: { window: [ low, high ], divider: mid },
             aux: { "label" => "Recursion depth", "items" => [ depth ] })

        sort(array, low, mid, depth + 1)
        sort(array, mid + 1, high, depth + 1)
        merge(array, low, mid, high, depth)
      end

      def merge(array, low, mid, high, depth)
        left = array[low..mid]
        right = array[(mid + 1)..high]
        merged = []

        until left.empty? || right.empty?
          count_comparison!
          merged << (left.first <= right.first ? left.shift : right.shift)
        end
        merged.concat(left).concat(right)

        merged.each_with_index { |value, offset| array[low + offset] = value }
        count_swap!
        emit("Merge the two sorted halves back into #{low}..#{high}.",
             data: array.dup,
             markers: { window: [ low, high ], sorted: (low..high).to_a },
             aux: { "label" => "Merged run", "items" => merged })
      end
    end
  end
end
