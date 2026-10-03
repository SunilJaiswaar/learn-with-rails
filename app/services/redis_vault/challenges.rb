module RedisVault
  # Objectives for the Redis Vault.
  #
  # The vault had a working command interpreter and nothing to accomplish
  # with it, so there was no success to award and the lab could not record
  # evidence for the Redis skill. Each challenge below states a goal a
  # learner reaches by reasoning about Redis, and the checks are deliberately
  # about *how* as well as *what* — landing on a counter of 3 by SETting it
  # to 3 is not the lesson.
  module Challenges
    CHALLENGES = [
      {
        slug: "expiring-session",
        title: "Expire a session before it leaks",
        xp_reward: 120,
        brief: "Cache a checkout session at session:checkout, then give it a " \
               "10 minute expiry. SET alone leaves a key resident forever — " \
               "that is how a cache becomes a memory leak.",
        hint: "SET stores the key. TTL reads the expiry. EXPIRE sets it, in seconds.",
        objectives: [
          { label: "session:checkout holds a string", check: { key: "session:checkout", type: "string" } },
          { label: "it expires rather than persisting", check: { key: "session:checkout", ttl: :finite } },
          { label: "the expiry was set explicitly", check: { event: "EXPIRE:session:checkout" } }
        ]
      },
      {
        slug: "atomic-counter",
        title: "Count without losing a write",
        xp_reward: 140,
        brief: "Bring page:views:home to 3. Read-modify-write from two " \
               "processes loses increments; Redis has a single-command answer " \
               "that cannot interleave.",
        hint: "GET then SET is two round trips with a gap in between. INCR is one.",
        objectives: [
          { label: "page:views:home reads 3", check: { key: "page:views:home", value: "3" } },
          { label: "you incremented rather than assigned", check: { event: "INCR:page:views:home" } }
        ]
      },
      {
        slug: "weekly-leaderboard",
        title: "Rank players without sorting in Ruby",
        xp_reward: 160,
        brief: "Build leaderboard:weekly with at least three players, where " \
               "user:ace leads on 9000 points. A sorted set keeps the ranking " \
               "in Redis, so reading the top N never loads the whole table.",
        hint: "ZADD takes the score before the member: ZADD key 9000 user:ace",
        objectives: [
          { label: "leaderboard:weekly is a sorted set", check: { key: "leaderboard:weekly", type: "zset" } },
          { label: "it holds at least three players", check: { key: "leaderboard:weekly", zset_min_members: 3 } },
          { label: "user:ace leads on 9000", check: { key: "leaderboard:weekly", zset_top: { "member" => "user:ace", "score" => 9000.0 } } }
        ]
      },
      {
        slug: "wrongtype-recovery",
        title: "Read a WRONGTYPE error and recover",
        xp_reward: 150,
        brief: "A deploy wrote cart:9001 as a string; the new code wants a " \
               "hash. Reproduce the WRONGTYPE error, then make cart:9001 a " \
               "hash whose sku field is RB-204. Redis will not quietly " \
               "convert a key for you.",
        hint: "A key keeps the type it was created with. Remove it before writing a different type.",
        objectives: [
          { label: "you triggered a WRONGTYPE error", check: { event: "ERR:WRONGTYPE" } },
          { label: "cart:9001 is now a hash", check: { key: "cart:9001", type: "hash" } },
          { label: "its sku field reads RB-204", check: { key: "cart:9001", hash_field: "sku", hash_value: "RB-204" } }
        ]
      },
      {
        slug: "exhaust-the-bucket",
        title: "Drive a rate limiter into 429",
        xp_reward: 110,
        brief: "Spend every token in the bucket and see requests rejected. A " \
               "limiter that never returns 429 under load is not limiting " \
               "anything.",
        hint: "The bucket holds 10 tokens. Blast more requests than that.",
        objectives: [
          { label: "the bucket is empty", check: { limiter_tokens: 0 } },
          { label: "at least one request was rejected with 429", check: { limiter_blocked: :positive } }
        ]
      }
    ].freeze

    class << self
      def all
        CHALLENGES
      end

      def find(slug)
        CHALLENGES.find { |challenge| challenge[:slug] == slug.to_s }
      end

      def slugs
        CHALLENGES.map { |challenge| challenge[:slug] }
      end
    end
  end
end
