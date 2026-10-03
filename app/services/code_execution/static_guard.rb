module CodeExecution
  # Defence in depth only. The sandbox is the real control; this catches
  # obviously hostile submissions early so we do not even spawn a process,
  # and gives the learner a clear message instead of a confusing crash.
  #
  # It is deliberately NOT treated as a security boundary: a determined
  # bypass of these patterns still lands inside the sandbox.
  class StaticGuard
    FORBIDDEN = {
      /\b(?:system|exec|spawn|fork)\s*[\(\s'"]/ => "spawning processes",
      /`[^`]*`/ => "shell backticks",
      /%x[\{\(\[]/ => "shell execution",
      /\bProcess\s*\./ => "the Process API",
      /\bFile\s*\.\s*(?:write|delete|unlink|rename|chmod|chown|open)/ => "file mutation",
      /\bFileUtils\b/ => "FileUtils",
      /\bIO\s*\.\s*(?:popen|read|write|sysopen)/ => "raw IO",
      /\bDir\s*\.\s*(?:delete|rmdir|mkdir|chdir)/ => "directory mutation",
      /\brequire\s*['"](?:socket|net\/|open-uri|open3|fileutils|etc)/ => "network or system libraries",
      /\bENV\s*\[[^\]]*\]\s*=/ => "mutating the environment",
      /\bat_exit\b/ => "at_exit hooks",
      /\bObjectSpace\b/ => "ObjectSpace",
      /\bbinding\s*\.\s*(?:irb|local_variable_set)/ => "binding manipulation",
      /\b__END__\b/ => "__END__ sections",
      /\bTracePoint\b/ => "TracePoint",
      /\bRubyVM\b/ => "RubyVM internals"
    }.freeze

    MAX_LENGTH = 20_000

    Rejection = Struct.new(:reason, keyword_init: true)

    def initialize(code)
      @code = code.to_s
    end

    # Returns nil when the code may proceed, or a Rejection explaining why not.
    def call
      return Rejection.new(reason: "Submission is empty.") if @code.strip.empty?

      if @code.length > MAX_LENGTH
        return Rejection.new(reason: "Submission exceeds #{MAX_LENGTH} characters.")
      end

      FORBIDDEN.each do |pattern, description|
        next unless @code.match?(pattern)

        return Rejection.new(
          reason: "This challenge does not allow #{description}. " \
                  "Solve it with plain Ruby instead."
        )
      end

      nil
    end
  end
end
