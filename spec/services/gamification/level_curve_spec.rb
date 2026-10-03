require "rails_helper"

RSpec.describe Gamification::LevelCurve do
  it "starts everyone at level 1 with no XP" do
    expect(described_class.level_for(0)).to eq(1)
  end

  it "requires no XP to reach level 1" do
    expect(described_class.threshold_for(1)).to eq(0)
  end

  it "increases the cost of each successive level" do
    gaps = (2..8).map do |level|
      described_class.threshold_for(level) - described_class.threshold_for(level - 1)
    end

    expect(gaps).to eq(gaps.sort)
    expect(gaps.first).to be < gaps.last
  end

  it "is consistent between level_for and threshold_for" do
    (1..20).each do |level|
      threshold = described_class.threshold_for(level)
      expect(described_class.level_for(threshold)).to eq(level)
      expect(described_class.level_for(threshold - 1)).to eq(level - 1) if level > 1
    end
  end

  it "caps at the maximum level" do
    expect(described_class.level_for(10**9)).to eq(described_class::MAX_LEVEL)
  end

  it "gives a title that never regresses as levels rise" do
    titles = (1..40).map { |level| described_class.title_for(level) }

    expect(titles.first).to eq("Curious Beginner")
    expect(titles.uniq.size).to be > 3
  end
end
