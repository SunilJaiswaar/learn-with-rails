module Interviews
  # Grades an open-ended answer against the concepts it should contain.
  #
  # This is a transparent rubric, not a black box: the learner is shown exactly
  # which concepts were recognised and which were missing, so feedback is
  # actionable and never a fabricated guarantee (spec 45).
  #
  # `Tutoring::Provider` can swap in a model-backed evaluator; the rubric is
  # the default so the platform works with no external dependency.
  class AnswerEvaluator
    Evaluation = Struct.new(:score, :correct, :matched, :missed, :verdict, :notes,
                            keyword_init: true) do
      def to_payload
        {
          "matched" => matched, "missed" => missed, "verdict" => verdict,
          "notes" => notes, "score" => score
        }
      end
    end

    # An answer that says nothing specific should not score well no matter how
    # many keywords it happens to contain.
    MIN_SUBSTANTIVE_WORDS = 8
    HEDGE_PATTERNS = [
      /\bnot sure\b/i, /\bi think maybe\b/i, /\bno idea\b/i, /\bguess\b/i
    ].freeze

    def initialize(question:, answer:)
      @question = question
      @answer = answer.to_s
    end

    def call
      return mcq_evaluation if question.respond_to?(:mcq?) && question.mcq?

      keyword_evaluation
    end

    private

    attr_reader :question, :answer

    def mcq_evaluation
      chosen = answer.strip
      correct = chosen.present? && chosen.to_i == question.correct_index
      Evaluation.new(
        score: correct ? 100 : 0,
        correct: correct,
        matched: correct ? [ question.choices[question.correct_index] ] : [],
        missed: correct ? [] : [ question.choices[question.correct_index] ].compact,
        verdict: correct ? "correct" : "incorrect",
        notes: question.explanation
      )
    end

    def keyword_evaluation
      expected = question.expected_keywords.map(&:to_s)
      required = question.respond_to?(:required_keywords) ? question.required_keywords : []
      text = answer.downcase

      matched = expected.select { |k| mentions?(text, k) }
      missed = expected - matched
      missing_required = required.reject { |k| mentions?(text, k) }

      score = compute_score(expected, matched, missing_required)
      Evaluation.new(
        score: score,
        correct: score >= 60 && missing_required.empty?,
        matched: matched,
        missed: missed,
        verdict: verdict_for(score),
        notes: notes_for(missing_required, missed)
      )
    end

    # Word-boundary match so "index" does not match "indexes" by accident in one
    # direction only; multi-word concepts are matched as phrases.
    def mentions?(text, keyword)
      needle = keyword.to_s.downcase.strip
      return false if needle.empty?

      if needle.include?(" ")
        text.include?(needle)
      else
        text.match?(/\b#{Regexp.escape(needle)}\w{0,3}\b/)
      end
    end

    def compute_score(expected, matched, missing_required)
      return 0 if answer.strip.empty?

      words = answer.split(/\s+/).size
      coverage = expected.empty? ? 0.6 : (matched.size.to_f / expected.size)
      score = (coverage * 100).round

      # Depth matters: a two-word answer cannot demonstrate reasoning.
      score = (score * 0.5).round if words < MIN_SUBSTANTIVE_WORDS
      score -= 15 if HEDGE_PATTERNS.any? { |p| answer.match?(p) }
      # A missing required concept caps the score: the answer has a real gap.
      score = [ score, 45 ].min if missing_required.any?

      score.clamp(0, 100)
    end

    def verdict_for(score)
      case score
      when 80.. then "strong"
      when 60...80 then "solid"
      when 35...60 then "partial"
      else "weak"
      end
    end

    def notes_for(missing_required, missed)
      parts = []
      if missing_required.any?
        parts << "Your answer did not address: #{missing_required.to_sentence}."
      elsif missed.any?
        parts << "You could also have mentioned: #{missed.first(4).to_sentence}."
      end
      parts.join(" ").presence
    end
  end
end
