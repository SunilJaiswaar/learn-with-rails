require "rails_helper"

# The core loop: submit code, get graded in a sandbox, earn XP, and have the
# attempt recorded as mastery evidence.
RSpec.describe "Challenge submission", type: :request do
  let(:user) { create(:user) }
  let(:skill) { create(:skill) }
  let(:challenge) { create(:challenge, :with_tests, :with_hints, skill: skill, xp_award: 30) }

  before do
    skip "no sandbox backend on this host" unless CodeExecution::Runner.sandbox_available?
    sign_in_as(user)
  end

  def submit(code)
    post challenge_attempts_path(challenge_id: challenge.slug),
         params: { code: code },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  context "with a correct solution" do
    let(:solution) { "def double(n)\n  n * 2\nend" }

    it "records a passing attempt" do
      submit(solution)

      attempt = user.challenge_attempts.last
      expect(attempt).to be_passed
      expect(attempt.tests_passed).to eq(2)
    end

    it "awards XP once, not on every re-solve" do
      expect { submit(solution) }.to change { user.reload.xp_total }.by(30)
      expect { submit(solution) }.not_to change { user.reload.xp_total }
    end

    it "records implementation evidence against the skill" do
      submit(solution)

      progress = SkillProgress.find_by(user: user, skill: skill)
      expect(progress.implementation_score).to be > 0
      expect(progress.correct_count).to eq(1)
    end

    it "starts a streak" do
      submit(solution)

      expect(user.reload.streak.current_length).to eq(1)
    end

    it "schedules the challenge further out for revision" do
      submit(solution)

      schedule = ReviewSchedule.find_by(user: user, reviewable: challenge)
      expect(schedule.due_on).to be > Date.current
    end

    it "shows the result and an XP toast" do
      submit(solution)

      expect(response.body).to include("challenge-result")
      expect(response.body).to include("+30 XP")
    end
  end

  context "with an incorrect solution" do
    it "records a failing attempt and awards no XP" do
      expect { submit("def double(n)\n  n + 1\nend") }
        .not_to change { user.reload.xp_total }

      expect(user.challenge_attempts.last).to be_failed
    end

    it "still records evidence, so failure counts as practice" do
      submit("def double(n)\n  n + 1\nend")

      progress = SkillProgress.find_by(user: user, skill: skill)
      expect(progress.attempts_count).to eq(1)
      expect(progress.correct_count).to eq(0)
    end

    it "brings the challenge back for revision sooner" do
      submit("def double(n)\n  n + 1\nend")

      schedule = ReviewSchedule.find_by(user: user, reviewable: challenge)
      expect(schedule.lapses).to eq(1)
      expect(schedule.due_on).to eq(Date.current)
    end
  end

  context "when the submission is hostile" do
    it "is rejected before execution" do
      submit("def double(n)\n  system('ls')\nend")

      expect(user.challenge_attempts.last).to be_rejected
      expect(response.body).to include("does not allow spawning processes")
    end
  end

  describe "hints" do
    it "reveals one rung at a time and charges XP" do
      # Start from a non-zero balance: the displayed total floors at zero, so a
      # penalty against an empty balance is not observable there.
      Gamification::XpAward.new(user: user, amount: 100, reason: "Starting balance").call

      expect {
        post challenge_hint_path(challenge_id: challenge.slug),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change { user.reload.xp_total }.by(-2)

      expect(user.hint_reveals.count).to eq(1)
    end

    it "records the penalty in the ledger even when the balance is already zero" do
      post challenge_hint_path(challenge_id: challenge.slug),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(user.reload.xp_total).to eq(0)
      expect(user.xp_transactions.where("amount < 0").sum(:amount)).to eq(-2)
    end

    it "reduces the payout for a challenge solved after a hint" do
      post challenge_hint_path(challenge_id: challenge.slug),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      submit("def double(n)\n  n * 2\nend")

      award = user.xp_transactions.find_by(idempotency_key: "challenge:#{challenge.id}")
      expect(award.amount).to eq(28)
    end

    it "charges for a given hint only once" do
      2.times do
        post challenge_hint_path(challenge_id: challenge.slug),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      # Two reveals means two different rungs, each charged once.
      expect(user.hint_reveals.count).to eq(2)
      expect(user.xp_transactions.where("amount < 0").count).to eq(2)
    end
  end

  describe "rate limiting" do
    it "stops a learner queueing unlimited sandbox runs" do
      ChallengeAttemptsController::THROTTLE_LIMIT.times do
        user.challenge_attempts.create!(challenge: challenge, submitted_code: "x",
                                        status: :failed)
      end

      submit("def double(n)\n  n * 2\nend")

      expect(response.body).to include("submitting very quickly")
    end
  end
end
