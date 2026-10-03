module Gamification
  # Each rule turns a user into a countable measure. An achievement is earned
  # when the measure reaches its threshold.
  #
  # Rules reward demonstrated work, never clicking (spec 49, 69).
  module AchievementRules
    RULES = {
      "challenges_solved" => lambda { |user|
        user.challenge_attempts.successful.distinct.count(:challenge_id)
      },
      "debug_challenges_solved" => lambda { |user|
        user.challenge_attempts.successful
            .joins(:challenge).where(challenges: { challenge_type: :debug })
            .distinct.count(:challenge_id)
      },
      "optimize_challenges_solved" => lambda { |user|
        user.challenge_attempts.successful
            .joins(:challenge).where(challenges: { challenge_type: :optimize })
            .distinct.count(:challenge_id)
      },
      "topics_completed" => lambda { |user|
        user.topic_completions.finished.count
      },
      "skills_mastered" => lambda { |user|
        user.skill_progresses.where(mastery_level: %i[strong mastered]).count
      },
      "streak_days" => lambda { |user|
        user.streak&.current_length.to_i
      },
      "longest_streak" => lambda { |user|
        user.streak&.longest_length.to_i
      },
      "xp_total" => lambda { |user| user.xp_total },
      "level" => lambda { |user| user.level },
      "bosses_defeated" => lambda { |user|
        user.boss_attempts.where(status: :won).distinct.count(:boss_battle_id)
      },
      "interviews_completed" => lambda { |user|
        user.interviews.where(status: :completed).count
      },
      "quests_completed" => lambda { |user|
        user.quests.where(status: :completed).count
      },
      "no_hint_solves" => lambda { |user|
        # Challenges solved without ever revealing a hint for them.
        revealed = Hint.joins(:hint_reveals)
                       .where(hint_reveals: { user_id: user.id })
                       .select(:challenge_id)
        user.challenge_attempts.successful
            .where.not(challenge_id: revealed)
            .distinct.count(:challenge_id)
      },
      "predictions_correct" => lambda { |user|
        user.question_attempts.correct_only
            .joins(:question).where(questions: { question_type: "output_prediction" })
            .count
      }
    }.freeze

    def self.keys
      RULES.keys
    end

    def self.measure(key, user)
      rule = RULES[key.to_s]
      return 0 unless rule

      rule.call(user).to_i
    end
  end
end
