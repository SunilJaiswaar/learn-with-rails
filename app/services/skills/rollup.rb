module Skills
  # Summarises a set of TreeBuilder nodes for a world, roadmap or technology.
  #
  # The three new Learn pages all need the same counts over different slices of
  # the same tree, so they share one builder and one rollup rather than each
  # issuing its own progress queries.
  class Rollup
    COMPLETE_STATES = %i[complete].freeze

    def initialize(nodes)
      @nodes = Array(nodes)
    end

    attr_reader :nodes

    def total
      nodes.size
    end

    def complete
      count_state(:complete)
    end

    def in_progress
      count_state(:in_progress)
    end

    def available
      count_state(:available)
    end

    def locked
      count_state(:locked)
    end

    # Deliberately counts *demonstrated* skills only, never pages visited, so
    # the number on a world card means the same thing as mastery elsewhere.
    def percent_complete
      return 0 if total.zero?

      ((complete.to_f / total) * 100).round
    end

    def started?
      complete.positive? || in_progress.positive?
    end

    def mission_count
      nodes.sum { |node| node.skill.topics.size }
    end

    # The node a learner should open next: the furthest-along unlocked skill
    # they have not finished, falling back to the first available one.
    def next_node
      nodes.find { |node| node.state == :in_progress } ||
        nodes.find { |node| node.state == :available }
    end

    def counts
      { complete: complete, in_progress: in_progress,
        available: available, locked: locked }
    end

    private

    def count_state(state)
      nodes.count { |node| node.state == state }
    end
  end
end
