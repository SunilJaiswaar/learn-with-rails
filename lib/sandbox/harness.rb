# frozen_string_literal: true
#
# Runs INSIDE the sandbox. Responsibilities, in order:
#   1. apply resource limits (done here, not on the bwrap process, because
#      RLIMIT_NPROC on bwrap itself breaks user-namespace creation)
#   2. load the learner's submission
#   3. evaluate each authored assertion against it
#   4. write a machine-readable report to result.json
#
# Nothing here trusts the submission: every eval is wrapped, and the report is
# written even when the submission fails to parse. Runs with --disable-gems, so
# only stdlib is available.

require "json"

module SandboxHarness
  RESULT_FILE = "result.json"
  MANIFEST_FILE = "manifest.json"
  MAX_VALUE_CHARS = 2_000

  class << self
    def run(solution_path)
      apply_limits
      manifest = JSON.parse(File.read(MANIFEST_FILE))
      report = { "load_error" => nil, "tests" => [] }

      # Load the submission first; a syntax error here means no test can run.
      begin
        load_submission(solution_path)
      rescue Exception => e # rubocop:disable Lint/RescueException
        report["load_error"] = describe_exception(e)
        write(report)
        return
      end

      report["tests"] = Array(manifest["tests"]).map { |spec| run_test(spec) }
      write(report)
    end

    private

    def apply_limits
      set_limit(Process::RLIMIT_CPU, env_int("SBX_CPU", 5))
      set_limit(Process::RLIMIT_AS, env_int("SBX_AS", 536_870_912))
      set_limit(Process::RLIMIT_FSIZE, env_int("SBX_FSIZE", 2_097_152))
      set_limit(Process::RLIMIT_NPROC, env_int("SBX_NPROC", 32))
      set_limit(Process::RLIMIT_CORE, 0)
    end

    def set_limit(resource, value)
      Process.setrlimit(resource, value, value)
    rescue StandardError
      # A limit we cannot set is not fatal: bwrap already provides isolation,
      # and the wall-clock timeout in the parent is the backstop.
      nil
    end

    def env_int(key, fallback)
      value = ENV[key]
      value.nil? || value.empty? ? fallback : Integer(value)
    end

    # Evaluated at top level so that `def` in the submission defines methods
    # reachable from the assertions.
    def load_submission(path)
      eval(File.read(path), TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
    end

    def run_test(spec)
      name = spec["name"].to_s
      expression = spec["call_expression"].to_s
      expected = spec["expected"]
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        actual = eval(expression, TOPLEVEL_BINDING, "(assertion)") # rubocop:disable Security/Eval
        actual_repr = safe_inspect(actual)
        passed = expected.nil? || actual_repr == expected.to_s
        {
          "name" => name,
          "passed" => passed,
          "expected" => expected,
          "actual" => actual_repr,
          "error" => nil,
          "runtime_ms" => elapsed_ms(started)
        }
      rescue Exception => e # rubocop:disable Lint/RescueException
        {
          "name" => name,
          "passed" => false,
          "expected" => expected,
          "actual" => nil,
          "error" => describe_exception(e),
          "runtime_ms" => elapsed_ms(started)
        }
      end
    end

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
    end

    # The submission may define a hostile #inspect, so guard it and cap length.
    def safe_inspect(value)
      text = value.inspect.to_s
      text.length > MAX_VALUE_CHARS ? "#{text[0, MAX_VALUE_CHARS]}..." : text
    rescue Exception # rubocop:disable Lint/RescueException
      "<uninspectable #{value.class}>"
    end

    def describe_exception(error)
      klass = begin
        error.class.name
      rescue Exception # rubocop:disable Lint/RescueException
        "Exception"
      end
      message = begin
        error.message.to_s[0, 500]
      rescue Exception # rubocop:disable Lint/RescueException
        "(unreadable message)"
      end
      line = Array(error.backtrace).first.to_s[0, 200]
      { "class" => klass, "message" => message, "where" => line }
    end

    def write(report)
      File.write(RESULT_FILE, JSON.generate(report))
    rescue StandardError
      nil
    end
  end
end

SandboxHarness.run(ARGV.fetch(0))
