module SqlExecution
  # Rejects submissions that are not a single read-only query.
  #
  # As with the Ruby guard, this is not the security boundary: the restricted
  # role and the read-only transaction are. It exists so a learner gets a clear
  # message, and so obviously-wrong shapes never reach the database.
  class StaticGuard
    MAX_LENGTH = 4_000

    # Only a query may be submitted. Anything that writes, changes schema or
    # touches the server is refused by name so the message is specific.
    FORBIDDEN = {
      /\b(?:INSERT|UPDATE|DELETE|TRUNCATE|MERGE)\b/i => "statements that modify data",
      /\b(?:CREATE|ALTER|DROP|COMMENT)\b/i => "statements that change the schema",
      /\b(?:GRANT|REVOKE|SET\s+ROLE|RESET\s+ROLE)\b/i => "privilege changes",
      /\b(?:COPY|VACUUM|ANALYZE|CLUSTER|REINDEX|CHECKPOINT|LISTEN|NOTIFY)\b/i => "maintenance commands",
      /\bpg_(?:read_file|read_binary_file|ls_dir|stat_file|sleep|terminate_backend|cancel_backend)\b/i =>
        "server-side system functions",
      /\bdblink|postgres_fdw|lo_(?:import|export)\b/i => "external data access",
      /\bpg_catalog\.|information_schema\./i => "catalogue introspection",
      /\bCOMMIT\b|\bROLLBACK\b|\bBEGIN\b|\bSTART\s+TRANSACTION\b/i => "transaction control"
    }.freeze

    Rejection = Struct.new(:reason, keyword_init: true)

    def initialize(sql)
      @sql = sql.to_s
    end

    def call
      return reject("Your query is empty.") if stripped.empty?

      if @sql.length > MAX_LENGTH
        return reject("Queries are limited to #{MAX_LENGTH} characters.")
      end

      unless stripped.match?(/\A(?:WITH|SELECT|TABLE|EXPLAIN|VALUES)\b/i)
        return reject("Only a SELECT (or WITH ... SELECT) query can be submitted.")
      end

      if multiple_statements?
        return reject("Submit a single statement. Semicolons separating several " \
                      "statements are not allowed.")
      end

      FORBIDDEN.each do |pattern, description|
        next unless without_literals.match?(pattern)

        return reject("This challenge does not allow #{description}. " \
                      "Answer it with a read-only query.")
      end

      nil
    end

    private

    attr_reader :sql

    def stripped
      # Strip leading comments so `-- note\nSELECT 1` is recognised as a query.
      @stripped ||= @sql.gsub(%r{/\*.*?\*/}m, " ")
                        .gsub(/^\s*--.*$/, "")
                        .strip
    end

    # Keywords inside string literals are data, not commands, so they are
    # blanked before pattern matching to avoid false positives such as
    # WHERE product = 'update kit'.
    def without_literals
      @without_literals ||= stripped.gsub(/'(?:''|[^'])*'/, "''")
                                    .gsub(/"(?:""|[^"])*"/, '""')
    end

    def multiple_statements?
      # One optional trailing semicolon is fine; anything after it is not.
      without_literals.sub(/;\s*\z/, "").include?(";")
    end

    def reject(reason)
      Rejection.new(reason: reason)
    end
  end
end
