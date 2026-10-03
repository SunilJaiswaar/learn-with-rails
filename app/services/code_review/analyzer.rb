module CodeReview
  # Automated review of a submission (spec 56).
  #
  # Findings are heuristic and labelled as such: the point is to make the
  # learner look at complexity, security and structure, not to pretend to be a
  # compiler. Every finding carries the reason and a concrete suggestion.
  class Analyzer
    Finding = Struct.new(:category, :severity, :message, :suggestion, keyword_init: true) do
      def to_h
        { "category" => category, "severity" => severity,
          "message" => message, "suggestion" => suggestion }
      end
    end

    # Nesting depth of iteration is the cheapest honest proxy for complexity.
    LOOP_KEYWORDS = /\b(?:each|each_with_index|map|times|upto|downto|while|until|for)\b/

    def initialize(code:, challenge: nil)
      @code = code.to_s
      @challenge = challenge
    end

    def call
      findings = []
      findings.concat(complexity_findings)
      findings.concat(readability_findings)
      findings.concat(security_findings)
      findings.concat(idiom_findings)

      {
        "findings" => findings.map(&:to_h),
        "estimated_complexity" => estimated_complexity,
        "line_count" => lines.size,
        "summary" => summarise(findings)
      }
    end

    private

    attr_reader :code, :challenge

    def lines
      @lines ||= code.lines.map(&:rstrip).reject { |l| l.strip.empty? }
    end

    def code_without_comments
      @code_without_comments ||= code.lines.reject { |l| l.strip.start_with?("#") }.join
    end

    # Counts the maximum nesting of loop constructs by tracking block depth.
    def max_loop_nesting
      depth = 0
      max = 0
      code_without_comments.each_line do |line|
        stripped = line.strip
        opens = stripped.scan(LOOP_KEYWORDS).size
        if opens.positive? && stripped.match?(/\bdo\b|\{|\bwhile\b|\buntil\b|\bfor\b/)
          depth += opens
          max = [ max, depth ].max
        end
        closes = stripped.scan(/\b(?:end)\b|\}/).size
        depth = [ depth - closes, 0 ].max
      end
      max
    end

    def estimated_complexity
      case max_loop_nesting
      when 0 then "O(1) or O(n) — no nested iteration detected"
      when 1 then "O(n)"
      when 2 then "O(n^2)"
      else "O(n^#{max_loop_nesting}) or worse"
      end
    end

    def complexity_findings
      findings = []
      nesting = max_loop_nesting

      if nesting >= 2
        findings << Finding.new(
          category: "performance", severity: "warning",
          message: "Iteration is nested #{nesting} deep, which suggests " \
                   "#{estimated_complexity} behaviour.",
          suggestion: "Ask whether a hash lookup, a single pass with running " \
                      "state, or sorting first could remove a level."
        )
      end

      target = challenge&.metadata&.dig("target_complexity")
      if target.present? && nesting >= 2
        findings << Finding.new(
          category: "performance", severity: "important",
          message: "This challenge targets #{target}.",
          suggestion: "Your current shape is #{estimated_complexity}. " \
                      "Reach for #{target} before moving on."
        )
      end

      if code_without_comments.match?(/\.include\?\(/) && nesting >= 1
        findings << Finding.new(
          category: "performance", severity: "info",
          message: "`include?` inside a loop scans the collection each time.",
          suggestion: "A Set or Hash gives O(1) membership instead of O(n)."
        )
      end
      findings
    end

    def readability_findings
      findings = []
      long = lines.each_with_index.select { |line, _| line.length > 100 }
      if long.any?
        findings << Finding.new(
          category: "readability", severity: "info",
          message: "#{long.size} line(s) exceed 100 characters.",
          suggestion: "Break long expressions across lines or name the " \
                      "intermediate value."
        )
      end

      method_count = code_without_comments.scan(/^\s*def\s+/).size
      if method_count == 1 && lines.size > 25
        findings << Finding.new(
          category: "maintainability", severity: "warning",
          message: "One method carries #{lines.size} lines.",
          suggestion: "If you can name two steps inside it, those are two methods."
        )
      end

      single_letters = code_without_comments.scan(/\b([a-z])\s*=(?!=)/).flatten
                                           .reject { |v| %w[i j k n x y].include?(v) }
      if single_letters.uniq.size >= 2
        findings << Finding.new(
          category: "readability", severity: "info",
          message: "Single-letter variables: #{single_letters.uniq.join(', ')}.",
          suggestion: "Names are free. `total` beats `t` when you reread this."
        )
      end
      findings
    end

    def security_findings
      findings = []
      {
        /\beval\b/ => [ "`eval` executes arbitrary strings as code.",
                        "Parse the input instead of evaluating it." ],
        /Marshal\.load/ => [ "`Marshal.load` on untrusted data allows object injection.",
                             "Use JSON for data you did not produce." ],
        /\bsend\s*\(/ => [ "`send` with a dynamic name can call any method.",
                           "Use `public_send` with an allow-list of names." ]
      }.each do |pattern, (message, suggestion)|
        next unless code_without_comments.match?(pattern)

        findings << Finding.new(category: "security", severity: "important",
                                message: message, suggestion: suggestion)
      end
      findings
    end

    def idiom_findings
      findings = []
      if code_without_comments.match?(/for\s+\w+\s+in\s+/)
        findings << Finding.new(
          category: "idiom", severity: "info",
          message: "`for ... in` leaks its loop variable into the surrounding scope.",
          suggestion: "`each` keeps the variable scoped to the block."
        )
      end

      if code_without_comments.match?(/\.each\s*(?:do\s*\|[^|]*\|\s*|\{\s*\|[^|]*\|\s*)\w+\s*<</)
        findings << Finding.new(
          category: "idiom", severity: "info",
          message: "Building an array with `each` and `<<` is what `map` does.",
          suggestion: "`collection.map { ... }` states the intent directly."
        )
      end
      findings
    end

    def summarise(findings)
      return "No issues detected by the automated review." if findings.empty?

      by_severity = findings.group_by(&:severity)
      parts = %w[important warning info].filter_map do |level|
        count = by_severity[level]&.size
        "#{count} #{level}" if count
      end
      "Automated review: #{parts.join(', ')}. These are heuristics — read them, " \
        "then decide."
    end
  end
end
