module Skills
  # Answers "may this learner start this skill?" for one skill.
  #
  # TreeBuilder answers the same question for every skill at once, which is
  # right for the map and wasteful for a single page view. This issues two
  # queries — the skill's prerequisites and that learner's progress on them —
  # so a controller can gate a request without building the whole tree.
  class Availability
    Result = Struct.new(:skill, :met, :missing, :staff, keyword_init: true) do
      def available?
        staff || missing.empty?
      end

      # True when the learner is being let through only because they are staff,
      # so the view can say so rather than implying they earned it.
      def staff_override?
        staff && missing.any?
      end

      def missing_skills
        missing.map(&:skill)
      end

      # The §50 offer: "learn the missing concepts in N minutes". Summed from
      # the missions' own estimates, so an empty skill honestly reports zero
      # rather than inventing a number.
      def estimated_minutes
        missing.sum { |entry| entry.estimated_minutes }
      end

      def next_missing
        missing.first
      end
    end

    Prerequisite = Struct.new(:skill, :progress, :estimated_minutes, keyword_init: true) do
      def satisfied?
        UnlockRule.satisfied?(progress)
      end

      def mastery_level
        progress&.mastery_level || "untested"
      end

      def composite
        progress&.composite_score.to_i
      end
    end

    def initialize(user:, skill:)
      @user = user
      @skill = skill
    end

    def call
      entries = prerequisites.map do |prerequisite|
        Prerequisite.new(
          skill: prerequisite,
          progress: progress_index[prerequisite.id],
          estimated_minutes: minutes_for(prerequisite)
        )
      end

      met, missing = entries.partition(&:satisfied?)
      Result.new(skill: @skill, met: met, missing: missing, staff: staff?)
    end

    private

    # Staff need to be able to review unpublished and locked content, so the
    # gate reports the override rather than pretending the skill is open.
    def staff?
      @user.present? && (@user.admin? || @user.author?)
    end

    def prerequisites
      @prerequisites ||= @skill.prerequisites.includes(:topics).ordered.to_a
    end

    def progress_index
      @progress_index ||=
        if @user.nil? || prerequisites.empty?
          {}
        else
          SkillProgress.where(user_id: @user.id, skill_id: prerequisites.map(&:id))
                       .index_by(&:skill_id)
        end
    end

    def minutes_for(prerequisite)
      prerequisite.topics.select(&:published?).sum { |topic| topic.estimated_minutes.to_i }
    end
  end
end
