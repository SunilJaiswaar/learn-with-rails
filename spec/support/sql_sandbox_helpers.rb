# The SQL playground lives in the database rather than the repo, so the suite
# provisions it once up front.
#
# It has to happen in a `before(:suite)` hook: examples run inside a
# transaction on the application's connection, and the playground is queried
# over a *separate* connection as the restricted role. DDL created inside the
# example transaction would be invisible to that connection.
module SqlSandboxHelpers
  class << self
    def provision!
      @available = begin
        SqlExecution::SandboxSchema.provision!
        SqlExecution::Runner.reset_pool!
        true
      rescue StandardError => e
        warn "SQL playground unavailable: #{e.class}: #{e.message}"
        false
      end
    end

    def available?
      @available ||= false
    end
  end

  def sql_sandbox_available?
    SqlSandboxHelpers.available? && SqlExecution::Runner.available?
  end
end
