require "rails_helper"

# The SQL playground is a second execution boundary, so it gets the same
# treatment as the Ruby sandbox: prove it reads the fixtures, and prove it
# cannot reach anything else.
RSpec.describe SqlExecution::Runner do
  before do
    skip "SQL playground unavailable on this host" unless sql_sandbox_available?
  end

  def run(sql, **options)
    described_class.new(sql: sql, **options).call
  end

  describe "grading" do
    it "passes when the result set matches" do
      result = run("SELECT count(*) FROM employees", expected_rows: [ [ "8" ] ])

      expect(result).to be_passed
      expect(result.rows).to eq([ [ "8" ] ])
    end

    it "fails when the values differ" do
      result = run("SELECT count(*) FROM employees", expected_rows: [ [ "99" ] ])

      expect(result.status).to eq(:failed)
      expect(result.message).to match(/values do not match/)
    end

    it "reports a row-count mismatch specifically" do
      result = run("SELECT name FROM employees", expected_rows: [ [ "Chen" ] ])

      expect(result.message).to match(/Expected 1 row\(s\), got 8/)
    end

    it "ignores row order by default" do
      result = run("SELECT name FROM employees WHERE department_id = 2 ORDER BY name DESC",
                   expected_rows: [ [ "Bruno" ], [ "Dana" ], [ "Emeka" ] ])

      expect(result).to be_passed
    end

    it "enforces row order when the challenge asked for it" do
      result = run("SELECT name FROM employees WHERE department_id = 2 ORDER BY name DESC",
                   expected_rows: [ [ "Bruno" ], [ "Dana" ], [ "Emeka" ] ],
                   ordered: true)

      expect(result.status).to eq(:failed)
    end

    it "compares values regardless of the driver's Ruby types" do
      # salary comes back as BigDecimal; the expectation is authored as a string.
      result = run("SELECT salary FROM employees WHERE name = 'Chen'",
                   expected_rows: [ [ "120000.0" ] ])

      expect(result).to be_passed
    end

    it "treats NULL as distinct from an empty string" do
      result = run("SELECT budget FROM departments WHERE name = 'Logistics'",
                   expected_rows: [ [ nil ] ])

      expect(result).to be_passed
    end
  end

  describe "technique requirements" do
    let(:expected) { [ [ "95000.0" ] ] }
    let(:query) { "SELECT DISTINCT salary FROM employees ORDER BY salary DESC OFFSET 1 LIMIT 1" }

    it "passes when the required construct is present" do
      result = run(query, expected_rows: expected,
                   requirements: [ { "label" => "DISTINCT", "pattern" => "DISTINCT" } ])

      expect(result).to be_passed
    end

    it "fails a correct result that skipped the required construct" do
      result = run("SELECT salary FROM employees ORDER BY salary DESC OFFSET 1 LIMIT 1",
                   expected_rows: expected,
                   requirements: [ { "label" => "DISTINCT", "pattern" => "DISTINCT" } ])

      expect(result.status).to eq(:failed)
      expect(result.requirement_failures.join).to match(/DISTINCT/)
    end

    it "fails when a forbidden construct is used" do
      result = run("SELECT max(salary) FROM employees WHERE salary < (SELECT max(salary) FROM employees)",
                   expected_rows: expected,
                   forbidden: [ { "label" => "a subquery", "pattern" => "\\(\\s*SELECT" } ])

      expect(result.status).to eq(:failed)
      expect(result.requirement_failures.join).to match(/without a subquery/)
    end
  end

  describe "isolation" do
    it "cannot read the application's own tables" do
      result = run("SELECT email FROM public.users")

      expect(result.status).to eq(:error)
      expect(result.message).to match(/permission denied/i)
    end

    it "cannot read application tables via the search path either" do
      result = run("SELECT count(*) FROM users")

      expect(result.status).to eq(:error)
    end

    it "runs as the restricted role, not the application role" do
      result = run("SELECT current_user", expected_rows: [ [ SqlExecution::SandboxSchema::ROLE ] ])

      expect(result).to be_passed
    end

    it "is inside a read-only transaction" do
      result = run("SELECT current_setting('transaction_read_only')",
                   expected_rows: [ [ "on" ] ])

      expect(result).to be_passed
    end

    it "cannot call superuser file functions" do
      result = run("SELECT pg_read_file('/etc/passwd')")

      expect(result.status).to be_in(%i[rejected error])
    end

    it "bounds a long-running query" do
      result = run("SELECT count(*) FROM generate_series(1, 500000000)", timeout_ms: 250)

      expect(result.status).to eq(:timed_out)
      expect(result.message).to match(/longer than 250ms/)
    end

    it "leaves the application connection on its own role" do
      run("SELECT 1", expected_rows: [ [ "1" ] ])

      expect(ActiveRecord::Base.connection.select_value("SELECT current_user"))
        .not_to eq(SqlExecution::SandboxSchema::ROLE)
    end

    it "does not let a query persist anything" do
      # Writes are refused outright, so the fixture row count is unchanged.
      run("SELECT 1", expected_rows: [ [ "1" ] ])
      after = run("SELECT count(*) FROM employees", expected_rows: [ [ "8" ] ])

      expect(after).to be_passed
    end
  end

  describe "database errors" do
    it "reports an unknown table in the database's own words" do
      result = run("SELECT * FROM nonexistent_table")

      expect(result.status).to eq(:error)
      expect(result.message).to match(/does not exist/)
    end

    it "reports a syntax error" do
      result = run("SELECT name FROM employees ORDER BY")

      expect(result.status).to eq(:error)
      expect(result.message).to match(/syntax error/)
    end
  end
end
