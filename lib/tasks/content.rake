namespace :content do
  desc "Run every challenge's reference solution through the sandbox and report failures"
  task validate_solutions: :environment do
    challenges = Challenge.includes(:challenge_tests).order(:slug)
    failures = []
    skipped = []

    unless CodeExecution::Runner.sandbox_available?
      abort "No code execution sandbox available; cannot validate solutions."
    end
    unless SqlExecution::Runner.available?
      abort "SQL playground not provisioned; run rails sql_sandbox:provision"
    end

    challenges.each do |challenge|
      if challenge.reference_solution.blank?
        skipped << challenge.slug
        next
      end

      result = if challenge.sql_language?
                 SqlExecution::Runner.new(
                   sql: challenge.reference_solution,
                   expected_rows: challenge.primary_test&.expected_rows || [],
                   ordered: challenge.ordered_result?,
                   timeout_ms: challenge.time_limit_ms,
                   requirements: challenge.required_constructs,
                   forbidden: challenge.forbidden_constructs
                 ).call
      else
                 CodeExecution::Runner.new(
                   code: challenge.reference_solution,
                   tests: challenge.challenge_tests.ordered.to_a,
                   limits: CodeExecution::Limits.for_challenge(challenge)
                 ).call
      end

      passed = challenge.sql_language? ? (result.passed? ? 1 : 0) : result.tests_passed
      total = challenge.sql_language? ? 1 : result.tests_total

      printf("%-4s %-5s %-34s %d/%d  %sms\n", result.passed? ? "PASS" : "FAIL",
             challenge.language, challenge.slug, passed, total, result.runtime_ms)

      next if result.passed?

      failures << {
        slug: challenge.slug,
        status: result.status,
        message: result.message,
        failed: challenge.sql_language? ? [] : result.tests.reject { |t| t[:passed] }
      }
    end

    puts "\n#{challenges.size - skipped.size} validated, #{failures.size} failing"
    puts "Skipped (no reference solution): #{skipped.join(', ')}" if skipped.any?

    if failures.any?
      puts "\nFailures:"
      failures.each do |failure|
        puts "\n  #{failure[:slug]} (#{failure[:status]})"
        puts "    #{failure[:message]}" if failure[:message]
        failure[:failed].each do |test|
          puts "    - #{test[:name]}"
          puts "        expected: #{test[:expected].inspect}"
          puts "        actual:   #{test[:actual].inspect}"
          puts "        error:    #{test[:error]['class']}: #{test[:error]['message']}" if test[:error]
        end
      end
      abort "\nReference solutions must pass their own tests."
    end
  end

  desc "Report any mission that does not satisfy the definition of done (spec 80)"
  task definition_of_done: :environment do
    incomplete = Topic.includes(:lessons, :challenges, :questions).reject(&:complete_content?)

    Topic.order(:slug).each do |topic|
      missing = topic.definition_of_done.reject { |_k, v| v }.keys
      printf("%-5s %-24s %s\n", missing.empty? ? "OK" : "GAP", topic.slug,
             missing.join(", "))
    end

    abort "\n#{incomplete.size} mission(s) incomplete." if incomplete.any?
    puts "\nAll #{Topic.count} missions complete."
  end

  desc "Check that the starter code of every debug challenge actually fails"
  task validate_debug_starters: :environment do
    # A debugging challenge whose starter already passes teaches nothing.
    wrong = []
    Challenge.debug_challenge.includes(:challenge_tests).order(:slug).each do |challenge|
      next if challenge.starter_code.blank?

      result = if challenge.sql_language?
                 SqlExecution::Runner.new(
                   sql: challenge.starter_code,
                   expected_rows: challenge.primary_test&.expected_rows || [],
                   ordered: challenge.ordered_result?,
                   timeout_ms: challenge.time_limit_ms,
                   requirements: challenge.required_constructs,
                   forbidden: challenge.forbidden_constructs
                 ).call
      else
                 CodeExecution::Runner.new(
                   code: challenge.starter_code,
                   tests: challenge.challenge_tests.ordered.to_a,
                   limits: CodeExecution::Limits.for_challenge(challenge)
                 ).call
      end

      broken = !result.passed?
      printf("%-4s %-34s starter %s\n", broken ? "OK" : "BAD", challenge.slug,
             broken ? "fails as intended (#{result.status})" : "already passes")
      wrong << challenge.slug unless broken
    end

    abort "\nThese debug challenges have starters that already pass: #{wrong.join(', ')}" if wrong.any?
    puts "\nEvery debug starter fails as intended."
  end
end
