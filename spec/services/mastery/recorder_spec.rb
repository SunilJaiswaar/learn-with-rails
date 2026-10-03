require "rails_helper"

# Mastery must require evidence across every dimension (spec 48, 65).
RSpec.describe Mastery::Recorder do
  let(:user) { create(:user) }
  let(:skill) { create(:skill) }

  def record(dimension, score, correct: nil)
    described_class.new(user: user, skill: skill, dimension: dimension,
                        score: score, correct: correct).call
  end

  it "creates progress on first evidence" do
    progress = record(:implementation, 80)

    expect(progress.implementation_score).to eq(80)
    expect(progress.attempts_count).to eq(1)
  end

  it "blends later evidence rather than overwriting it" do
    record(:implementation, 100)
    progress = record(:implementation, 0)

    expect(progress.implementation_score).to be_between(1, 99)
  end

  it "only moves the dimension it was given" do
    progress = record(:debugging, 90)

    expect(progress.debugging_score).to eq(90)
    expect(progress.implementation_score).to eq(0)
  end

  it "does not grant mastery from reading alone" do
    5.times { record(:understanding, 100) }
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.mastery_level).not_to eq("mastered")
    expect(progress.mastery_level).to eq("weak")
  end

  it "grants mastery only when every dimension clears its bar" do
    # Repeat so the moving average converges above the threshold.
    12.times do
      SkillProgress::DIMENSIONS.each { |dimension| record(dimension, 100) }
    end
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.mastery_level).to eq("mastered")
    expect(progress.mastered_at).to be_present
  end

  it "holds the whole skill back when one dimension is untested" do
    12.times do
      (SkillProgress::DIMENSIONS - [ :debugging ]).each { |d| record(d, 100) }
    end
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.debugging_score).to eq(0)
    expect(progress.mastery_level).to eq("weak")
  end

  it "identifies the weakest dimension for the adaptive engine" do
    # Every dimension gets evidence so the comparison is between real scores
    # rather than between untested zeroes.
    SkillProgress::DIMENSIONS.each { |dimension| record(dimension, 80) }
    3.times { record(:debugging, 0) }
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.weakest_dimension).to eq(:debugging)
  end

  it "treats an untested dimension as the weakest point" do
    record(:understanding, 90)
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.dimension_scores[progress.weakest_dimension]).to eq(0)
  end

  it "tracks accuracy separately from scores" do
    record(:implementation, 100, correct: true)
    record(:implementation, 0, correct: false)
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.attempts_count).to eq(2)
    expect(progress.correct_count).to eq(1)
    expect(progress.accuracy_percent).to eq(50)
  end

  it "rejects an unknown dimension" do
    expect { record(:vibes, 50) }.to raise_error(ArgumentError, /unknown mastery dimension/)
  end

  it "weights building and debugging above reading" do
    weights = SkillProgress::DIMENSION_WEIGHTS

    expect(weights[:implementation]).to be > weights[:understanding]
    expect(weights[:debugging]).to be > weights[:understanding]
  end
end
