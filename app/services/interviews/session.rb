module Interviews
  # Drives a live interview: records an answer, decides whether to probe
  # further, and finalises the report.
  class Session
    def initialize(interview:)
      @interview = interview
    end

    # Records the answer, then inserts a follow-up probe when the answer invites
    # one (spec 43).
    def submit_answer!(interview_question:, body:)
      evaluation = AnswerEvaluator.new(
        question: interview_question.follow_up? ? interview_question.question_follow_up
                                               : interview_question.question,
        answer: body
      ).call

      answer = nil
      ActiveRecord::Base.transaction do
        answer = InterviewAnswer.create!(
          interview_question: interview_question,
          body: body,
          score: evaluation.score,
          evaluation: evaluation.to_payload
        )

        insert_follow_up(interview_question, body)
        record_mastery(interview_question, evaluation)
      end

      finish! if interview.reload.current_question.nil?
      answer
    end

    def finish!
      return interview if interview.completed_interview?

      report = FeedbackReport.new(interview: interview).call
      xp = FeedbackReport.xp_for(report[:overall])

      interview.update!(
        status: :completed,
        completed_at: Time.current,
        competency_scores: report[:competencies],
        feedback: report.except(:competencies).deep_stringify_keys,
        xp_awarded: xp
      )

      Gamification::XpAward.new(
        user: interview.user, amount: xp,
        reason: "Interview simulation: #{interview.interview_template&.name || 'practice'}",
        source: interview, idempotency_key: "interview:#{interview.id}"
      ).call

      interview
    end

    private

    attr_reader :interview

    def insert_follow_up(interview_question, body)
      follow_up = FollowUpPlanner.new(
        interview_question: interview_question, answer_text: body
      ).next_follow_up
      return if follow_up.nil?

      # The probe is inserted immediately after the answer it came from.
      next_position = (interview.interview_questions.maximum(:position) || 0) + 1
      interview.interview_questions.create!(
        interview_round: interview_question.interview_round,
        question: interview_question.question,
        question_follow_up: follow_up,
        position: next_position,
        time_limit_seconds: interview.seconds_per_question
      )
    end

    # Interview performance is evidence of explanation ability.
    def record_mastery(interview_question, evaluation)
      skill = interview_question.question.skill
      return if skill.nil?

      Mastery::Recorder.new(
        user: interview.user, skill: skill, dimension: :explanation,
        score: evaluation.score, correct: evaluation.correct
      ).call

      Learning::SpacedRepetition.new(user: interview.user)
                                .record!(reviewable: interview_question.question,
                                         correct: evaluation.correct, skill: skill)
    end
  end
end
