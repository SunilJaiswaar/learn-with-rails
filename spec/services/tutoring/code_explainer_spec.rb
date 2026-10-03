require "rails_helper"

# The deterministic tutor. Its value is that it names a *specific* likely
# cause from the evidence, so the specs assert the diagnosis, not just that
# some text came back.
RSpec.describe Tutoring::CodeExplainer do
  let(:challenge) { create(:challenge, explanation: "Because of the invariant.") }

  def attempt_with(status:, tests: [], stderr: nil, passed: 0, total: 1, review: {})
    create(:challenge_attempt_stub_for_explainer,
           challenge: challenge, status: status, stderr: stderr,
           tests_passed: passed, tests_total: total,
           results: { "tests" => tests }, review: review)
  end

  def explain(attempt)
    described_class.new(attempt: attempt).call
  end

  it "reports the reference explanation on a pass" do
    result = explain(attempt_with(status: :passed, passed: 1))

    expect(result.headline).to match(/passes/i)
    expect(result.detail).to eq("Because of the invariant.")
  end

  it "surfaces a non-trivial review finding on a pass" do
    review = { "findings" => [ { "severity" => "warning",
                                 "message" => "Nested iteration.",
                                 "suggestion" => "Use a hash." } ] }
    result = explain(attempt_with(status: :passed, passed: 1, review: review))

    expect(result.next_step).to match(/Nested iteration/)
  end

  it "diagnoses an off-by-one from the numeric difference" do
    tests = [ { "name" => "counts", "passed" => false, "expected" => "5", "actual" => "6" } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.next_step).to match(/off-by-one/i)
    expect(result.next_step).to match(/inclusive|<=/)
  end

  it "diagnoses a doubled value as counting twice" do
    tests = [ { "name" => "total", "passed" => false, "expected" => "250", "actual" => "500" } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.next_step).to match(/counted twice/i)
  end

  it "diagnoses a nil return" do
    tests = [ { "name" => "returns", "passed" => false, "expected" => "4", "actual" => "nil" } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.detail).to match(/nil/)
    expect(result.next_step).to match(/every branch returns/i)
  end

  it "diagnoses right elements in the wrong order" do
    tests = [ { "name" => "sorted", "passed" => false,
                "expected" => "[1, 2, 3]", "actual" => "[3, 2, 1]" } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.detail).to match(/wrong order/i)
    expect(result.next_step).to match(/ordering/i)
  end

  it "diagnoses an empty collection as a filter that matched nothing" do
    tests = [ { "name" => "selects", "passed" => false,
                "expected" => "[1, 2]", "actual" => "[]" } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.next_step).to match(/matched nothing/i)
  end

  it "diagnoses a case-only difference" do
    tests = [ { "name" => "name", "passed" => false,
                "expected" => '"Asha"', "actual" => '"asha"' } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.detail).to match(/case differs/i)
  end

  it "points upstream when a nil was used, not where it was used" do
    tests = [ { "name" => "lookup", "passed" => false, "expected" => "1",
                "error" => { "class" => "NoMethodError",
                             "message" => "undefined method for nil" } } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect(result.next_step).to match(/where the nil came from/i)
  end

  it "explains a timeout as a loop that never progresses" do
    result = explain(attempt_with(status: :timed_out))

    expect(result.headline).to match(/never finished/i)
    expect(result.next_step).to match(/closer to stopping/i)
  end

  it "explains a syntax error as nothing having run" do
    result = explain(attempt_with(status: :error, stderr: "SyntaxError: unexpected end"))

    expect(result.headline).to match(/could not be parsed/i)
    expect(result.next_step).to match(/line above/i)
  end

  it "explains a rejection without revealing the guard's internals" do
    result = explain(attempt_with(status: :rejected,
                                  stderr: "This challenge does not allow shell access."))

    expect(result.headline).to match(/refused before it ran/i)
    expect(result.detail).to match(/does not allow/)
  end

  it "reports how many assertions pass and names the first failure" do
    tests = [ { "name" => "first case", "passed" => false, "expected" => "1", "actual" => "2" } ]
    result = explain(attempt_with(status: :failed, tests: tests, passed: 3, total: 5))

    expect(result.headline).to match(/3 of 5/)
    expect(result.headline).to match(/first case/)
  end

  it "never includes the reference solution" do
    challenge.update!(reference_solution: "def secret_answer; 42; end")
    tests = [ { "name" => "x", "passed" => false, "expected" => "1", "actual" => "2" } ]
    result = explain(attempt_with(status: :failed, tests: tests))

    expect([ result.headline, result.detail, result.next_step ].join)
      .not_to include("secret_answer")
  end
end
