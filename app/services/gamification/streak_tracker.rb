module Gamification
  # A day counts toward the streak only when the learner did something that
  # produced evidence, not merely opened the app.
  class StreakTracker
    def initialize(user:)
      @user = user
    end

    def record_activity!(today = nil)
      day = today || current_day
      streak = user.streak || user.create_streak!
      streak.register_activity!(day)
    end

    private

    attr_reader :user

    # Streaks are evaluated in the learner's own timezone so a late-night
    # session does not silently break the chain.
    def current_day
      Time.find_zone(user.timezone)&.today || Date.current
    rescue ArgumentError
      Date.current
    end
  end
end
