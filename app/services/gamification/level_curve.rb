module Gamification
  # Levels cost progressively more XP so early momentum is fast and later
  # levels stay meaningful (spec 49).
  module LevelCurve
    BASE = 100
    GROWTH = 1.18
    MAX_LEVEL = 60

    TITLES = {
      1 => "Curious Beginner",
      3 => "Code Apprentice",
      6 => "Problem Solver",
      9 => "Junior Developer",
      12 => "Developer",
      15 => "Backend Builder",
      18 => "Frontend Builder",
      21 => "Full-Stack Developer",
      25 => "Production Engineer",
      30 => "Senior Engineer",
      36 => "System Designer",
      44 => "Software Architect",
      52 => "Principal Engineer"
    }.freeze

    class << self
      # Total XP required to *reach* the given level.
      def threshold_for(level)
        level = level.to_i
        return 0 if level <= 1
        return threshold_for(MAX_LEVEL) if level > MAX_LEVEL

        thresholds[level - 1]
      end

      def level_for(xp)
        xp = xp.to_i
        found = thresholds.rindex { |threshold| xp >= threshold }
        [ (found || 0) + 1, MAX_LEVEL ].min
      end

      def title_for(level)
        key = TITLES.keys.select { |k| k <= level.to_i }.max || 1
        TITLES.fetch(key)
      end

      private

      # Cumulative thresholds, memoised: index i holds the XP needed for level i+1.
      def thresholds
        @thresholds ||= begin
          total = 0
          (1..MAX_LEVEL).map do |level|
            total += (BASE * (GROWTH**(level - 1))).round if level > 1
            total
          end
        end
      end
    end
  end
end
