module Learning
  # Wrong concepts come back automatically on an expanding ladder (spec 47).
  class SpacedRepetition
    def initialize(user:)
      @user = user
    end

    # `correct` promotes the item up the ladder; a miss demotes it so it
    # returns sooner and more often.
    def record!(reviewable:, correct:, skill: nil)
      schedule = ReviewSchedule.find_or_initialize_by(
        user: user,
        reviewable_type: reviewable.class.name,
        reviewable_id: reviewable.id
      )

      if schedule.new_record?
        schedule.skill = skill || infer_skill(reviewable)
        schedule.interval_index = 0
        schedule.due_on = Date.current
        schedule.save!
      end

      correct ? schedule.promote! : schedule.demote!
      schedule
    end

    def due(limit: 10, on: Date.current)
      user.review_schedules.due(on).soonest.limit(limit)
    end

    def due_count(on: Date.current)
      user.review_schedules.due(on).count
    end

    private

    attr_reader :user

    def infer_skill(reviewable)
      return reviewable.skill if reviewable.respond_to?(:skill)

      nil
    end
  end
end
