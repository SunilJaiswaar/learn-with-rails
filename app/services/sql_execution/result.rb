module SqlExecution
  # Outcome of running one learner query.
  Result = Struct.new(
    :status,        # :passed :failed :error :timed_out :rejected
    :columns,
    :rows,
    :expected_rows,
    :row_count,
    :runtime_ms,
    :message,
    :requirement_failures,
    keyword_init: true
  ) do
    def passed?
      status == :passed
    end

    def to_results_payload
      {
        "columns" => Array(columns),
        "rows" => Array(rows).first(PREVIEW_ROWS),
        "expected" => Array(expected_rows).first(PREVIEW_ROWS),
        "row_count" => row_count,
        "requirements" => Array(requirement_failures)
      }
    end

    PREVIEW_ROWS = 25
  end
end
