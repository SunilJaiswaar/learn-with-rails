namespace :code_sandbox do
  # Runs a snippet through the sandbox *directly*, bypassing StaticGuard, and
  # returns what the assertion produced.
  #
  # The guard is only the first layer; these checks must prove the sandbox
  # holds on its own, so they cannot go through CodeExecution::Runner (which
  # would reject `require "socket"` before the sandbox ever ran).
  def sandbox_value(code, expression: "go")
    test = Struct.new(:name, :call_expression, :expected, keyword_init: true)
    limits = CodeExecution::Limits.default

    Dir.mktmpdir("codequest-verify-") do |dir|
      workdir = Pathname(dir)
      harness = CodeExecution::Harness.new(
        workdir: workdir, code: code,
        tests: [ test.new(name: "probe", call_expression: expression, expected: nil) ]
      ).stage!

      CodeExecution::Sandbox::Bubblewrap
        .new(workdir: workdir, limits: limits)
        .run(CodeExecution::Harness::SOLUTION)

      Array(harness.result_payload&.dig("tests")).first&.dig("actual")
    end
  end

  desc "Report whether the Ruby code sandbox works, and prove its isolation"
  task verify: :environment do
    probe = CodeExecution::Sandbox::Bubblewrap.probe_result

    unless probe[:ok]
      puts "FAIL Ruby code sandbox is unavailable: #{probe[:reason]}"
      puts
      puts "Learner code cannot be executed on this host. The runner refuses to"
      puts "fall back to running it in-process, so code challenges are disabled"
      puts "rather than unsafe."
      puts
      puts "On Ubuntu 24.04+ unprivileged user namespaces are restricted by"
      puts "AppArmor. To allow them:"
      puts "  sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0"
      exit 1
    end

    test = Struct.new(:name, :call_expression, :expected, keyword_init: true)

    checks = {
      "runs a submission" => lambda {
        CodeExecution::Runner.new(
          code: "def go; 40 + 2; end",
          tests: [ test.new(name: "t", call_expression: "go", expected: "42") ]
        ).call.passed?
      },
      "blocks the network" => lambda {
        sandbox_value(<<~RUBY) == '"blocked"'
          def go
            require "socket"
            TCPSocket.new("1.1.1.1", 80)
            "reached"
          rescue Exception
            "blocked"
          end
        RUBY
      },
      "hides the host filesystem" => lambda {
        sandbox_value(<<~RUBY) == '"unreadable"'
          def go
            ::File.read("/etc/passwd")
            "readable"
          rescue Exception
            "unreadable"
          end
        RUBY
      },
      "hides the application's own source" => lambda {
        sandbox_value(<<~RUBY) == '"unreadable"'
          def go
            ::File.read("#{Rails.root.join('config/database.yml')}")
            "readable"
          rescue Exception
            "unreadable"
          end
        RUBY
      },
      "hides the server environment" => lambda {
        sandbox_value('def go; ENV["DATABASE_URL"] || ENV["SECRET_KEY_BASE"]; end') == "nil"
      },
      "rejects obvious abuse before execution" => lambda {
        CodeExecution::Runner.new(
          code: "def go; system('ls'); end",
          tests: [ test.new(name: "t", call_expression: "go", expected: "1") ]
        ).call.status == :rejected
      },
      "bounds CPU" => lambda {
        limits = CodeExecution::Limits.new(
          cpu_seconds: 2,
          address_space_bytes: CodeExecution::Limits::MIN_ADDRESS_SPACE,
          file_size_bytes: 1_000_000, max_processes: 16, wall_margin_seconds: 4
        )
        CodeExecution::Runner.new(
          code: "def go; loop {}; end",
          tests: [ test.new(name: "t", call_expression: "go", expected: "1") ],
          limits: limits
        ).call.status == :timed_out
      }
    }

    failures = []
    checks.each do |label, check|
      ok = begin
        check.call
      rescue StandardError => e
        puts "     (#{e.class}: #{e.message})"
        false
      end
      puts "#{ok ? 'OK  ' : 'FAIL'} #{label}"
      failures << label unless ok
    end

    if failures.any?
      puts "\nCode sandbox isolation checks failed: #{failures.join(', ')}"
      exit 1
    end
    puts "\nRuby code sandbox verified."
  end
end
