module Admin
  class DashboardController < BaseController
    def show
      @counts = {
        "Learners" => User.where(role: :learner).count,
        "Missions" => Topic.count,
        "Challenges" => Challenge.count,
        "Interview questions" => Question.count,
        "Algorithms" => Algorithm.count,
        "Boss battles" => BossBattle.count,
        "Achievements" => Achievement.count
      }
      @analytics = Admin::Analytics.new.call
      @incomplete_topics = Topic.includes(:lessons, :challenges, :questions)
                                .reject(&:complete_content?)
                                .first(10)
      @recent_audits = AuditLog.includes(:actor).recent.limit(10)
    end
  end
end
