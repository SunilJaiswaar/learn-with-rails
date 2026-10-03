module CodeExecution
  # Normalised outcome of one sandboxed run.
  Result = Struct.new(
    :status,        # :passed :failed :error :timed_out :rejected
    :tests,         # array of per-test hashes
    :stdout,
    :stderr,
    :runtime_ms,
    :message,
    keyword_init: true
  ) do
    def passed?
      status == :passed
    end

    def tests_passed
      Array(tests).count { |t| t[:passed] }
    end

    def tests_total
      Array(tests).size
    end

    def to_results_payload
      { "tests" => Array(tests).map { |t| t.transform_keys(&:to_s) } }
    end
  end
end
