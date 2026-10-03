module Learning
  # Turns measured performance into the next thing to do (spec 46).
  #
  # Priority order: overdue revision, then the weakest dimension of the weakest
  # unlocked skill, then the next unstarted topic on the learner's path.
  class AdaptiveEngine
    Recommendation = Struct.new(:kind, :title, :reason, :target, :path, keyword_init: true)

    def initialize(user:)
      @user = user
    end

    def call(limit: 4)
      (revision_recommendations + weakness_recommendations + progression_recommendations)
        .uniq { |r| [ r.kind, r.target&.id, r.target&.class&.name ] }
        .first(limit)
    end

    # The single most important next action, used by the dashboard hero.
    def next_action
      call(limit: 1).first
    end

    private

    attr_reader :user

    def revision_recommendations
      SpacedRepetition.new(user: user).due(limit: 2).filter_map do |schedule|
        target = schedule.reviewable
        next if target.nil?

        Recommendation.new(
          kind: :revision,
          title: "Revision due: #{describe(target)}",
          reason: "You last got this wrong. It is scheduled to come back today.",
          target: target,
          path: route_for(target)
        )
      end
    end

    def weakness_recommendations
      weakest = user.skill_progresses
                    .includes(:skill)
                    .where(mastery_level: %i[weak developing])
                    .sort_by(&:composite_score)
                    .first(2)

      weakest.filter_map do |progress|
        dimension = progress.weakest_dimension
        challenge = challenge_for(progress.skill, dimension)
        next if challenge.nil?

        Recommendation.new(
          kind: :weakness,
          title: challenge.title,
          reason: "Your #{dimension.to_s.humanize.downcase} score for " \
                  "#{progress.skill.name} is #{progress.public_send("#{dimension}_score")}%.",
          target: challenge,
          path: Rails.application.routes.url_helpers.challenge_path(challenge.slug)
        )
      end
    end

    def progression_recommendations
      topic = Skills::TreeBuilder.new(user: user).next_topic
      return [] if topic.nil?

      [ Recommendation.new(
        kind: :progression,
        title: topic.name,
        reason: "Next mission on your path.",
        target: topic,
        path: Rails.application.routes.url_helpers.topic_path(topic.slug)
      ) ]
    end

    # Pick a challenge that exercises the dimension the learner is weakest at.
    def challenge_for(skill, dimension)
      types = case dimension
      when :debugging then %i[debug]
      when :prediction then %i[predict trace]
      when :explanation then %i[explain compare]
      when :application then %i[production optimize]
      else %i[implement]
      end

      solved = user.challenge_attempts.successful.select(:challenge_id)
      Challenge.published.where(skill: skill, challenge_type: types)
               .where.not(id: solved)
               .order(:difficulty).first ||
        Challenge.published.where(skill: skill).where.not(id: solved).order(:difficulty).first
    end

    def describe(target)
      target.try(:title) || target.try(:name) || target.try(:body)&.truncate(60) ||
        target.class.name.humanize
    end

    def route_for(target)
      helpers = Rails.application.routes.url_helpers
      case target
      when Topic then helpers.topic_path(target.slug)
      when Challenge then helpers.challenge_path(target.slug)
      when Question then helpers.question_path(target)
      else helpers.dashboard_path
      end
    end
  end
end
