module Algorithms
  module Tracers
    class InsertionSort < Base
      def trace(input)
        array = input.dup
        emit("The first element alone is trivially sorted.",
             data: array.dup, markers: { sorted: [ 0 ] })

        (1...array.length).each do |i|
          key = array[i]
          emit("Take #{key} and find where it belongs in the sorted left part.",
               data: array.dup, markers: { current: i, sorted: (0...i).to_a })
          j = i - 1

          while j >= 0
            count_comparison!
            emit("Is #{array[j]} greater than #{key}?",
                 data: array.dup,
                 markers: { compare: [ j, j + 1 ], current: i, sorted: (0...i).to_a })
            break unless array[j] > key

            array[j + 1] = array[j]
            count_swap!
            emit("Yes, shift #{array[j]} one place right.",
                 data: array.dup, markers: { swap: [ j, j + 1 ], sorted: (0...i).to_a })
            j -= 1
          end

          array[j + 1] = key
          emit("Place #{key} at index #{j + 1}.",
               data: array.dup, markers: { current: j + 1, sorted: (0..i).to_a })
        end

        emit("Sorted.", data: array.dup, markers: { sorted: (0...array.length).to_a })
      end
    end
  end
end
