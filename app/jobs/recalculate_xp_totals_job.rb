# The XP ledger is the source of truth; `users.xp_total` is a cache of its sum.
# This job repairs any drift (for example after a manual ledger correction).
class RecalculateXpTotalsJob < ApplicationJob
  queue_as :low

  def perform(user_id: nil)
    scope = user_id ? User.where(id: user_id) : User.all

    scope.find_each(batch_size: 200) do |user|
      total = [ user.xp_transactions.sum(:amount), 0 ].max
      level = Gamification::LevelCurve.level_for(total)
      next if user.xp_total == total && user.level == level

      user.update_columns(xp_total: total, level: level, updated_at: Time.current)
    end
  end
end
