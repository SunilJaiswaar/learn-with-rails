require "rails_helper"

# The follow-up engine is what stops memorised answers scoring well (spec 43).
RSpec.describe Interviews::FollowUpPlanner do
  let(:user) { create(:user) }
  let(:question) { create(:question) }
  let(:interview) { create(:interview, user: user) }
  let(:interview_question) do
    create(:interview_question, interview: interview, question: question, position: 0)
  end

  def plan(answer)
    described_class.new(interview_question: interview_question, answer_text: answer)
                   .next_follow_up
  end

  it "asks an always-triggered probe regardless of the answer" do
    follow_up = create(:question_follow_up, question: question, trigger_kind: "always")

    expect(plan("anything at all")).to eq(follow_up)
  end

  it "asks a keyword probe only when the learner raised that topic" do
    create(:question_follow_up, question: question, trigger_kind: "keyword",
           trigger_keywords: %w[redis], body: "Why is Redis faster?")

    expect(plan("Redis is faster than Postgres")).to be_present
    expect(plan("I would add a database index")).to be_nil
  end

  it "asks a missing-keyword probe when the learner skipped a concept" do
    create(:question_follow_up, question: question, trigger_kind: "missing_keyword",
           trigger_keywords: %w[invalidation], body: "How would you invalidate it?")

    expect(plan("I would cache the result")).to be_present
    expect(plan("I would cache it and handle invalidation on write")).to be_nil
  end

  it "does not repeat a probe that was already asked" do
    follow_up = create(:question_follow_up, question: question, trigger_kind: "always")
    create(:interview_question, interview: interview, question: question,
           question_follow_up: follow_up, position: 1)

    expect(plan("anything")).to be_nil
  end

  it "walks down the probe tree after a follow-up is answered" do
    parent = create(:question_follow_up, question: question, trigger_kind: "always")
    child = create(:question_follow_up, question: question, parent: parent,
                   trigger_kind: "always", depth: 2, body: "And then?")
    asked_parent = create(:interview_question, interview: interview, question: question,
                          question_follow_up: parent, position: 1)

    planner = described_class.new(interview_question: asked_parent, answer_text: "yes")

    expect(planner.next_follow_up).to eq(child)
  end

  it "stops probing after the depth limit so an interview cannot run forever" do
    described_class::MAX_FOLLOW_UPS_PER_QUESTION.times do |index|
      follow_up = create(:question_follow_up, question: question, trigger_kind: "always",
                         body: "Probe #{index}")
      create(:interview_question, interview: interview, question: question,
             question_follow_up: follow_up, position: index + 1)
    end
    create(:question_follow_up, question: question, trigger_kind: "always",
           body: "One more")

    expect(plan("anything")).to be_nil
  end
end
