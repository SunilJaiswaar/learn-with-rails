module Learning
  # Tracks movement through a topic's blocks and records understanding when the
  # learner reaches the end.
  #
  # Reaching the end of a topic is worth a little XP and a little
  # *understanding* evidence only — never mastery (spec 65).
  class TopicProgress
    UNDERSTANDING_SCORE = 60

    def initialize(user:, topic:)
      @user = user
      @topic = topic
    end

    def record_block_seen!(index)
      completion = find_or_create
      seen = [ completion.blocks_seen, index.to_i + 1 ].max
      completion.update!(blocks_seen: seen)
      completion
    end

    def complete!
      completion = find_or_create
      return completion if completion.finished?

      completion.update!(completed_at: Time.current, blocks_seen: total_blocks)

      Gamification::XpAward.new(
        user: user, amount: topic.xp_award,
        reason: "Mission complete: #{topic.name}",
        source: topic, idempotency_key: "topic:#{topic.id}"
      ).call

      if topic.skill
        Mastery::Recorder.new(
          user: user, skill: topic.skill, dimension: :understanding,
          score: UNDERSTANDING_SCORE, correct: true
        ).call
      end

      Gamification::StreakTracker.new(user: user).record_activity!
      QuestProgress.new(user: user).sync!(target: topic, kind: "topic")
      completion
    end

    # Prediction blocks are graded: committing to an answer is the evidence.
    def record_prediction!(block:, choice:)
      correct = block.correct_option?(choice)
      amount = correct ? 20 : 0

      if correct
        Gamification::XpAward.new(
          user: user, amount: amount,
          reason: "Correct prediction: #{topic.name}",
          source: block, idempotency_key: "prediction:#{block.id}"
        ).call
      end

      if topic.skill
        Mastery::Recorder.new(
          user: user, skill: topic.skill, dimension: :prediction,
          score: correct ? 100 : 25, correct: correct
        ).call
      end

      { correct: correct, xp: amount, explanation: block.payload["explanation"] }
    end

    private

    attr_reader :user, :topic

    def total_blocks
      topic.lesson_blocks.count
    end

    def find_or_create
      TopicCompletion.find_or_create_by!(user: user, topic: topic)
    end
  end
end
