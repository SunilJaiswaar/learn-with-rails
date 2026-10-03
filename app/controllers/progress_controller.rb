# Graphical progress (spec 64) and interview readiness by category (spec 63).
class ProgressController < ApplicationController
  def show
    @readiness = Mastery::Report.new(user: current_user).call
    @skill_progresses = current_user.skill_progresses.includes(:skill)
                                    .order(Arel.sql("mastery_level DESC, updated_at DESC"))
    @xp_history = xp_by_day
    @accuracy_history = accuracy_by_week
    @totals = {
      challenges_solved: current_user.challenge_attempts.successful.distinct.count(:challenge_id),
      topics_completed: current_user.topic_completions.finished.count,
      interviews: current_user.interviews.where(status: :completed).count,
      bosses: current_user.boss_attempts.where(status: :won).distinct.count(:boss_battle_id),
      xp: current_user.xp_total
    }
  end

  private

  # Daily XP for the last 30 days, zero-filled so the chart has no gaps.
  def xp_by_day
    start = 29.days.ago.to_date
    sums = current_user.xp_transactions
                       .since(start.beginning_of_day)
                       .group(Arel.sql("DATE(created_at)"))
                       .sum(:amount)
    (start..Date.current).map do |day|
      { date: day, amount: sums[day].to_i }
    end
  end

  # Weekly accuracy over challenge attempts, so the learner can see change.
  def accuracy_by_week
    attempts = current_user.challenge_attempts
                           .where(created_at: 8.weeks.ago..)
                           .pluck(:created_at, :status)
    attempts.group_by { |created_at, _| created_at.to_date.beginning_of_week }
            .sort_by(&:first)
            .map do |week, rows|
              passed = rows.count { |_, status| status == "passed" }
              { week: week, accuracy: ((passed.to_f / rows.size) * 100).round, attempts: rows.size }
            end
  end
end
