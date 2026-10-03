class AchievementsController < ApplicationController
  def index
    @earned = current_user.user_achievements.includes(:achievement).recent
    earned_ids = @earned.map(&:achievement_id)
    @locked = Achievement.visible.where.not(id: earned_ids).ordered
    # Show how close the learner is to each locked achievement.
    @progress = @locked.index_with do |achievement|
      Gamification::AchievementRules.measure(achievement.rule_key, current_user)
    end
  end
end
