module RedisVault
  # Checks a challenge's objectives against the vault's actual state.
  #
  # Every objective is evaluated and reported individually, so the learner
  # sees which part they have and which part they are missing rather than a
  # bare pass/fail. An unrecognised check fails closed: a typo in a challenge
  # definition must never read as satisfied.
  class Verifier
    Status = Struct.new(:label, :met, keyword_init: true) do
      def met?
        met
      end
    end

    Report = Struct.new(:challenge, :statuses, :passed, keyword_init: true) do
      def passed?
        passed
      end
    end

    def initialize(store:, events: [], limiter: {})
      @store = store || {}
      @events = Array(events)
      @limiter = limiter || {}
    end

    def call(challenge)
      statuses = challenge[:objectives].map do |objective|
        Status.new(label: objective[:label], met: met?(objective[:check]))
      end

      Report.new(challenge: challenge, statuses: statuses, passed: statuses.all?(&:met))
    end

    private

    def met?(check)
      return event_met?(check[:event]) if check.key?(:event)
      return @limiter["tokens"].to_i == check[:limiter_tokens] if check.key?(:limiter_tokens)
      return @limiter["blocked"].to_i.positive? if check.key?(:limiter_blocked)
      return key_met?(check) if check.key?(:key)

      false
    end

    def event_met?(token)
      @events.include?(token)
    end

    def key_met?(check)
      entry = @store[check[:key]]
      return false if entry.nil?

      return entry["type"] == check[:type] if check.key?(:type)
      return entry["value"].to_s == check[:value].to_s if check.key?(:value)
      return ttl_met?(entry, check[:ttl]) if check.key?(:ttl)
      return hash_met?(entry, check) if check.key?(:hash_field)
      return zset_size_met?(entry, check[:zset_min_members]) if check.key?(:zset_min_members)
      return zset_top_met?(entry, check[:zset_top]) if check.key?(:zset_top)

      false
    end

    def ttl_met?(entry, expectation)
      ttl = entry["ttl"].to_i
      case expectation
      when :finite  then ttl.positive?
      when :persist then ttl == -1
      else false
      end
    end

    def hash_met?(entry, check)
      return false unless entry["type"] == "hash"

      entry["value"][check[:hash_field]].to_s == check[:hash_value].to_s
    end

    def zset_size_met?(entry, minimum)
      return false unless entry["type"] == "zset"

      entry["value"].size >= minimum
    end

    def zset_top_met?(entry, expectation)
      return false unless entry["type"] == "zset"

      top = entry["value"].max_by { |item| item["score"].to_f }
      return false if top.nil?

      top["member"] == expectation["member"] &&
        top["score"].to_f == expectation["score"].to_f
    end
  end
end
