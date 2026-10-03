module Algorithms
  module Tracers
    # Dynamic programming: the visualiser shows state, transition and memo
    # filling up, which is the part learners miss (spec 7).
    class FibonacciMemo < Base
      def self.visualizer_kind
        "dp_table"
      end

      def initialize(n: 8)
        @n = n
      end

      def call(input = nil)
        @frames = []
        @comparisons = 0
        @swaps = 0
        @n = input.is_a?(Integer) ? input : @n
        trace(nil)
        frames
      end

      private

      def trace(_input)
        n = @n.clamp(1, 20)
        table = Array.new(n + 1)
        table[0] = 0
        table[1] = 1 if n >= 1

        emit("Base cases are known outright: fib(0)=0 and fib(1)=1.",
             data: table_payload(table),
             markers: { solved: [ 0, 1 ].first(n + 1) })

        (2..n).each do |i|
          count_comparison!
          emit("State fib(#{i}) depends on fib(#{i - 1}) and fib(#{i - 2}).",
               data: table_payload(table),
               markers: { current: i, depends_on: [ i - 1, i - 2 ] })

          table[i] = table[i - 1] + table[i - 2]
          emit("Transition: #{table[i - 1]} + #{table[i - 2]} = #{table[i]}. " \
               "Store it so it is never recomputed.",
               data: table_payload(table),
               markers: { current: i, solved: (0..i).to_a })
        end

        emit("fib(#{n}) = #{table[n]}. Memoisation turns the exponential " \
             "recursion tree into #{n} linear steps.",
             data: table_payload(table),
             markers: { found: n, solved: (0..n).to_a })
      end

      def table_payload(table)
        {
          "cells" => table.each_with_index.map do |value, index|
            { "index" => index, "label" => "fib(#{index})", "value" => value }
          end
        }
      end
    end
  end
end
