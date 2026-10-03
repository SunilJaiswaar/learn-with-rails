module Algorithms
  # Maps an Algorithm record to the tracer that can step through it.
  module Tracer
    REGISTRY = {
      "bubble-sort" => Tracers::BubbleSort,
      "insertion-sort" => Tracers::InsertionSort,
      "merge-sort" => Tracers::MergeSort,
      "quick-sort" => Tracers::QuickSort,
      "linear-search" => Tracers::LinearSearch,
      "binary-search" => Tracers::BinarySearch,
      "two-pointer" => Tracers::TwoPointer,
      "sliding-window" => Tracers::SlidingWindow,
      "breadth-first-search" => Tracers::BreadthFirstSearch,
      "depth-first-search" => Tracers::DepthFirstSearch,
      "fibonacci-memoisation" => Tracers::FibonacciMemo
    }.freeze

    class NullTracer
      def call(_input)
        [ Frame.new(narration: "No step-through trace is available for this algorithm yet.") ]
      end
    end

    def self.for(algorithm)
      klass = REGISTRY[algorithm.slug]
      return NullTracer.new if klass.nil?

      klass.new
    end

    def self.supports?(slug)
      REGISTRY.key?(slug)
    end

    def self.slugs
      REGISTRY.keys
    end
  end
end
