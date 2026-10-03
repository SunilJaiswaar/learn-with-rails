module Interviews
  # The follow-up engine (spec 43).
  #
  # A real interviewer probes: "Redis is faster" earns "Why?", then "What if it
  # goes down?". Follow-ups are selected from what the learner actually said, so
  # a memorised answer gets dismantled rather than rewarded.
  class FollowUpPlanner
    MAX_FOLLOW_UPS_PER_QUESTION = 3

    def initialize(interview_question:, answer_text:)
      @interview_question = interview_question
      @answer_text = answer_text.to_s
    end

    # Returns the follow-up to ask next, or nil when the thread is exhausted.
    def next_follow_up
      return nil if asked_count >= MAX_FOLLOW_UPS_PER_QUESTION

      candidates.find { |follow_up| follow_up.triggered_by?(answer_text) }
    end

    private

    attr_reader :interview_question, :answer_text

    def question
      interview_question.question
    end

    # Walk down the probe tree: children of the follow-up just answered, or the
    # root probes when this was the opening question.
    def candidates
      scope = if interview_question.follow_up?
                interview_question.question_follow_up.children
      else
                question.question_follow_ups.roots
      end

      scope.ordered.reject { |follow_up| already_asked_ids.include?(follow_up.id) }
    end

    def already_asked_ids
      @already_asked_ids ||= interview_question.interview
                                               .interview_questions
                                               .where.not(question_follow_up_id: nil)
                                               .pluck(:question_follow_up_id)
    end

    def asked_count
      interview_question.interview
                        .interview_questions
                        .where(question_id: question.id)
                        .where.not(question_follow_up_id: nil)
                        .count
    end
  end
end
