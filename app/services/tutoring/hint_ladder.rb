module Tutoring
  # Hints are revealed one rung at a time and never start with the answer
  # (spec 55). Each reveal costs XP, so asking is a real decision.
  class HintLadder
    def initialize(user:, challenge:)
      @user = user
      @challenge = challenge
    end

    def revealed
      challenge.hints.where(id: revealed_ids)
    end

    def next_hint
      challenge.hints.ordered.find { |hint| !revealed_ids.include?(hint.id) }
    end

    def exhausted?
      next_hint.nil?
    end

    # Reveals the next rung and charges its XP penalty once.
    def reveal_next!
      hint = next_hint
      return nil if hint.nil?

      HintReveal.create!(user: user, hint: hint)
      @revealed_ids = nil

      if hint.xp_penalty.positive?
        Gamification::XpAward.new(
          user: user, amount: -hint.xp_penalty,
          reason: "Hint revealed: #{challenge.title}",
          source: hint, idempotency_key: "hint:#{hint.id}"
        ).call
      end

      hint
    rescue ActiveRecord::RecordNotUnique
      hint
    end

    def penalty_so_far
      challenge.hints.where(id: revealed_ids).sum(:xp_penalty)
    end

    private

    attr_reader :user, :challenge

    def revealed_ids
      @revealed_ids ||= HintReveal.where(user: user, hint_id: challenge.hints.select(:id))
                                  .pluck(:hint_id)
    end
  end
end
