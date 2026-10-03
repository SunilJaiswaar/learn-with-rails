module Tutoring
  # Model-backed tutoring through the Claude Messages API.
  #
  # Active only when ANTHROPIC_API_KEY is set and the optional `anthropic` gem
  # is installed. Every call falls back to the rule-based provider on any
  # failure, so a credential problem or an outage degrades the explanation
  # rather than breaking the page.
  #
  # Grading deliberately still runs through the rubric: a learner's score
  # should be reproducible and explainable, and the model is used to *explain*
  # rather than to decide.
  class AnthropicProvider
    MAX_TOKENS = 1_024
    TIMEOUT_SECONDS = 20

    TUTOR_SYSTEM = <<~PROMPT.freeze
      You are a programming tutor inside a learning platform. A learner has
      submitted code that was executed in a sandbox, and you are given the
      actual result.

      Rules:
      - Never write the solution, or any line of the corrected code.
      - Name the single most likely cause of the failure, in one or two
        sentences.
      - Then give one concrete next action the learner can take themselves.
      - Refer only to evidence you were given. If it is insufficient, say so.
      - Be direct. No praise, no preamble.

      Reply as JSON only: {"headline": "...", "detail": "...", "next_step": "..."}
    PROMPT

    def name
      "model-backed"
    end

    def model_backed?
      true
    end

    def explain_attempt(attempt)
      response = request(prompt_for(attempt))
      parsed = parse(response)
      return fallback.explain_attempt(attempt) if parsed.nil?

      CodeExplainer::Explanation.new(
        headline: parsed["headline"].to_s,
        detail: parsed["detail"].to_s,
        next_step: parsed["next_step"].to_s,
        source: "model"
      )
    rescue StandardError => e
      Rails.logger.warn("Tutoring::AnthropicProvider failed: #{e.class}: #{e.message}")
      fallback.explain_attempt(attempt)
    end

    # Scores stay on the rubric: a grade a learner cannot reproduce or appeal
    # is worse than a slightly cruder one.
    def evaluate_answer(question:, answer:)
      fallback.evaluate_answer(question: question, answer: answer)
    end

    private

    def fallback
      @fallback ||= RuleBasedProvider.new
    end

    def client
      @client ||= begin
        require "anthropic"
        Anthropic::Client.new(api_key: Provider.api_key, timeout: TIMEOUT_SECONDS)
      end
    end

    def request(user_content)
      client.messages.create(
        model: Provider.model.to_sym,
        max_tokens: MAX_TOKENS,
        system_: [ { type: "text", text: TUTOR_SYSTEM } ],
        messages: [ { role: "user", content: user_content } ]
      )
    end

    # `content` is an array of polymorphic blocks and `type` is a Symbol, so
    # text has to be selected rather than assumed to be first.
    def parse(response)
      text = Array(response.content)
             .select { |block| block.type == :text }
             .map(&:text)
             .join

      json = text[/\{.*\}/m]
      return nil if json.nil?

      parsed = JSON.parse(json)
      return nil unless parsed.is_a?(Hash) && parsed["headline"].present?

      parsed
    rescue JSON::ParserError
      nil
    end

    # Only the failure evidence is sent — never the reference solution, which
    # would let the model leak the answer it has been told not to give.
    def prompt_for(attempt)
      failing = attempt.test_results.reject { |t| t["passed"] }.first(3)

      <<~TEXT
        Challenge: #{attempt.challenge.title}
        Task: #{attempt.challenge.prompt.to_s.truncate(600)}

        Status: #{attempt.status}
        Assertions passing: #{attempt.tests_passed} of #{attempt.tests_total}

        Submitted code:
        #{attempt.submitted_code.to_s.truncate(2_000)}

        Failing assertions:
        #{failing.map { |t| format_failure(t) }.join("\n")}

        Error output:
        #{attempt.stderr.to_s.truncate(600).presence || '(none)'}
      TEXT
    end

    def format_failure(test)
      if test["error"].present?
        "- #{test['name']}: raised #{test['error']['class']}: #{test['error']['message']}"
      else
        "- #{test['name']}: expected #{test['expected']}, got #{test['actual']}"
      end
    end
  end
end
