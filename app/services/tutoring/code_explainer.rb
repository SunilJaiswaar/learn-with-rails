module Tutoring
  # Explains *why* a submission failed, from the evidence the sandbox produced.
  #
  # This is the deterministic tutor: it reads the actual failure — the error
  # class, the expected and actual values, the timing — and names the likely
  # cause. It never reveals the solution, because the hint ladder exists for
  # that and skipping to the answer is what the spec forbids.
  class CodeExplainer
    Explanation = Struct.new(:headline, :detail, :next_step, :source,
                             keyword_init: true)

    # Patterns recognised from an assertion's expected/actual pair. Ordered:
    # the first match wins, so specific diagnoses precede general ones.
    def initialize(attempt:)
      @attempt = attempt
      @challenge = attempt.challenge
    end

    def call
      case attempt.status
      when "passed" then passed
      when "rejected" then rejected
      when "timed_out" then timed_out
      when "error" then errored
      else failed
      end
    end

    private

    attr_reader :attempt, :challenge

    def passed
      Explanation.new(
        headline: "This passes.",
        detail: challenge.explanation.presence ||
                "Every assertion matched, including the hidden ones.",
        next_step: review_suggestion || "Read the explanation, then move on.",
        source: "rules"
      )
    end

    def rejected
      Explanation.new(
        headline: "This was refused before it ran.",
        detail: attempt.stderr.to_s.presence ||
                "The submission used something this challenge does not allow.",
        next_step: "Solve it with the language's own data structures.",
        source: "rules"
      )
    end

    def timed_out
      Explanation.new(
        headline: "Your code never finished.",
        detail: "It was stopped at the time limit rather than returning. " \
                "That is almost always an unbounded loop, a recursion with no " \
                "base case, or a loop whose variable never changes.",
        next_step: "Pick the loop and ask: what makes this get closer to " \
                   "stopping on every pass? If nothing does, that is the bug.",
        source: "rules"
      )
    end

    def errored
      message = attempt.stderr.to_s

      if message.match?(/SyntaxError/)
        Explanation.new(
          headline: "The code could not be parsed.",
          detail: "Nothing ran, so no assertion was even attempted. The " \
                  "message points at the first place the parser gave up — " \
                  "which is often just after the real mistake.",
          next_step: "Check the line above the one reported for an unclosed " \
                     "bracket, `do` or `end`.",
          source: "rules"
        )
      else
        Explanation.new(
          headline: "Your code raised before finishing.",
          detail: message.presence || "The program stopped with an error.",
          next_step: "Read the error class first: it tells you what kind of " \
                     "thing went wrong before you look at any line number.",
          source: "rules"
        )
      end
    end

    def failed
      first = failing_test
      return generic_failure if first.nil?

      diagnosis = diagnose(first)

      Explanation.new(
        headline: "#{attempt.tests_passed} of #{attempt.tests_total} " \
                  "assertions pass. The first failure is \"#{first['name']}\".",
        detail: diagnosis[:detail],
        next_step: diagnosis[:next_step],
        source: "rules"
      )
    end

    def generic_failure
      Explanation.new(
        headline: "Not passing yet.",
        detail: "No assertion detail was captured for this run.",
        next_step: "Re-run, and read the first failing assertion rather than " \
                   "the last.",
        source: "rules"
      )
    end

    def failing_test
      attempt.test_results.find { |test| !test["passed"] }
    end

    # Names the likely cause from the shape of the mismatch. Each branch is a
    # pattern that recurs across the whole curriculum.
    def diagnose(test)
      expected = test["expected"].to_s
      actual = test["actual"].to_s
      error = test["error"]

      if error.present?
        return {
          detail: "That assertion raised #{error['class']}: " \
                  "#{error['message']}.",
          next_step: error["class"] == "NoMethodError" && error["message"].to_s.include?("nil") ?
                     "Something returned nil earlier than you expected. The " \
                     "bug is where the nil came from, not where it was used." :
                     "Work out which input reaches that line, then trace it by hand."
        }
      end

      if actual == "nil"
        return { detail: "It returned nil where #{expected} was expected.",
                 next_step: "Check that every branch returns a value — a " \
                            "method whose last statement is an assignment or " \
                            "an `if` with no else can fall through to nil." }
      end

      if numeric?(expected) && numeric?(actual)
        return numeric_diagnosis(expected, actual)
      end

      if collection?(expected) && collection?(actual)
        return collection_diagnosis(expected, actual)
      end

      if expected.downcase == actual.downcase
        return { detail: "The value is right but the case differs: expected " \
                         "#{expected}, got #{actual}.",
                 next_step: "Normalise case before comparing or returning." }
      end

      { detail: "Expected #{expected}, got #{actual}.",
        next_step: "Work that one case through by hand before changing code." }
    end

    def numeric_diagnosis(expected, actual)
      difference = actual.to_f - expected.to_f

      if difference.abs == 1
        { detail: "Expected #{expected}, got #{actual} — out by exactly one.",
          next_step: "That is an off-by-one: check an inclusive versus " \
                     "exclusive range, or a `<` that should be `<=`." }
      elsif expected.to_f != 0 && (actual.to_f / expected.to_f - 2).abs < 0.001
        { detail: "Expected #{expected}, got #{actual} — exactly double.",
          next_step: "Something is being counted twice. Look for a value " \
                     "added inside a loop that should be added once." }
      elsif expected.include?(".") != actual.include?(".")
        { detail: "Expected #{expected}, got #{actual} — the value is right " \
                  "but the type is not.",
          next_step: "Integer division truncates, and an integer result where " \
                     "a float is expected usually means a `/` or a missing " \
                     "`to_f`." }
      else
        { detail: "Expected #{expected}, got #{actual}.",
          next_step: "Compute that case by hand and compare each step." }
      end
    end

    def collection_diagnosis(expected, actual)
      if expected.length == actual.length && expected.chars.sort == actual.chars.sort
        { detail: "The right elements, in the wrong order: expected " \
                  "#{expected}, got #{actual}.",
          next_step: "Add or correct the ordering — and if ties are possible, " \
                     "make the tie-break explicit." }
      elsif actual == "[]" || actual == "{}"
        { detail: "An empty collection came back where #{expected} was expected.",
          next_step: "The filter or loop matched nothing. Check the condition " \
                     "against a single known-good input." }
      else
        { detail: "Expected #{expected}, got #{actual}.",
          next_step: "Compare them element by element; the first difference is " \
                     "usually where the logic diverges." }
      end
    end

    def numeric?(value)
      value.match?(/\A-?\d+(\.\d+)?\z/)
    end

    def collection?(value)
      value.start_with?("[", "{")
    end

    # Surfaces the automated review only when it found something worth saying.
    def review_suggestion
      finding = attempt.review_findings.find { |f| f["severity"] != "info" }
      return nil if finding.nil?

      "The automated review notes: #{finding['message']} #{finding['suggestion']}"
    end
  end
end
