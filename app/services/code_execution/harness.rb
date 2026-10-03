module CodeExecution
  # Stages the harness, the submission and the assertion manifest into a
  # throwaway working directory.
  class Harness
    FILENAME = "harness.rb"
    SOLUTION = "solution.rb"
    MANIFEST = "manifest.json"
    RESULT = "result.json"

    SOURCE = Rails.root.join("lib/sandbox/harness.rb")

    def initialize(workdir:, code:, tests:)
      @workdir = Pathname(workdir)
      @code = code
      @tests = tests
    end

    def stage!
      FileUtils.cp(SOURCE, workdir.join(FILENAME))
      workdir.join(SOLUTION).write(code)
      workdir.join(MANIFEST).write(JSON.generate(manifest))
      # The sandbox needs to write result.json into this directory.
      FileUtils.chmod(0o700, workdir)
      self
    end

    def result_payload
      path = workdir.join(RESULT)
      return nil unless path.exist?

      JSON.parse(path.read)
    rescue JSON::ParserError
      nil
    end

    private

    attr_reader :workdir, :code, :tests

    def manifest
      {
        "tests" => tests.map do |test|
          {
            "name" => test.name,
            "call_expression" => test.call_expression,
            "expected" => test.expected
          }
        end
      }
    end
  end
end
