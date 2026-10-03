require "rails_helper"

# The visualiser must show the real algorithm, so the traces are asserted
# against known-correct output (spec 7).
RSpec.describe Algorithms::Tracer do
  let(:input) { [ 8, 3, 7, 4, 2 ] }

  it "has a tracer for every algorithm in the catalogue" do
    described_class::REGISTRY.each_key do |slug|
      expect(described_class.supports?(slug)).to be(true)
    end
  end

  describe "sorting tracers" do
    %w[bubble-sort insertion-sort merge-sort quick-sort].each do |slug|
      it "#{slug} ends with a correctly sorted array" do
        frames = described_class::REGISTRY.fetch(slug).new.call(input)

        expect(frames.last.data).to eq(input.sort)
      end

      it "#{slug} produces a narration for every frame" do
        frames = described_class::REGISTRY.fetch(slug).new.call(input)

        expect(frames).to be_present
        expect(frames.map(&:narration)).to all(be_present)
      end
    end

    it "exits bubble sort early on already-sorted input" do
      frames = Algorithms::Tracers::BubbleSort.new.call([ 1, 2, 3, 4, 5 ])

      expect(frames.map(&:narration).join).to include("already sorted")
    end
  end

  describe "binary search" do
    it "finds a value present in the array" do
      frames = Algorithms::Tracers::BinarySearch.new(target: 7).call(input)

      expect(frames.last.narration).to include("Found it")
    end

    it "halves the window rather than scanning" do
      frames = Algorithms::Tracers::BinarySearch.new(target: 7).call((1..64).to_a)

      # log2(64) is 6, so a correct trace cannot need dozens of comparisons.
      expect(frames.last.metrics[:comparisons]).to be <= 7
    end

    it "reports a value that is absent" do
      frames = Algorithms::Tracers::BinarySearch.new(target: 999).call(input)

      expect(frames.last.narration).to include("not present")
    end
  end

  describe "graph traversal" do
    it "visits breadth-first, level by level" do
      frames = Algorithms::Tracers::BreadthFirstSearch.new.call

      expect(frames.last.narration).to include("A -> B -> C -> D -> E -> F")
    end

    it "visits depth-first, diving before backtracking" do
      frames = Algorithms::Tracers::DepthFirstSearch.new.call

      expect(frames.last.narration).to include("A -> B -> D -> E -> F -> C")
    end

    it "shows the queue contents as BFS runs" do
      frames = Algorithms::Tracers::BreadthFirstSearch.new.call
      labels = frames.filter_map { |frame| frame.aux&.dig("label") }

      expect(labels).to include("Queue")
    end

    it "shows the stack contents as DFS runs" do
      frames = Algorithms::Tracers::DepthFirstSearch.new.call
      labels = frames.filter_map { |frame| frame.aux&.dig("label") }

      expect(labels).to include("Stack")
    end
  end

  describe "dynamic programming" do
    it "fills the memo table with the Fibonacci sequence" do
      frames = Algorithms::Tracers::FibonacciMemo.new(n: 7).call
      values = frames.last.data["cells"].map { |cell| cell["value"] }

      expect(values).to eq([ 0, 1, 1, 2, 3, 5, 8, 13 ])
    end
  end

  describe "two pointers and sliding window" do
    it "finds a pair summing to the target" do
      frames = Algorithms::Tracers::TwoPointer.new(target: 10).call(input)

      expect(frames.last.narration).to include("matches the target")
    end

    it "reports the best window sum" do
      frames = Algorithms::Tracers::SlidingWindow.new(window_size: 3).call(input)

      expect(frames.last.narration).to include("Best window")
    end
  end

  it "caps the number of frames so a large input cannot exhaust memory" do
    frames = Algorithms::Tracers::BubbleSort.new.call((1..40).to_a.reverse)

    expect(frames.size).to be <= Algorithms::Tracers::Base::MAX_FRAMES
  end

  it "returns a placeholder frame for an algorithm with no tracer" do
    algorithm = create(:algorithm, slug: "not-implemented-yet")

    frames = described_class.for(algorithm).call([ 1, 2 ])

    expect(frames.first.narration).to include("No step-through trace")
  end

  it "serialises a frame into the shape the front-end expects" do
    frame = Algorithms::Tracers::BubbleSort.new.call([ 2, 1 ]).first.as_json

    expect(frame).to include("narration", "data", "markers", "metrics")
  end
end
