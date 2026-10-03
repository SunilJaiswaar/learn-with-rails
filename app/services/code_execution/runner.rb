module CodeExecution
  # Orchestrates one sandboxed evaluation of a submission.
  #
  #   Rails -> Runner -> StaticGuard -> Sandbox (bwrap + rlimits) -> Result
  #
  # The Rails process never evaluates learner code itself (spec 74).
  class Runner
    class SandboxUnavailable < StandardError; end

    def self.sandbox_class
      @sandbox_class ||= begin
        configured = Rails.configuration.x.code_execution.sandbox.to_s
        candidate = case configured
                    when "bubblewrap" then Sandbox::Bubblewrap
                    when "disabled" then Sandbox::Disabled
                    else detect_sandbox
                    end
        candidate.available? ? candidate : Sandbox::Disabled
      end
    end

    def self.detect_sandbox
      Sandbox::Bubblewrap.available? ? Sandbox::Bubblewrap : Sandbox::Disabled
    end

    def self.sandbox_available?
      sandbox_class != Sandbox::Disabled
    end

    def self.reset_sandbox_cache!
      @sandbox_class = nil
    end

    def initialize(code:, tests:, limits: Limits.default)
      @code = code.to_s
      @tests = Array(tests)
      @limits = limits
    end

    def call
      rejection = StaticGuard.new(code).call
      return rejected(rejection.reason) if rejection

      if self.class.sandbox_class == Sandbox::Disabled
        return Result.new(status: :error, tests: [], stdout: "", stderr: "",
                          runtime_ms: 0,
                          message: "Code execution is unavailable: no sandbox " \
                                   "backend is configured on this host.")
      end

      in_workdir do |dir|
        harness = Harness.new(workdir: dir, code: code, tests: tests).stage!
        outcome = self.class.sandbox_class
                      .new(workdir: dir, limits: limits)
                      .run(Harness::SOLUTION)
        interpret(outcome, harness)
      end
    end

    private

    attr_reader :code, :tests, :limits

    def in_workdir
      Dir.mktmpdir("codequest-run-") do |dir|
        yield Pathname(dir)
      end
    end

    def interpret(outcome, harness)
      payload = harness.result_payload

      if outcome.timed_out
        return Result.new(
          status: :timed_out, tests: [], stdout: outcome.stdout, stderr: outcome.stderr,
          runtime_ms: outcome.runtime_ms,
          message: "Your code ran longer than the #{limits.cpu_seconds}s limit. " \
                   "Look for an infinite loop or a runaway recursion."
        )
      end

      # No report means the process died before it could write one, which is
      # what an out-of-memory kill or a hard signal looks like.
      if payload.nil?
        return Result.new(
          status: :error, tests: [], stdout: outcome.stdout, stderr: outcome.stderr,
          runtime_ms: outcome.runtime_ms,
          message: failure_message(outcome)
        )
      end

      if payload["load_error"].present?
        error = payload["load_error"]
        return Result.new(
          status: :error, tests: [], stdout: outcome.stdout, stderr: outcome.stderr,
          runtime_ms: outcome.runtime_ms,
          message: "#{error['class']}: #{error['message']}"
        )
      end

      tests = Array(payload["tests"]).map { |t| symbolize_test(t) }
      status = tests.any? && tests.all? { |t| t[:passed] } ? :passed : :failed

      Result.new(status: status, tests: tests, stdout: outcome.stdout,
                 stderr: outcome.stderr, runtime_ms: outcome.runtime_ms, message: nil)
    end

    def failure_message(outcome)
      if outcome.stderr.to_s.match?(/Cannot allocate memory|NoMemoryError|failed to allocate/)
        "Your code exceeded the memory limit."
      elsif outcome.stderr.present?
        outcome.stderr.to_s.lines.last(3).join.strip.presence ||
          "The sandbox stopped your program before it finished."
      else
        "The sandbox stopped your program before it finished. " \
          "This usually means it used too much memory or spawned processes."
      end
    end

    def symbolize_test(test)
      {
        name: test["name"],
        passed: !!test["passed"],
        expected: test["expected"],
        actual: test["actual"],
        error: test["error"],
        runtime_ms: test["runtime_ms"]
      }
    end

    def rejected(reason)
      Result.new(status: :rejected, tests: [], stdout: "", stderr: "",
                 runtime_ms: 0, message: reason)
    end
  end
end
