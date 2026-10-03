module Tutoring
  # The default provider: deterministic, transparent and dependency-free.
  #
  # It is not a weaker imitation of a model — it reads evidence the model would
  # not have (the exact assertion that failed, the authored answer key) and its
  # output is reproducible, which is what makes it safe to grade with.
  class RuleBasedProvider
    def name
      "rubric"
    end

    def model_backed?
      false
    end

    # Explains a failed or passing submission from the sandbox's evidence.
    def explain_attempt(attempt)
      CodeExplainer.new(attempt: attempt).call
    end

    # Grades an open-ended answer against the authored concept list.
    def evaluate_answer(question:, answer:)
      Interviews::AnswerEvaluator.new(question: question, answer: answer).call
    end
  end
end
