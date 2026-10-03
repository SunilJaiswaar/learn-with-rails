module Mastery
  # Records one piece of evidence against a skill.
  #
  # Mastery is never granted for reading (spec 48, 65): each dimension moves
  # only when the learner demonstrates that specific ability, and the overall
  # level requires *every* weighted dimension to clear a bar.
  class Recorder
    # How strongly a single new observation pulls the running score. Low enough
    # that one lucky pass cannot mint mastery.
    LEARNING_RATE = 0.35

    MASTERY_THRESHOLDS = {
      mastered: { min_each: 70, composite: 85 },
      strong: { min_each: 55, composite: 70 },
      developing: { min_each: 30, composite: 45 },
      weak: { min_each: 0,  composite: 1 }
    }.freeze

    def initialize(user:, skill:, dimension:, score:, correct: nil)
      @user = user
      @skill = skill
      @dimension = dimension.to_sym
      @score = score.to_i.clamp(0, 100)
      @correct = correct.nil? ? score.to_i >= 70 : correct
    end

    def call
      return nil if user.nil? || skill.nil?
      unless SkillProgress::DIMENSIONS.include?(dimension)
        raise ArgumentError, "unknown mastery dimension: #{dimension}"
      end

      progress = SkillProgress.find_or_create_by!(user: user, skill: skill)
      progress.with_lock do
        apply_dimension(progress)
        progress.attempts_count += 1
        progress.correct_count += 1 if correct
        progress.last_practiced_at = Time.current
        progress.mastery_level = derive_level(progress)
        progress.mastered_at ||= Time.current if progress.mastery_level == "mastered"
        progress.save!
      end
      progress
    end

    private

    attr_reader :user, :skill, :dimension, :score, :correct

    # Exponential moving average, so recent evidence matters most but a single
    # result never defines the score.
    def apply_dimension(progress)
      attribute = "#{dimension}_score"
      current = progress.public_send(attribute).to_i
      blended = if progress.attempts_count.zero?
                  score
      else
                  (current + ((score - current) * LEARNING_RATE)).round
      end
      progress.public_send("#{attribute}=", blended.clamp(0, 100))
    end

    # A weak dimension holds the whole skill back: you cannot be "mastered" at
    # SQL joins if you have never debugged one.
    def derive_level(progress)
      scores = progress.dimension_scores.values
      composite = progress.composite_score
      lowest = scores.min.to_i

      MASTERY_THRESHOLDS.each do |level, bar|
        return level.to_s if lowest >= bar[:min_each] && composite >= bar[:composite]
      end
      "untested"
    end
  end
end
