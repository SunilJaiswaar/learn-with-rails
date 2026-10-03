module Learning
  # Produces one daily mission per learner (spec 51), biased toward whatever
  # the adaptive engine says is weakest so the quest is never busywork.
  class QuestGenerator
    def initialize(user:, on: nil)
      @user = user
      @on = on || today_for_user
    end

    def call
      existing = user.quests.for_day(on).first
      return existing if existing

      template = pick_template
      return nil if template.nil?

      build_quest(template)
    rescue ActiveRecord::RecordNotUnique
      # Two requests raced; whichever landed first owns today's quest.
      user.quests.for_day(on).first
    end

    private

    attr_reader :user, :on

    def today_for_user
      Time.find_zone(user.timezone)&.today || Date.current
    rescue ArgumentError
      Date.current
    end

    # Prefer a template targeting a weak skill; otherwise rotate deterministically
    # so a learner does not get the same quest two days running.
    def pick_template
      candidates = QuestTemplate.active.to_a
      return nil if candidates.empty?

      weak_skill_ids = user.skill_progresses
                           .where(mastery_level: %i[weak developing])
                           .pluck(:skill_id)

      targeted = candidates.select { |t| weak_skill_ids.include?(t.skill_id) }
      pool = targeted.presence || candidates
      recent_ids = user.quests.order(scheduled_on: :desc).limit(3).pluck(:quest_template_id)
      fresh = pool.reject { |t| recent_ids.include?(t.id) }

      (fresh.presence || pool).min_by { |t| [ (t.id + on.to_time.to_i / 86_400) % pool.size, t.id ] }
    end

    def build_quest(template)
      Quest.transaction do
        quest = user.quests.create!(
          quest_template: template,
          scheduled_on: on,
          status: :open
        )

        template.steps.each_with_index do |spec, index|
          quest.quest_steps.create!(
            position: index,
            label: spec["label"].to_s,
            kind: spec.fetch("kind", "action"),
            target_type: spec["target_type"],
            target_id: resolve_target_id(spec)
          )
        end
        quest
      end
    end

    # Steps reference content by slug in the template so templates stay
    # portable across environments.
    def resolve_target_id(spec)
      return spec["target_id"] if spec["target_id"].present?

      slug = spec["target_slug"]
      return nil if slug.blank?

      case spec["target_type"]
      when "Challenge" then Challenge.find_by(slug: slug)&.id
      when "Topic" then Topic.find_by(slug: slug)&.id
      when "Question" then nil
      end
    end
  end
end
