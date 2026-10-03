require "rails_helper"

RSpec.describe Learning::SpacedRepetition do
  let(:user) { create(:user) }
  let(:challenge) { create(:challenge) }
  subject(:repetition) { described_class.new(user: user) }

  it "schedules a first review when evidence is recorded" do
    schedule = repetition.record!(reviewable: challenge, correct: false)

    expect(schedule.reviewable).to eq(challenge)
    expect(schedule.lapses).to eq(1)
  end

  it "pushes a correct answer further out each time" do
    first = repetition.record!(reviewable: challenge, correct: true).due_on
    second = repetition.record!(reviewable: challenge, correct: true).due_on

    expect(second).to be > first
  end

  it "brings a wrong answer back sooner" do
    4.times { repetition.record!(reviewable: challenge, correct: true) }
    far = ReviewSchedule.last.due_on

    near = repetition.record!(reviewable: challenge, correct: false).due_on

    expect(near).to be < far
  end

  it "never schedules earlier than today" do
    schedule = repetition.record!(reviewable: challenge, correct: false)

    expect(schedule.due_on).to be >= Date.current
  end

  it "keeps one schedule per item per user" do
    3.times { repetition.record!(reviewable: challenge, correct: true) }

    expect(ReviewSchedule.where(user: user, reviewable: challenge).count).to eq(1)
  end

  it "lists what is due today" do
    repetition.record!(reviewable: challenge, correct: false)

    expect(repetition.due_count).to eq(1)
    expect(repetition.due).to include(ReviewSchedule.last)
  end

  it "excludes items scheduled for the future" do
    5.times { repetition.record!(reviewable: challenge, correct: true) }

    expect(repetition.due_count).to eq(0)
  end
end
