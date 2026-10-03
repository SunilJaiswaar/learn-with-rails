require "rails_helper"

RSpec.describe Skills::Rollup do
  Node = Skills::TreeBuilder::Node

  def node(state, composite: 0, topics: [])
    skill = instance_double(Skill, topics: topics)
    Node.new(skill: skill, progress: nil, state: state, prerequisite_names: [])
  end

  describe "counts" do
    subject(:rollup) do
      described_class.new([
        node(:complete), node(:complete),
        node(:in_progress),
        node(:available),
        node(:locked), node(:locked), node(:locked)
      ])
    end

    it "totals the nodes" do
      expect(rollup.total).to eq(7)
    end

    it "counts each state" do
      expect(rollup.counts).to eq(complete: 2, in_progress: 1, available: 1, locked: 3)
    end

    it "treats only complete as progress, never a visit" do
      expect(rollup.percent_complete).to eq(29)
    end

    it "knows it has been started" do
      expect(rollup).to be_started
    end
  end

  describe "an untouched set" do
    subject(:rollup) { described_class.new([ node(:available), node(:locked) ]) }

    it "reports zero percent" do
      expect(rollup.percent_complete).to be_zero
    end

    it "is not started" do
      expect(rollup).not_to be_started
    end
  end

  describe "an empty set" do
    subject(:rollup) { described_class.new([]) }

    it "reports zero rather than dividing by zero" do
      expect(rollup.total).to be_zero
      expect(rollup.percent_complete).to be_zero
    end

    it "has no next node" do
      expect(rollup.next_node).to be_nil
    end
  end

  describe "#percent_complete" do
    it "reports 100 only when every node is complete" do
      expect(described_class.new([ node(:complete), node(:complete) ]).percent_complete).to eq(100)
    end

    it "does not reach 100 while one node is merely in progress" do
      rollup = described_class.new([ node(:complete), node(:in_progress) ])
      expect(rollup.percent_complete).to eq(50)
    end

    it "rounds rather than truncating" do
      expect(described_class.new([ node(:complete), node(:locked), node(:locked) ]).percent_complete)
        .to eq(33)
    end
  end

  describe "#next_node" do
    it "prefers a skill already in progress over an untouched one" do
      in_progress = node(:in_progress)
      rollup = described_class.new([ node(:available), in_progress ])
      expect(rollup.next_node).to eq(in_progress)
    end

    it "falls back to the first available skill" do
      first_available = node(:available)
      rollup = described_class.new([ node(:complete), first_available, node(:available) ])
      expect(rollup.next_node).to eq(first_available)
    end

    it "offers nothing when everything is locked or done" do
      expect(described_class.new([ node(:complete), node(:locked) ]).next_node).to be_nil
    end
  end

  describe "#mission_count" do
    it "sums the missions across the set" do
      rollup = described_class.new([
        node(:complete, topics: [ :a, :b ]), node(:available, topics: [ :c ])
      ])
      expect(rollup.mission_count).to eq(3)
    end
  end

  it "tolerates a nil collection" do
    expect(described_class.new(nil).total).to be_zero
  end
end
