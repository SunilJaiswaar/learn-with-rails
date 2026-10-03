module Gamification
  # Evaluates every achievement rule for a user and awards the ones newly met.
  class AchievementEngine
    def initialize(user:)
      @user = user
    end

    def call
      pending = Achievement.where.not(id: user.user_achievements.select(:achievement_id))
      return [] if pending.empty?

      # Measure each distinct rule once, not once per achievement.
      measures = pending.pluck(:rule_key).uniq.index_with do |key|
        AchievementRules.measure(key, user)
      end

      newly_earned = pending.select { |a| measures.fetch(a.rule_key, 0) >= a.threshold }
      newly_earned.filter_map { |achievement| award(achievement) }
    end

    private

    attr_reader :user

    def award(achievement)
      user.user_achievements.create!(achievement: achievement, awarded_at: Time.current)

      if achievement.xp_reward.positive?
        # Awarded directly to the ledger: routing back through XpAward would
        # re-enter the achievement engine.
        user.xp_transactions.create!(
          amount: achievement.xp_reward,
          reason: "Achievement: #{achievement.name}",
          source: achievement,
          idempotency_key: "achievement:#{achievement.id}"
        )
        total = user.xp_transactions.sum(:amount)
        user.update_columns(xp_total: total, level: LevelCurve.level_for(total),
                            updated_at: Time.current)
      end

      achievement
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
