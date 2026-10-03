module Algorithms
  module Tracers
    class Base
      # Guard against a learner pasting a huge input into the visualiser.
      MAX_INPUT_SIZE = 32
      MAX_FRAMES = 400

      def self.visualizer_kind
        "array"
      end

      def call(input)
        @frames = []
        @comparisons = 0
        @swaps = 0
        trace(normalise(input))
        frames
      end

      private

      attr_reader :frames

      def normalise(input)
        Array(input).first(MAX_INPUT_SIZE)
      end

      def emit(narration, data: nil, markers: {}, aux: nil)
        return if frames.size >= MAX_FRAMES

        @frames << Frame.new(
          narration: narration,
          data: data,
          markers: markers,
          aux: aux,
          metrics: { comparisons: @comparisons, swaps: @swaps }
        )
      end

      def count_comparison!
        @comparisons += 1
      end

      def count_swap!
        @swaps += 1
      end

      def trace(_input)
        raise NotImplementedError
      end
    end
  end
end
