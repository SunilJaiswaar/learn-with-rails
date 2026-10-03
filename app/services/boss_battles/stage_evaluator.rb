module BossBattles
  # Grades one stage of a boss battle and advances or ends the attempt.
  #
  # Stages are heterogeneous: a stage may be a diagnosis (keyword-graded), a
  # choice (exact match) or a code challenge (delegated to the sandbox).
  class StageEvaluator
    Outcome = Struct.new(:correct, :score, :feedback, :finished, :won, :xp,
                         keyword_init: true)

    PASS_MARK = 60

    def initialize(attempt:, answer:)
      @attempt = attempt
      @answer = answer
    end

    def call
      spec = attempt.current_stage_spec
      return Outcome.new(correct: false, score: 0, feedback: "No stage to grade.",
                         finished: true, won: false, xp: 0) if spec.nil?

      evaluation = grade(spec)
      record_result(spec, evaluation)

      if evaluation[:score] >= PASS_MARK
        advance(spec, evaluation)
      else
        # A failed stage does not end the battle: the learner retries the stage,
        # which is the point of a boss.
        Outcome.new(correct: false, score: evaluation[:score],
                    feedback: evaluation[:feedback], finished: false, won: false, xp: 0)
      end
    end

    private

    attr_reader :attempt, :answer

    def grade(spec)
      case spec["kind"]
      when "choice" then grade_choice(spec)
      else grade_open(spec)
      end
    end

    def grade_choice(spec)
      correct = answer.strip == spec["answer"].to_s.strip
      {
        score: correct ? 100 : 0,
        feedback: correct ? spec["explanation"].to_s : spec["wrong_hint"].to_s.presence ||
                            "Not quite. Reread the evidence and try again.",
        matched: [], missed: []
      }
    end

    # Open stages are graded on the concepts the diagnosis must contain.
    def grade_open(spec)
      keywords = Array(spec["keywords"]).map(&:to_s)
      text = answer.downcase
      matched = keywords.select { |k| text.include?(k.downcase) }
      missed = keywords - matched

      score = if keywords.empty?
                answer.split(/\s+/).size >= 10 ? 70 : 30
      else
                ((matched.size.to_f / keywords.size) * 100).round
      end
      score = (score * 0.5).round if answer.split(/\s+/).size < 6

      feedback = if score >= PASS_MARK
                   spec["explanation"].to_s
      else
                   "Your diagnosis is missing: #{missed.first(3).to_sentence}."
      end
      { score: score, feedback: feedback, matched: matched, missed: missed }
    end

    def record_result(spec, evaluation)
      results = attempt.results.reject { |r| r["stage"].to_i == attempt.current_stage }
      results << {
        "stage" => attempt.current_stage,
        "label" => spec["label"],
        "score" => evaluation[:score],
        "answer" => answer.first(2_000),
        "missed" => evaluation[:missed]
      }
      attempt.update!(stage_results: results)
    end

    def advance(spec, evaluation)
      next_stage = attempt.current_stage + 1
      total_stages = attempt.boss_battle.stage_count

      if next_stage >= total_stages
        finish_victory(evaluation)
      else
        attempt.update!(current_stage: next_stage)
        Outcome.new(correct: true, score: evaluation[:score],
                    feedback: evaluation[:feedback], finished: false, won: false, xp: 0)
      end
    end

    def finish_victory(evaluation)
      scores = attempt.results.map { |r| r["score"].to_i }
      final = scores.empty? ? 0 : (scores.sum / scores.size)
      boss = attempt.boss_battle

      attempt.update!(status: :won, score: final, finished_at: Time.current,
                      xp_awarded: boss.xp_reward)

      award = Gamification::XpAward.new(
        user: attempt.user, amount: boss.xp_reward,
        reason: "Boss defeated: #{boss.title}",
        source: attempt, idempotency_key: "boss:#{boss.id}"
      ).call

      if boss.skill
        Mastery::Recorder.new(
          user: attempt.user, skill: boss.skill, dimension: :application,
          score: final, correct: true
        ).call
      end
      Gamification::StreakTracker.new(user: attempt.user).record_activity!

      Outcome.new(correct: true, score: final, feedback: boss.debrief.to_s,
                  finished: true, won: true, xp: award.awarded)
    end
  end
end
