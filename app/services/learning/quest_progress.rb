module Learning
  # Marks quest steps done as the learner produces the matching evidence, and
  # pays out once every step is complete.
  class QuestProgress
    def initialize(user:)
      @user = user
    end

    # Called after any activity that might satisfy a step.
    def sync!(target: nil, kind: nil)
      quest = user.quests.for_day(today_for_user).first
      return nil if quest.nil? || !quest.open_quest?

      quest.quest_steps.reject(&:completed).each do |step|
        step.complete! if satisfies?(step, target, kind)
      end

      complete_quest!(quest) if quest.reload.all_steps_complete?
      quest
    end

    private

    attr_reader :user

    def today_for_user
      Time.find_zone(user.timezone)&.today || Date.current
    rescue ArgumentError
      Date.current
    end

    def satisfies?(step, target, kind)
      return false if target.nil? && kind.nil?
      return true if kind.present? && step.kind == kind.to_s && step.target_id.nil?

      target.present? &&
        step.target_type == target.class.name &&
        step.target_id == target.id
    end

    def complete_quest!(quest)
      Gamification::XpAward.new(
        user: user,
        amount: quest.quest_template.xp_reward,
        reason: "Daily quest: #{quest.quest_template.name}",
        source: quest,
        idempotency_key: "quest:#{quest.id}"
      ).call

      quest.update!(status: :completed, completed_at: Time.current,
                    xp_awarded: quest.quest_template.xp_reward)
    end
  end
end
