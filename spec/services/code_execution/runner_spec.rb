require "rails_helper"

# These specs are the security boundary for the whole product: they assert that
# learner code cannot reach the network, the host filesystem, or unbounded
# CPU and memory (spec 74).
RSpec.describe CodeExecution::Runner do
  let(:test_struct) { Struct.new(:name, :call_expression, :expected, keyword_init: true) }

  def tests_for(expression, expected, name: "assertion")
    [ test_struct.new(name: name, call_expression: expression, expected: expected) ]
  end

  def run(code, tests: tests_for("double(2)", "4"), limits: nil)
    described_class.new(code: code, tests: tests,
                        limits: limits || CodeExecution::Limits.default).call
  end

  before do
    skip "no sandbox backend on this host" unless described_class.sandbox_available?
  end

  describe "correct submissions" do
    it "passes when every assertion matches" do
      result = run("def double(n)\n  n * 2\nend")

      expect(result.status).to eq(:passed)
      expect(result.tests_passed).to eq(1)
      expect(result.tests_total).to eq(1)
    end

    it "captures the learner's stdout separately from the report" do
      result = run("def double(n)\n  puts 'hello'\n  n * 2\nend")

      expect(result.status).to eq(:passed)
      expect(result.stdout).to include("hello")
    end
  end

  describe "incorrect submissions" do
    it "reports which assertion failed and what it produced" do
      result = run("def double(n)\n  n + 2\nend",
                   tests: tests_for("double(3)", "6"))

      expect(result.status).to eq(:failed)
      expect(result.tests.first[:expected]).to eq("6")
      expect(result.tests.first[:actual]).to eq("5")
    end

    it "surfaces a syntax error instead of crashing" do
      result = run("def double(n\n  n * 2\nend")

      expect(result.status).to eq(:error)
      expect(result.message).to include("SyntaxError")
    end

    it "records a runtime exception per assertion" do
      result = run("def double(n)\n  raise ArgumentError, 'nope'\nend")

      expect(result.status).to eq(:failed)
      expect(result.tests.first[:error]["class"]).to eq("ArgumentError")
      expect(result.tests.first[:error]["message"]).to eq("nope")
    end
  end

  describe "resource limits" do
    it "stops an infinite loop and explains why" do
      limits = CodeExecution::Limits.new(
        cpu_seconds: 2, address_space_bytes: CodeExecution::Limits::MIN_ADDRESS_SPACE,
        file_size_bytes: 1_000_000, max_processes: 16, wall_margin_seconds: 4
      )
      result = run("def double(n)\n  loop {}\nend", limits: limits)

      expect(result.status).to eq(:timed_out)
      expect(result.message).to match(/longer than the 2s limit/)
    end

    it "stops runaway memory allocation" do
      result = run(<<~RUBY)
        def double(n)
          store = []
          loop { store << ("x" * 1_000_000) }
        end
      RUBY

      # Either the harness catches NoMemoryError per assertion, or the process
      # is killed outright. Both are acceptable; silently succeeding is not.
      expect(result.status).to be_in(%i[failed error timed_out])
      expect(result.tests_passed).to eq(0)
    end
  end

  # These go through the sandbox directly, bypassing StaticGuard, to prove the
  # second layer holds on its own.
  describe "isolation (sandbox layer, guard bypassed)" do
    it "cannot reach the network" do
      value = sandbox_value(<<~RUBY, expression: "double(1)")
        def double(n)
          require "socket"
          TCPSocket.new("1.1.1.1", 80)
          "reached"
        rescue Exception
          "blocked"
        end
      RUBY

      expect(value).to eq('"blocked"')
    end

    it "cannot read files outside the sandbox" do
      value = sandbox_value(<<~RUBY, expression: "double(1)")
        def double(n)
          ::File.read("/etc/passwd")
          "readable"
        rescue Exception
          "unreadable"
        end
      RUBY

      expect(value).to eq('"unreadable"')
    end

    it "cannot read the application's own configuration" do
      value = sandbox_value(<<~RUBY, expression: "double(1)")
        def double(n)
          ::File.read("#{Rails.root}/config/database.yml")
          "readable"
        rescue Exception
          "unreadable"
        end
      RUBY

      expect(value).to eq('"unreadable"')
    end

    it "cannot write to the host filesystem" do
      target = Rails.root.join("tmp/should-never-exist.txt")
      value = sandbox_value(<<~RUBY, expression: "double(1)")
        def double(n)
          ::File.open("#{target}", "w") { |f| f << "x" }
          "wrote"
        rescue Exception
          "blocked"
        end
      RUBY

      expect(value).to eq('"blocked"')
      expect(File.exist?(target)).to be(false)
    end

    it "cannot spawn a shell" do
      value = sandbox_value(<<~RUBY, expression: "double(1)")
        def double(n)
          system("echo pwned") ? "ran" : "failed"
        rescue Exception
          "blocked"
        end
      RUBY

      expect(value).not_to eq('"ran"')
    end

    it "does not leak the server's environment into the sandbox" do
      value = sandbox_value(<<~RUBY, expression: "double(1)")
        def double(n)
          ENV["DATABASE_URL"] || ENV["SECRET_KEY_BASE"] || ENV["GEM_HOME"]
        end
      RUBY

      expect(value).to eq("nil")
    end
  end

  describe "the static guard" do
    it "rejects shell execution before running anything" do
      result = run("def double(n)\n  system('ls')\nend")

      expect(result.status).to eq(:rejected)
      expect(result.message).to match(/does not allow spawning processes/)
    end

    it "rejects an empty submission" do
      expect(run("").status).to eq(:rejected)
    end

    it "rejects an oversized submission" do
      result = run("x = 1\n" * 10_000)

      expect(result.status).to eq(:rejected)
      expect(result.message).to match(/exceeds/)
    end
  end
end
