module CodeExecution
  module Sandbox
    # Used when no isolation backend is available. It refuses to execute rather
    # than silently running learner code on the application server (spec 74).
    class Disabled < Base
      def self.available?
        true
      end

      def run(_script_name)
        Outcome.new(
          stdout: "",
          stderr: "No code execution sandbox is available on this host.",
          exit_status: nil,
          timed_out: false,
          runtime_ms: 0
        )
      end
    end
  end
end
