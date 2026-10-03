module Skills
  # Builds the skill tree for display and resolves what is unlocked.
  #
  # A skill unlocks when every prerequisite has reached at least "developing"
  # mastery, so the tree gates on demonstrated ability rather than on pages
  # viewed (spec 50, 65).
  class TreeBuilder
    # Kept as an alias so existing callers and specs keep working; the rule
    # itself now lives in UnlockRule so the gate cannot drift from the map.
    UNLOCK_LEVELS = UnlockRule::LEVELS

    Node = Struct.new(:skill, :progress, :state, :prerequisite_names, keyword_init: true) do
      def unlocked?
        state != :locked
      end

      def composite
        progress&.composite_score.to_i
      end

      def mastery_level
        progress&.mastery_level || "untested"
      end
    end

    def initialize(user:)
      @user = user
    end

    def nodes
      @nodes ||= begin
        skills = Skill.includes(:world, :technology, :topics, :prerequisites).ordered.to_a
        progresses = progress_index

        skills.map do |skill|
          Node.new(
            skill: skill,
            progress: progresses[skill.id],
            state: state_for(skill, progresses),
            prerequisite_names: skill.prerequisites.map(&:name)
          )
        end
      end
    end

    def nodes_by_world
      nodes.group_by { |node| node.skill.world }
           .sort_by { |world, _| world&.position || 99 }
    end

    def nodes_for_world(world)
      nodes.select { |node| node.skill.world_id == world.id }
    end

    def nodes_by_technology
      nodes.group_by { |node| node.skill.technology }
           .sort_by { |technology, _| technology&.position || 99 }
    end

    def nodes_for_technology(technology)
      nodes.select { |node| node.skill.technology_id == technology.id }
    end

    # Roadmap order is the path's own step order, which is not the tree's
    # order, so the steps drive the sequence and the tree supplies the state.
    def nodes_for_skill_ids(skill_ids)
      index = nodes.index_by { |node| node.skill.id }
      skill_ids.filter_map { |id| index[id] }
    end

    def unlocked_skills
      nodes.select(&:unlocked?).map(&:skill)
    end

    # Edges for drawing the tree, limited to pairs both present in the view.
    def edges
      ids = nodes.map { |n| n.skill.id }.to_set
      SkillDependency.where(skill_id: ids, prerequisite_id: ids)
                     .pluck(:prerequisite_id, :skill_id)
    end

    # The next mission to offer: first unfinished topic in an unlocked skill.
    def next_topic
      return nil if user.nil?

      completed = user.topic_completions.finished.select(:topic_id)
      Topic.published
           .where(skill: unlocked_skills)
           .where.not(id: completed)
           .joins(:curriculum_module)
           .order("topics.difficulty ASC, curriculum_modules.position ASC, topics.position ASC")
           .first
    end

    private

    attr_reader :user

    def progress_index
      return {} if user.nil?

      user.skill_progresses.index_by(&:skill_id)
    end

    def state_for(skill, progresses)
      progress = progresses[skill.id]
      return :in_progress if progress && progress.attempts_count.positive? &&
                             !UnlockRule.satisfied?(progress)
      return :complete if UnlockRule.satisfied?(progress)

      prerequisite_ids = skill.prerequisites.map(&:id)
      return :available if prerequisite_ids.empty?

      satisfied = prerequisite_ids.all? { |id| UnlockRule.satisfied?(progresses[id]) }
      satisfied ? :available : :locked
    end
  end
end
