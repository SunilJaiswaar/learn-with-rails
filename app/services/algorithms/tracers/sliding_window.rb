module Algorithms
  module Tracers
    # Maximum sum of any contiguous window of size k.
    class SlidingWindow < Base
      def initialize(window_size: 3)
        @window_size = window_size
      end

      def trace(input)
        array = input.dup
        k = [ [ @window_size, 1 ].max, array.length ].min
        return emit("Need at least one element.", data: array) if array.empty?

        window_sum = array.first(k).sum
        best = window_sum
        best_start = 0
        emit("Sum the first window of #{k} elements: #{window_sum}.",
             data: array.dup, markers: { window: [ 0, k - 1 ] },
             aux: { "label" => "Window sum", "items" => [ window_sum ] })

        (k...array.length).each do |i|
          leaving = array[i - k]
          entering = array[i]
          window_sum += entering - leaving
          count_comparison!

          emit("Slide: drop #{leaving}, add #{entering}. New sum #{window_sum}.",
               data: array.dup,
               markers: { window: [ i - k + 1, i ], leaving: i - k, entering: i },
               aux: { "label" => "Window sum", "items" => [ window_sum ] })

          next unless window_sum > best

          best = window_sum
          best_start = i - k + 1
          emit("That is the best window so far (#{best}).",
               data: array.dup, markers: { window: [ best_start, best_start + k - 1 ] },
               aux: { "label" => "Best sum", "items" => [ best ] })
        end

        emit("Best window is #{best_start}..#{best_start + k - 1} with sum #{best}. " \
             "Recomputing each window would be O(n*k); sliding makes it O(n).",
             data: array.dup,
             markers: { window: [ best_start, best_start + k - 1 ],
                        sorted: (best_start..(best_start + k - 1)).to_a })
      end
    end
  end
end
