module Cicd
  # The simulated deployment pipeline for the CI/CD repair game (spec 35).
  #
  # The stage list and build log are deterministic functions of one piece of
  # learner state — whether the security fix was applied — so none of it needs
  # to be persisted. Only the flag is kept in the session, which matters: the
  # full pipeline is roughly 5KB and overflows the 4KB cookie session.
  class Pipeline
    REQUIRED_FIX = "parameterized_query"

    STAGE_NAMES = [
      "1. Checkout & Git Push",
      "2. Dependency Cache (Bundler)",
      "3. Code Linting (RuboCop)",
      "4. Automated Test Suite (RSpec)",
      "5. Security Vulnerability Scan (Brakeman)",
      "6. Docker Container Build",
      "7. Production Deploy (Rolling Update)"
    ].freeze

    DURATIONS = %w[3s 14s 8s 22s 6s 45s 18s].freeze

    # The security gate is stage 5; everything after it is gated on that pass.
    SECURITY_GATE_INDEX = 4

    def self.for(security_fix)
      new(security_fix: security_fix)
    end

    def initialize(security_fix:)
      @passing = security_fix.to_s == REQUIRED_FIX
    end

    def passing?
      @passing
    end

    def status
      passing? ? "passed" : "failed"
    end

    def stages
      STAGE_NAMES.each_with_index.map do |name, index|
        {
          "name" => name,
          "status" => stage_status(index),
          "duration" => stage_status(index) == "skipped" ? "—" : DURATIONS[index]
        }
      end
    end

    def logs
      passing? ? passing_logs : failing_logs
    end

    def to_view_model
      { "status" => status, "stages" => stages, "logs" => logs,
        "security_fix" => passing? ? REQUIRED_FIX : nil }
    end

    private

    def stage_status(index)
      return "passed" if passing?
      return "passed" if index < SECURITY_GATE_INDEX
      return "failed" if index == SECURITY_GATE_INDEX

      "skipped"
    end

    def passing_logs
      [
        "[00:03] git checkout -q 7f91a02b",
        "[00:17] bundle check --path vendor/bundle (Cache HIT)",
        "[00:25] bin/rubocop --parallel: no offenses detected",
        "[00:47] bundle exec rspec: all examples passed",
        "[00:53] bin/brakeman -q: 0 security warnings. SQL injection eliminated.",
        "[01:38] docker build -t registry.example.dev/app:7f91a02b . [SUCCESS]",
        "[01:56] kubectl rollout status deployment/web: rolled out to 12 pods"
      ].join("\n")
    end

    def failing_logs
      [
        "[00:03] git checkout -q 7f91a02b",
        "[00:17] bundle check --path vendor/bundle (Cache HIT)",
        "[00:25] bin/rubocop --parallel: no offenses detected",
        "[00:47] bundle exec rspec: all examples passed",
        "[00:52] bin/brakeman -q: 1 CRITICAL WARNING DETECTED",
        "         Confidence: High",
        "         Category: SQL Injection",
        "         Check: SQL",
        "         File: app/controllers/users_controller.rb:14",
        %q{         Code: User.where("name = '#{params[:name]}'")},
        "         Error: Raw user input interpolated into a SQL clause without",
        "                parameterisation.",
        "[00:53] Security gate failed. Pipeline halted. Docker build skipped."
      ].join("\n")
    end
  end
end
