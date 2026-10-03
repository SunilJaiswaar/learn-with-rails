module SqlExecution
  # Executes a learner's SQL against the fixture schema and grades the result.
  #
  #   Rails -> StaticGuard -> restricted role connection
  #         -> read-only transaction (always rolled back)
  #         -> row comparison -> Result
  #
  # Isolation rests on three things, not on the guard:
  #   * the connection authenticates as a role that can only SELECT from the
  #     sandbox schema, so application tables are unreadable
  #   * the transaction is read only, so DDL and DML are refused by the server
  #   * statement_timeout bounds how long any one query may run
  class Runner
    MAX_ROWS = 500
    DEFAULT_TIMEOUT_MS = 2_000

    class << self
      def available?
        SandboxSchema.provisioned?
      end

      # A separate connection pool for the restricted role, established on
      # SqlSandboxRecord rather than ActiveRecord::Base — doing it on the base
      # class would repoint the entire application at the sandbox role.
      def sandbox_pool
        @sandbox_pool ||= begin
          SqlSandboxRecord.establish_connection(sandbox_config)
          SqlSandboxRecord.connection_pool
        end
      end

      def sandbox_config
        ActiveRecord::Base.connection_db_config.configuration_hash.merge(
          username: SandboxSchema::ROLE,
          password: SandboxSchema.password,
          pool: 5,
          # The role authenticates by password, which needs a TCP connection
          # rather than the peer-authenticated local socket.
          host: ENV.fetch("SQL_SANDBOX_HOST", "127.0.0.1"),
          application_name: "codequest-sql-sandbox"
        )
      end

      def reset_pool!
        SqlSandboxRecord.remove_connection if @sandbox_pool
        @sandbox_pool = nil
      end
    end

    def initialize(sql:, expected_rows: [], ordered: false, timeout_ms: DEFAULT_TIMEOUT_MS,
                   requirements: [], forbidden: [])
      @sql = sql.to_s
      @expected_rows = normalise(expected_rows)
      @ordered = ordered
      @timeout_ms = timeout_ms
      @requirements = Array(requirements)
      @forbidden = Array(forbidden)
    end

    def call
      rejection = StaticGuard.new(@sql).call
      return rejected(rejection.reason) if rejection

      unless self.class.available?
        return Result.new(status: :error, message: "The SQL playground is not " \
                                                   "provisioned on this host.",
                          rows: [], columns: [], expected_rows: @expected_rows)
      end

      requirement_failures = check_requirements
      execute_and_grade(requirement_failures)
    end

    private

    # Construct requirements let a challenge insist on (or rule out) a
    # technique: "solve this with a window function", "without a subquery".
    def check_requirements
      failures = []
      body = @sql

      @requirements.each do |requirement|
        next if body.match?(Regexp.new(requirement["pattern"], Regexp::IGNORECASE))

        failures << "This challenge asks you to use #{requirement['label']}."
      end

      @forbidden.each do |requirement|
        next unless body.match?(Regexp.new(requirement["pattern"], Regexp::IGNORECASE))

        failures << "Solve this one without #{requirement['label']}."
      end

      failures
    end

    def execute_and_grade(requirement_failures)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      columns = []
      rows = []

      begin
        with_sandbox_connection do |connection|
          result = connection.exec_query(@sql)
          columns = result.columns
          rows = normalise(result.rows)
        end
      rescue ActiveRecord::QueryCanceled
        return Result.new(status: :timed_out, columns: [], rows: [],
                          expected_rows: @expected_rows,
                          runtime_ms: elapsed(started),
                          message: "Your query ran longer than #{@timeout_ms}ms. " \
                                   "Look at what it is scanning.")
      rescue ActiveRecord::StatementInvalid => e
        return Result.new(status: :error, columns: [], rows: [],
                          expected_rows: @expected_rows,
                          runtime_ms: elapsed(started),
                          message: database_message(e))
      end

      grade(columns, rows, requirement_failures, elapsed(started))
    end

    def grade(columns, rows, requirement_failures, runtime_ms)
      truncated = rows.length > MAX_ROWS
      comparable = truncated ? rows.first(MAX_ROWS) : rows

      matches = rows_match?(comparable)
      status = matches && requirement_failures.empty? ? :passed : :failed

      Result.new(
        status: status,
        columns: columns,
        rows: comparable,
        expected_rows: @expected_rows,
        row_count: rows.length,
        runtime_ms: runtime_ms,
        requirement_failures: requirement_failures,
        message: grading_message(matches, requirement_failures, truncated, comparable)
      )
    end

    def rows_match?(rows)
      if @ordered
        rows == @expected_rows
      else
        # Row order is only part of the answer when the challenge asked for it.
        rows.sort_by(&:to_s) == @expected_rows.sort_by(&:to_s)
      end
    end

    def grading_message(matches, requirement_failures, truncated, rows)
      return "Your query returned more than #{MAX_ROWS} rows." if truncated
      return requirement_failures.join(" ") if requirement_failures.any?
      return nil if matches

      if rows.length != @expected_rows.length
        "Expected #{@expected_rows.length} row(s), got #{rows.length}."
      else
        "The right number of rows, but the values do not match."
      end
    end

    # Runs on the restricted connection, inside a read-only transaction that is
    # always rolled back, with a statement timeout.
    def with_sandbox_connection
      self.class.sandbox_pool.with_connection do |connection|
        connection.transaction(requires_new: true) do
          connection.execute("SET LOCAL statement_timeout = #{@timeout_ms.to_i}")
          connection.execute("SET LOCAL transaction_read_only = on")
          connection.execute("SET LOCAL search_path TO #{Fixtures::SCHEMA}, pg_temp")

          yield connection

          raise ActiveRecord::Rollback
        end
      end
    end

    # Values arrive from the driver in mixed types (BigDecimal, Date, nil), so
    # both sides are reduced to strings for a stable, type-agnostic comparison.
    def normalise(rows)
      Array(rows).map do |row|
        Array(row).map { |value| value.nil? ? nil : value.to_s }
      end
    end

    def database_message(error)
      # The driver prefixes the class name and appends the failing statement;
      # the learner only needs PostgreSQL's own sentence.
      error.message.to_s.split("\n").first.to_s.sub(/\APG::\w+:\s*/, "").strip
    end

    def elapsed(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end

    def rejected(reason)
      Result.new(status: :rejected, columns: [], rows: [],
                 expected_rows: @expected_rows, message: reason)
    end
  end
end
