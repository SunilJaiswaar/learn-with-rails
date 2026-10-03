module CodeExecution
  # Resource budget for one sandboxed run.
  class Limits
    # CRuby 3.4 reserves a large virtual address space at startup, so an
    # RLIMIT_AS below this stops the interpreter booting at all rather than
    # limiting the learner's program. It is a floor, not a tuning choice.
    MIN_ADDRESS_SPACE = 512 * 1024 * 1024

    attr_reader :cpu_seconds, :address_space_bytes, :file_size_bytes,
                :max_processes, :wall_margin_seconds

    def initialize(cpu_seconds:, address_space_bytes:, file_size_bytes:,
                   max_processes:, wall_margin_seconds:)
      @cpu_seconds = cpu_seconds
      @address_space_bytes = [ address_space_bytes, MIN_ADDRESS_SPACE ].max
      @file_size_bytes = file_size_bytes
      @max_processes = max_processes
      @wall_margin_seconds = wall_margin_seconds
    end

    def self.for_challenge(challenge)
      new(
        cpu_seconds: [ (challenge.time_limit_ms / 1000.0).ceil, 1 ].max,
        address_space_bytes: challenge.memory_limit_mb * 1024 * 1024,
        file_size_bytes: 2 * 1024 * 1024,
        max_processes: 32,
        wall_margin_seconds: 5
      )
    end

    def self.default
      new(
        cpu_seconds: 5,
        address_space_bytes: MIN_ADDRESS_SPACE,
        file_size_bytes: 2 * 1024 * 1024,
        max_processes: 32,
        wall_margin_seconds: 5
      )
    end
  end
end
