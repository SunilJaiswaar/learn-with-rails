module SqlExecution
  # Provisions the SQL playground: a dedicated schema holding the fixture
  # dataset, plus a login role that can read *only* that schema.
  #
  # Learner SQL is executed as this role, so it cannot reach the application's
  # own tables (users, sessions, xp_transactions) even though they live in the
  # same database. The role is not a superuser, so server-side file functions
  # such as pg_read_file are unavailable to it too.
  #
  # Every step is idempotent: `provision!` can be re-run safely.
  class SandboxSchema
    SCHEMA = Fixtures::SCHEMA
    ROLE = "codequest_sql_runner".freeze

    class ProvisionError < StandardError; end

    class << self
      def password
        ENV.fetch("SQL_SANDBOX_PASSWORD", "codequest-sql-sandbox")
      end

      def provisioned?
        schema_exists? && role_exists? && tables_present?
      rescue ActiveRecord::StatementInvalid
        false
      end

      def provision!
        raise ProvisionError, "refusing to provision in production" if Rails.env.production? && !ENV["SQL_SANDBOX_ALLOW_PRODUCTION"]

        create_role!
        rebuild_schema!
        grant_read_only!
        true
      end

      # The table and column list shown alongside a SQL challenge. Read from
      # the live schema rather than hard-coded, so the reference a learner sees
      # can never drift from the data they are querying.
      def reference
        return [] unless schema_exists?

        rows = select_rows_with_binds(<<~SQL, [ SCHEMA ])
          SELECT table_name, column_name, data_type
          FROM information_schema.columns
          WHERE table_schema = $1
          ORDER BY table_name, ordinal_position
        SQL

        rows.group_by(&:first).map do |table, columns|
          {
            "table" => table,
            "columns" => columns.map { |(_t, name, type)| { "name" => name, "type" => short_type(type) } }
          }
        end.sort_by { |entry| Fixtures::TABLES.index(entry["table"]) || 99 }
      end

      def row_counts
        return {} unless schema_exists?

        connection = ActiveRecord::Base.connection

        Fixtures::TABLES.index_with do |table|
          # A table name is an identifier, so it cannot be a bind parameter.
          # It comes from the frozen TABLES list and is quoted as an identifier.
          qualified = "#{connection.quote_table_name(SCHEMA)}." \
                      "#{connection.quote_table_name(table)}"
          connection.select_value("SELECT count(*) FROM #{qualified}").to_i
        end
      end

      # Used by the specs and the rake task; leaves the role in place because
      # it is cluster-wide and may be shared with other databases.
      def teardown!
        execute("DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE")
      end

      private

      def connection
        ActiveRecord::Base.connection
      end

      def execute(sql)
        connection.execute(sql)
      end

      def quote(value)
        connection.quote(value)
      end

      def short_type(data_type)
        {
          "character varying" => "text", "text" => "text",
          "integer" => "int", "bigint" => "int",
          "numeric" => "numeric", "date" => "date",
          "timestamp without time zone" => "timestamp", "boolean" => "bool"
        }.fetch(data_type, data_type)
      end

      # Bind parameters are used throughout rather than interpolation, even
      # though these values are frozen constants: it keeps the queries provably
      # injection-free and avoids teaching the wrong pattern in a codebase whose
      # subject is SQL.
      def select_rows_with_binds(sql, binds)
        ActiveRecord::Base.connection.exec_query(sql, "sql_sandbox", binds).rows
      end

      def schema_exists?
        select_rows_with_binds(
          "SELECT 1 FROM information_schema.schemata WHERE schema_name = $1", [ SCHEMA ]
        ).any?
      end

      def role_exists?
        select_rows_with_binds(
          "SELECT 1 FROM pg_roles WHERE rolname = $1", [ ROLE ]
        ).any?
      end

      def tables_present?
        found = select_rows_with_binds(
          "SELECT table_name FROM information_schema.tables WHERE table_schema = $1",
          [ SCHEMA ]
        ).flatten
        (Fixtures::TABLES - found).empty?
      end

      # CREATE ROLE is not idempotent, hence the DO block.
      def create_role!
        execute(<<~SQL)
          DO $$
          BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '#{ROLE}') THEN
              CREATE ROLE #{ROLE} LOGIN PASSWORD #{quote(password)};
            ELSE
              ALTER ROLE #{ROLE} LOGIN PASSWORD #{quote(password)};
            END IF;
          END
          $$;
        SQL
      end

      def rebuild_schema!
        execute("DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE")
        execute("CREATE SCHEMA #{SCHEMA}")
        execute(Fixtures::DDL)
        execute(Fixtures::DATA)
      end

      def grant_read_only!
        database = connection.current_database

        execute("GRANT CONNECT ON DATABASE #{connection.quote_table_name(database)} TO #{ROLE}")
        execute("GRANT USAGE ON SCHEMA #{SCHEMA} TO #{ROLE}")
        execute("GRANT SELECT ON ALL TABLES IN SCHEMA #{SCHEMA} TO #{ROLE}")

        # Future tables in the schema are readable too, so adding a fixture
        # table does not silently become invisible to the runner.
        execute("ALTER DEFAULT PRIVILEGES IN SCHEMA #{SCHEMA} GRANT SELECT ON TABLES TO #{ROLE}")

        # Nothing outside the sandbox: no object creation anywhere, and the
        # application's own schema stays unreadable (table privileges are
        # owner-only by default, and this makes the intent explicit).
        execute("REVOKE ALL ON SCHEMA public FROM #{ROLE}")
        execute("REVOKE CREATE ON SCHEMA #{SCHEMA} FROM #{ROLE}")
      end
    end
  end
end
