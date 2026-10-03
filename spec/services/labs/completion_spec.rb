require "rails_helper"

RSpec.describe Labs::Completion do
  let(:user) { create(:user) }
  let!(:skill) { skill_at("git-fundamentals") }

  def complete(**overrides)
    described_class.new(
      user: user, lab_key: "git_lab", xp: 120,
      reason: "Rebased a feature branch", detail: "rebase-exercise",
      **overrides
    ).call
  end

  it "awards the lab's XP" do
    outcome = complete
    expect(outcome.xp).to eq(120)
    expect(user.xp_transactions.find_by(idempotency_key: "lab:git_lab:rebase-exercise").amount)
      .to eq(120)
  end

  it "records mastery evidence in the dimension the lab exercises" do
    outcome = complete
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(outcome.skill).to eq(skill)
    expect(progress.application_score).to be_positive
    expect(progress.attempts_count).to eq(1)
    expect(progress.correct_count).to eq(1)
  end

  it "leaves the other dimensions untouched, so a lab cannot mint mastery alone" do
    complete
    progress = SkillProgress.find_by(user: user, skill: skill)

    expect(progress.understanding_score).to be_zero
    expect(progress.debugging_score).to be_zero
    expect(progress.mastery_level).not_to eq("mastered")
  end

  it "records evidence against :debugging for a diagnosis lab" do
    skill_at("observability")
    described_class.new(
      user: user, lab_key: "incidents", xp: 200,
      reason: "Resolved an incident", detail: "n-plus-one"
    ).call

    progress = SkillProgress.find_by(user: user, skill: Skill.find_by(slug: "observability"))
    expect(progress.debugging_score).to be_positive
    expect(progress.application_score).to be_zero
  end

  it "schedules the skill for revision" do
    complete
    schedule = ReviewSchedule.find_by(user: user, reviewable: skill)

    expect(schedule).to be_present
    expect(schedule.skill).to eq(skill)
  end

  it "pays out once for the same accomplishment but keeps recording practice" do
    complete
    second = complete

    expect(second.xp).to be_zero
    expect(user.xp_transactions.where(idempotency_key: "lab:git_lab:rebase-exercise").count).to eq(1)
    expect(SkillProgress.find_by(user: user, skill: skill).attempts_count).to eq(2)
  end

  it "pays out separately for a different accomplishment in the same lab" do
    complete
    other = complete(detail: "cherry-pick-exercise", reason: "Cherry-picked a commit")

    expect(other.xp).to eq(120)
    expect(user.xp_transactions.where("idempotency_key LIKE 'lab:git_lab:%'").count).to eq(2)
  end

  it "counts towards the streak and the daily quests" do
    expect(Gamification::StreakTracker).to receive(:new).with(user: user).and_call_original
    expect(Learning::QuestProgress).to receive(:new).with(user: user).and_call_original
    complete
  end

  it "does nothing for an unknown lab rather than awarding unattributed XP" do
    outcome = described_class.new(
      user: user, lab_key: "not_a_lab", xp: 500, reason: "nope"
    ).call

    expect(outcome.xp).to be_zero
    expect(outcome.skill).to be_nil
    expect(user.xp_transactions.count).to be_zero
  end

  it "does nothing without a user" do
    outcome = described_class.new(
      user: nil, lab_key: "git_lab", xp: 120, reason: "anonymous"
    ).call

    expect(outcome.xp).to be_zero
    expect(SkillProgress.where(skill: skill)).to be_empty
  end

  it "still awards XP when the mapped skill has not been seeded" do
    without_skill("concurrency")
    outcome = described_class.new(
      user: user, lab_key: "cpu_scheduler", xp: 90,
      reason: "Scheduled a workload", detail: "sjf"
    ).call

    expect(outcome.xp).to eq(90)
    expect(outcome.skill).to be_nil
  end
end
