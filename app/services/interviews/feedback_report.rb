module Interviews
  # Produces per-competency feedback (spec 45).
  #
  # Deliberately never outputs a pass/fail promise: it reports strong areas,
  # weak areas, gaps and what to revise.
  class FeedbackReport
    # Which competencies a question type is evidence for.
    COMPETENCY_MAP = {
      "mcq" => %w[technical_accuracy],
      "coding" => %w[technical_accuracy problem_solving],
      "sql" => %w[technical_accuracy performance_awareness],
      "debugging" => %w[debugging problem_solving],
      "output_prediction" => %w[technical_accuracy depth],
      "architecture" => %w[architecture tradeoffs],
      "system_design" => %w[architecture tradeoffs depth],
      "security" => %w[security_awareness technical_accuracy],
      "scenario" => %w[problem_solving tradeoffs],
      "optimization" => %w[performance_awareness problem_solving]
    }.freeze

    def self.xp_for(overall)
      # Scaled so a serious attempt is worth real XP without rewarding noise.
      base = 80
      (base + (overall.to_i * 1.2)).round
    end

    def initialize(interview:)
      @interview = interview
    end

    def call
      answers = interview.interview_questions
                         .includes(:question, :interview_answer, :question_follow_up)
                         .filter_map { |iq| [ iq, iq.interview_answer ] if iq.interview_answer }

      competencies = score_competencies(answers)
      overall = competencies.values.compact.then do |values|
        values.empty? ? 0 : (values.sum / values.size.to_f).round
      end

      {
        overall: overall,
        competencies: competencies,
        strong_areas: label_areas(competencies) { |score| score >= 75 },
        weak_areas: label_areas(competencies) { |score| score < 50 },
        knowledge_gaps: knowledge_gaps(answers),
        recommended_revision: recommended_revision(answers),
        answered: answers.size,
        communication_note: communication_note(answers)
      }
    end

    private

    attr_reader :interview

    def score_competencies(answers)
      buckets = Hash.new { |h, k| h[k] = [] }

      answers.each do |interview_question, answer|
        competencies = COMPETENCY_MAP.fetch(interview_question.question.question_type,
                                            %w[technical_accuracy])
        competencies.each { |name| buckets[name] << answer.score }
        # Depth is judged by how well probes were handled, not opening answers.
        buckets["depth"] << answer.score if interview_question.follow_up?
        buckets["communication"] << communication_score(answer)
      end

      Interview::COMPETENCIES.index_with do |name|
        scores = buckets[name]
        scores.empty? ? nil : (scores.sum / scores.size.to_f).round
      end
    end

    # A proxy for communication: did the answer explain, or just name-drop?
    def communication_score(answer)
      words = answer.body.to_s.split(/\s+/).size
      structure = answer.body.to_s.match?(/because|so that|which means|therefore|whereas/i)
      score = case words
      when 0...8 then 30
      when 8...30 then 60
      when 30...150 then 85
      else 75
      end
      structure ? [ score + 10, 100 ].min : score
    end

    def label_areas(competencies)
      competencies.filter_map do |name, score|
        next if score.nil?
        next unless yield(score)

        { "name" => name.humanize, "score" => score }
      end
    end

    # Concepts the learner failed to mention, aggregated across the interview.
    def knowledge_gaps(answers)
      answers.flat_map { |_iq, answer| answer.missed_keywords }
             .tally
             .sort_by { |_concept, count| -count }
             .first(8)
             .map { |concept, count| { "concept" => concept, "times_missed" => count } }
    end

    def recommended_revision(answers)
      weak = answers.select { |_iq, answer| answer.score < 60 }
      weak.filter_map { |interview_question, _answer| interview_question.question.skill }
          .uniq
          .first(5)
          .map { |skill| { "skill" => skill.name, "slug" => skill.slug } }
    end

    def communication_note(answers)
      return nil if answers.empty?

      average = answers.sum { |_iq, a| communication_score(a) } / answers.size
      if average >= 80
        "You explained your reasoning, not just your conclusion."
      elsif average >= 55
        "Your answers were on topic but often stopped at the conclusion. " \
          "Say why, and name the trade-off."
      else
        "Answers were very short. Interviewers read brevity as uncertainty: " \
          "state the reason and one consequence."
      end
    end
  end
end
