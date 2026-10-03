module Skills
  # The single definition of "this prerequisite has been satisfied".
  #
  # The skill map and the gate both answer the same question, from different
  # data shapes: the map has every progress row preloaded, the gate has one
  # skill's prerequisites. They must never disagree about whether a skill is
  # open, so the rule lives here and both call it.
  module UnlockRule
    # A prerequisite counts as satisfied once it reaches developing mastery —
    # demonstrated ability, not pages opened (spec 50, 65).
    LEVELS = %w[developing strong mastered].freeze

    def self.satisfied?(progress)
      LEVELS.include?(progress&.mastery_level)
    end
  end
end
