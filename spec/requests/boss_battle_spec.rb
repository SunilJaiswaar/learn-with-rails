require "rails_helper"

RSpec.describe "Boss battles", type: :request do
  let(:user) { create(:user) }
  let(:skill) { create(:skill) }
  let(:boss) do
    create(:boss_battle, skill: skill, xp_reward: 250,
           stages: [
             { "label" => "Diagnose", "kind" => "open",
               "prompt" => "Why is the total inflated?",
               "keywords" => %w[duplicate join],
               "explanation" => "Row multiplication from a one-to-many join." },
             { "label" => "Choose", "kind" => "choice",
               "prompt" => "Which fix?",
               "options" => [ "DISTINCT", "Aggregate in a CTE first" ],
               "answer" => "1",
               "explanation" => "Aggregating first removes the fan-out.",
               "wrong_hint" => "One of these breaks on equal values." }
           ])
  end

  before { sign_in_as(user) }

  def submit_stage(answer)
    patch boss_battle_stage_path(boss_battle_id: boss.slug),
          params: { answer: answer },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  it "requires starting the battle before a stage can be submitted" do
    submit_stage("anything")

    expect(response).to redirect_to(boss_battle_path(boss.slug))
    expect(BossAttempt.count).to eq(0)
  end

  it "creates one in-progress attempt when started" do
    post start_boss_battle_path(boss.slug)
    post start_boss_battle_path(boss.slug)

    expect(user.boss_attempts.where(status: :in_progress).count).to eq(1)
  end

  it "advances when an open stage is answered well" do
    post start_boss_battle_path(boss.slug)

    submit_stage("The join duplicates each order row, so the total is counted twice.")

    expect(user.boss_attempts.last.current_stage).to eq(1)
    expect(response.body).to include("Stage cleared")
  end

  it "keeps the learner on a failed stage rather than ending the battle" do
    post start_boss_battle_path(boss.slug)

    submit_stage("No idea.")

    attempt = user.boss_attempts.last
    expect(attempt.current_stage).to eq(0)
    expect(attempt).to be_in_progress_battle
    expect(response.body).to include("Not yet")
  end

  it "tells the learner which concepts were missing" do
    post start_boss_battle_path(boss.slug)

    submit_stage("Something is broken somewhere in the query.")

    expect(response.body).to include("missing")
  end

  it "awards XP and marks a win once every stage is cleared" do
    post start_boss_battle_path(boss.slug)
    submit_stage("The join duplicates rows, so the sum double counts.")

    expect { submit_stage("1") }.to change { user.reload.xp_total }.by(250)

    attempt = user.boss_attempts.last
    expect(attempt).to be_won_battle
    expect(attempt.score).to be > 0
    expect(response.body).to include("Boss defeated")
  end

  it "rejects the wrong choice with a hint instead of advancing" do
    post start_boss_battle_path(boss.slug)
    submit_stage("The join duplicates rows, so the sum double counts.")

    submit_stage("0")

    expect(user.boss_attempts.last).to be_in_progress_battle
    expect(response.body).to include("breaks on equal values")
  end

  it "records application evidence against the skill on a win" do
    post start_boss_battle_path(boss.slug)
    submit_stage("The join duplicates rows, so the total double counts.")
    submit_stage("1")

    progress = SkillProgress.find_by(user: user, skill: skill)
    expect(progress.application_score).to be > 0
  end

  it "pays the boss reward only once across repeat wins" do
    2.times do
      post start_boss_battle_path(boss.slug)
      submit_stage("The join duplicates rows, so the total double counts.")
      submit_stage("1")
    end

    awards = user.xp_transactions.where(idempotency_key: "boss:#{boss.id}")
    expect(awards.count).to eq(1)
  end
end
