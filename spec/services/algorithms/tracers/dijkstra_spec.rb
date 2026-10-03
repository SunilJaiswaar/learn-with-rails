require "rails_helper"

RSpec.describe Algorithms::Tracers::Dijkstra do
  subject(:tracer) { described_class.new }

  it "computes shortest paths on the default weighted graph" do
    frames = tracer.call

    expect(frames).not_to be_empty
    first_frame = frames.first
    expect(first_frame.aux["label"]).to eq("Priority Queue")

    last_frame = frames.last
    expect(last_frame.narration).to include("Dijkstra complete")
    expect(last_frame.aux["label"]).to eq("Shortest Distances")

    # In default graph: A->B:4, A->C:2, B->C:1, B->D:5, C->D:8, C->E:10, D->E:2, D->F:6, E->F:3
    # Shortest paths from A:
    # A: 0
    # C: 2
    # B: 4 (or 3 via C? B->C is directed, not C->B. A->B is 4)
    # D: A->B(4) + B->D(5) = 9
    # E: A->B->D->E = 11
    # F: A->B->D->E->F = 14
    expect(last_frame.markers[:visited]).to include("A", "C", "B", "D", "E", "F")
  end

  it "tracks priority queue aux items across relaxation steps" do
    frames = tracer.call
    relaxation_frames = frames.select { |f| f.narration.include?("Relax edge") }

    expect(relaxation_frames).not_to be_empty
    expect(relaxation_frames.first.aux["items"]).to be_an(Array)
  end
end
