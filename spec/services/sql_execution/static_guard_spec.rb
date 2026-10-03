require "rails_helper"

RSpec.describe SqlExecution::StaticGuard do
  def rejection_for(sql)
    described_class.new(sql).call
  end

  it "allows a plain SELECT" do
    expect(rejection_for("SELECT name FROM employees")).to be_nil
  end

  it "allows a CTE" do
    expect(rejection_for("WITH t AS (SELECT 1 AS n) SELECT n FROM t")).to be_nil
  end

  it "allows a window function" do
    expect(rejection_for("SELECT rank() OVER (ORDER BY salary DESC) FROM employees")).to be_nil
  end

  it "allows EXPLAIN, so query plans can be taught" do
    expect(rejection_for("EXPLAIN SELECT 1")).to be_nil
  end

  it "allows a leading comment" do
    expect(rejection_for("-- my approach\nSELECT 1")).to be_nil
  end

  it "allows one trailing semicolon" do
    expect(rejection_for("SELECT 1;")).to be_nil
  end

  it "rejects an empty submission" do
    expect(rejection_for("  ").reason).to match(/empty/)
  end

  %w[
    INSERT\ INTO\ employees\ VALUES(9)
    UPDATE\ employees\ SET\ salary=1
    DELETE\ FROM\ employees
    TRUNCATE\ employees
    DROP\ TABLE\ employees
    CREATE\ TABLE\ x(y\ int)
    ALTER\ TABLE\ employees\ ADD\ z\ int
    GRANT\ ALL\ ON\ employees\ TO\ PUBLIC
  ].each do |statement|
    it "rejects #{statement.split.first}" do
      expect(rejection_for(statement)).not_to be_nil
    end
  end

  it "rejects several statements in one submission" do
    expect(rejection_for("SELECT 1; DROP TABLE employees").reason)
      .to match(/single statement/)
  end

  it "rejects catalogue introspection" do
    expect(rejection_for("SELECT * FROM pg_catalog.pg_user")).not_to be_nil
  end

  it "rejects server-side file functions" do
    expect(rejection_for("SELECT pg_read_file('/etc/passwd')")).not_to be_nil
  end

  it "rejects transaction control" do
    expect(rejection_for("SELECT 1 FROM employees; COMMIT")).not_to be_nil
  end

  # Keywords inside string literals are data, not commands.
  it "does not reject a forbidden word appearing inside a string literal" do
    expect(rejection_for("SELECT * FROM order_items WHERE product = 'update kit'")).to be_nil
  end

  it "does not reject a column whose name contains a keyword" do
    expect(rejection_for('SELECT "created_at" FROM orders')).to be_nil
  end

  it "rejects an oversized query" do
    expect(rejection_for("SELECT #{'1,' * 3_000}1").reason).to match(/limited to/)
  end
end
