module Challenges
  # One submission of learner code, end to end:
  #
  #   sandboxed run -> automated review -> mastery evidence -> XP
  #   -> spaced repetition -> quest progress -> achievements
  #
  # Everything that follows from "the tests passed" lives here so controllers
  # stay thin and the rules are testable in one place.
  class Submission
    Outcome = Struct.new(:attempt, :result, :xp, :award, keyword_init: true) do
      def passed?
        attempt.passed?
      end
    end

    def initialize(user:, challenge:, code:)
      @user = user
      @challenge = challenge
      @code = code.to_s
    end

    def call
      result = run_sandbox
      # The heuristic reviewer reads Ruby; it has nothing useful to say about SQL.
      review = if challenge.sql_language?
                 {}
      else
                 CodeReview::Analyzer.new(code: code, challenge: challenge).call
      end
      attempt = persist_attempt(result, review)

      award = nil
      if attempt.passed?
        award = grant_xp(attempt)
        attempt.update_column(:xp_awarded, award&.awarded.to_i)
      end

      record_evidence(attempt, result)
      Gamification::StreakTracker.new(user: user).record_activity!
      Learning::QuestProgress.new(user: user).sync!(target: challenge, kind: "challenge")

      Outcome.new(attempt: attempt, result: result, xp: award&.awarded.to_i, award: award)
    end

    private

    attr_reader :user, :challenge, :code

    # Ruby and SQL run in different sandboxes, so the submission picks the
    # right one and normalises both outcomes into one attempt record.
    def run_sandbox
      challenge.sql_language? ? run_sql : run_ruby
    end

    def run_ruby
      CodeExecution::Runner.new(
        code: code,
        tests: challenge.challenge_tests.ordered.to_a,
        limits: CodeExecution::Limits.for_challenge(challenge)
      ).call
    end

    def run_sql
      test = challenge.primary_test

      SqlExecution::Runner.new(
        sql: code,
        expected_rows: test&.expected_rows || [],
        ordered: challenge.ordered_result?,
        timeout_ms: challenge.time_limit_ms,
        requirements: challenge.required_constructs,
        forbidden: challenge.forbidden_constructs
      ).call
    end

    def persist_attempt(result, review)
      user.challenge_attempts.create!(
        challenge: challenge,
        submitted_code: code,
        status: result.status,
        tests_passed: passed_count(result),
        tests_total: total_count(result),
        runtime_ms: result.runtime_ms,
        stdout: result.try(:stdout).presence,
        stderr: [ result.try(:stderr).presence, result.message ].compact.join("\n").presence,
        results: result.to_results_payload,
        review: review
      )
    end

    # A SQL challenge is a single pass/fail against one expected result set,
    # which is reported as 1-of-1 so the shared progress meter still works.
    def passed_count(result)
      return result.passed? ? 1 : 0 if challenge.sql_language?

      result.tests_passed
    end

    def total_count(result)
      challenge.sql_language? ? 1 : result.tests_total
    end

    # XP is paid once per challenge; later re-solves are free practice.
    # Hints already revealed reduce the payout (spec 49, 55).
    def grant_xp(attempt)
      penalty = Tutoring::HintLadder.new(user: user, challenge: challenge).penalty_so_far
      amount = [ challenge.xp_award - penalty, 5 ].max

      Gamification::XpAward.new(
        user: user, amount: amount,
        reason: "Challenge solved: #{challenge.title}",
        source: attempt,
        idempotency_key: "challenge:#{challenge.id}",
        metadata: { "tests" => attempt.tests_total, "hint_penalty" => penalty }
      ).call
    end

    # The dimension exercised depends on the challenge shape, so debugging a bug
    # proves debugging rather than implementation (spec 48).
    def record_evidence(attempt, result)
      return if challenge.skill.nil?

      score = case result.status
      when :passed then 100
      when :failed then attempt.score_percent
      else 0
      end

      Mastery::Recorder.new(
        user: user, skill: challenge.skill,
        dimension: challenge.mastery_dimension,
        score: score, correct: attempt.passed?
      ).call

      Learning::SpacedRepetition.new(user: user)
                                .record!(reviewable: challenge,
                                         correct: attempt.passed?,
                                         skill: challenge.skill)
    end
  end
end
