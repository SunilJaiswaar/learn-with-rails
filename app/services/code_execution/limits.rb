module CodeExecution
  # Resource budget for one run.
  Limits = Struct.new(
    :cpu_seconds,
    :address_space_bytes,
    :file_size_bytes,
    :max_processes,
    :wall_margin_seconds,
    keyword_init: true
  ) do
    # 512MB of address space is the floor at which CRuby 3.4 can still boot;
    # lower values fail at startup rather than limiting the learner's code.
    MIN_ADDRESS_SPACE = 512 * 1024 * 1024

    def self.for_challenge(challenge)
      new(
        cpu_seconds: [ (challenge.time_limit_ms / 1000.0).ceil, 1 ].max,
        address_space_bytes: [ challenge.memory_limit_mb * 1024 * 1024,
                               MIN_ADDRESS_SPACE ].max,
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
