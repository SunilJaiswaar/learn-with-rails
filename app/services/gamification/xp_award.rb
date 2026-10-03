module Gamification
  # The single entry point for granting XP.
  #
  # Every award is written to an append-only ledger and the user's cached total
  # is derived from it, so XP can always be audited and recomputed. An
  # idempotency key makes re-submitting the same accomplishment a no-op rather
  # than a second payout.
  class XpAward
    Outcome = Struct.new(:transaction, :awarded, :levels_gained, :new_level,
                         :achievements, keyword_init: true) do
      def awarded?
        awarded.to_i != 0
      end

      def levelled_up?
        levels_gained.to_i.positive?
      end
    end

    def initialize(user:, amount:, reason:, source: nil, idempotency_key: nil, metadata: {})
      @user = user
      @amount = amount.to_i
      @reason = reason
      @source = source
      @idempotency_key = idempotency_key
      @metadata = metadata
    end

    def call
      return none if amount.zero?

      transaction = nil
      previous_level = user.level

      ActiveRecord::Base.transaction do
        # Locking serialises concurrent awards so two submissions cannot both
        # read a stale total and overwrite each other.
        user.lock!
        transaction = create_transaction
        recalculate_total! if transaction
      end

      # A duplicate key means this accomplishment was already paid out.
      return none if transaction.nil?

      achievements = AchievementEngine.new(user: user).call
      Outcome.new(transaction: transaction, awarded: amount,
                  levels_gained: user.level - previous_level,
                  new_level: user.level, achievements: achievements)
    end

    private

    attr_reader :user, :amount, :reason, :source, :idempotency_key, :metadata

    # Returns nil when this accomplishment has already been awarded. The model
    # validation catches the ordinary case; the unique index catches the race
    # between two concurrent requests.
    def create_transaction
      user.xp_transactions.create!(
        amount: amount, reason: reason, source: source,
        idempotency_key: idempotency_key, metadata: metadata
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    rescue ActiveRecord::RecordInvalid => e
      raise unless duplicate_key?(e.record)

      nil
    end

    def duplicate_key?(record)
      record.errors.where(:idempotency_key, :taken).any?
    end

    # The ledger is the source of truth; the column is a cache of its sum.
    def recalculate_total!
      total = [ user.xp_transactions.sum(:amount), 0 ].max
      user.update_columns(
        xp_total: total,
        level: LevelCurve.level_for(total),
        updated_at: Time.current
      )
      user.reload
    end

    def none
      Outcome.new(transaction: nil, awarded: 0, levels_gained: 0,
                  new_level: user.level, achievements: [])
    end
  end
end
