class DashboardController < ApplicationController
  def show
    @quest = Learning::QuestGenerator.new(user: current_user).call
    @recommendations = Learning::AdaptiveEngine.new(user: current_user).call(limit: 4)
    @next_action = @recommendations.first
    @skill_progresses = current_user.skill_progresses
                                    .includes(:skill)
                                    .order(Arel.sql("mastery_level DESC"))
                                    .limit(8)
    @weakest = Mastery::Report.new(user: current_user).weakest(limit: 2)
    @due_reviews = Learning::SpacedRepetition.new(user: current_user).due_count
    @recent_achievements = current_user.user_achievements
                                       .includes(:achievement).recent.limit(4)
    @recent_xp = current_user.xp_transactions.recent.limit(6)
    @streak = current_user.streak || current_user.create_streak!
  end
end
