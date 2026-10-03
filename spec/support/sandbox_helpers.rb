# Runs code through the sandbox while deliberately bypassing StaticGuard.
#
# The guard is only the first layer; these helpers let the specs prove that the
# sandbox still contains hostile code when the guard is bypassed entirely.
module SandboxHelpers
  TestCase = Struct.new(:name, :call_expression, :expected, keyword_init: true)

  def sandbox_run(code, expression:, expected:, limits: nil)
    limits ||= CodeExecution::Limits.default
    tests = [ TestCase.new(name: "assertion", call_expression: expression,
                           expected: expected) ]

    Dir.mktmpdir("codequest-spec-") do |dir|
      workdir = Pathname(dir)
      harness = CodeExecution::Harness.new(workdir: workdir, code: code, tests: tests).stage!
      outcome = CodeExecution::Sandbox::Bubblewrap
                    .new(workdir: workdir, limits: limits)
                    .run(CodeExecution::Harness::SOLUTION)
      { outcome: outcome, payload: harness.result_payload }
    end
  end

  # The value the single assertion produced, as an inspect string.
  def sandbox_value(code, expression:, expected: nil)
    result = sandbox_run(code, expression: expression, expected: expected)
    Array(result[:payload]&.dig("tests")).first&.dig("actual")
  end
end
