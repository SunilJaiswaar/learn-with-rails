module Skills
  # The skill tree must stay a DAG: a cycle would make unlock resolution
  # non-terminating. Checked before a dependency edge is persisted.
  class CycleDetector
    def initialize(skill_id:, prerequisite_id:)
      @skill_id = skill_id
      @prerequisite_id = prerequisite_id
    end

    # True when adding skill -> prerequisite would close a loop, i.e. the
    # proposed prerequisite already depends on the skill (transitively).
    def cycle?
      return true if skill_id == prerequisite_id

      reachable_prerequisites_of(prerequisite_id).include?(skill_id)
    end

    private

    attr_reader :skill_id, :prerequisite_id

    def reachable_prerequisites_of(start_id)
      edges = SkillDependency.pluck(:skill_id, :prerequisite_id)
                             .group_by(&:first)
                             .transform_values { |pairs| pairs.map(&:last) }

      visited = Set.new
      stack = [ start_id ]

      while (current = stack.pop)
        next if visited.include?(current)

        visited << current
        stack.concat(edges.fetch(current, []))
      end
      visited
    end
  end
end
