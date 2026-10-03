include SeedDSL
# Phase 3, part 2: Redis, Sidekiq and RSpec. Each skill is wired into the tree
# and points at the interactive lab that already exists for it.
puts "  Phase 3: Redis, Sidekiq, RSpec"

dungeon = World.find_by!(slug: "database-dungeon")
forest  = World.find_by!(slug: "programming-forest")

skills = [
  { slug: "redis-caching", name: "Redis & Caching", world: dungeon, tier: 4,
    position: 6, grid_x: 8, grid_y: 4,
    summary: "In-memory structures, TTL, and the hard part: invalidation.",
    prerequisites: %w[query-performance] },
  { slug: "background-jobs", name: "Background Jobs", world: dungeon, tier: 5,
    position: 1, grid_x: 8, grid_y: 5,
    summary: "Queues, retries, and why every job must be idempotent.",
    prerequisites: %w[redis-caching] },
  { slug: "testing-rspec", name: "Testing with RSpec", world: forest, tier: 2,
    position: 6, grid_x: 2, grid_y: 2,
    summary: "What to assert, what to double, and why flaky tests get deleted.",
    prerequisites: %w[ruby-blocks debugging-skill] }
]

skills.each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

redis_mod = curriculum_module!(
  world_slug: "database-dungeon", slug: "redis-module", position: 5,
  name: "Redis Vault", summary: "Memory is fast. Memory is also small and volatile."
)
jobs_mod = curriculum_module!(
  world_slug: "database-dungeon", slug: "jobs-module", position: 6,
  name: "Sidekiq Factory", summary: "Work that happens later, reliably."
)
test_mod = curriculum_module!(
  world_slug: "programming-forest", slug: "testing-module", position: 5,
  name: "Testing", summary: "Tests that fail for the right reason."
)

# ========================================================================= Redis
r1 = mission!(
  curriculum_module: redis_mod, slug: "cache-invalidation", position: 1,
  name: "The hard part is not caching", skill_slug: "redis-caching",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "Caching is easy: store the answer, return it next time. Then a price " \
        "changes and 40,000 users keep seeing the old one for an hour.",
  summary: "TTL, explicit invalidation, stampedes, and what Redis is not for.",
  blocks: [
    [ :prose, "Three ways to invalidate",
      { "body" => "**Expiry** (TTL): the entry dies after n seconds — simple, " \
                  "but stale until it does. **Explicit deletion** on write: " \
                  "fresh, but you must find every writer. **Key versioning**: " \
                  "include something that changes (an `updated_at`) in the key, " \
                  "so a write produces a different key and the old one just " \
                  "ages out." } ],
    [ :visual, "Which structure for which job",
      { "kind" => "growth_table",
        "sizes" => [ "Redis type", "typical use" ],
        "rows" => [
          { "label" => "Cached value", "values" => [ "String", "serialised JSON + TTL" ] },
          { "label" => "Counter", "values" => [ "String (INCR)", "rate limits, page views" ] },
          { "label" => "Leaderboard", "values" => [ "Sorted Set", "ZADD / ZREVRANGE" ] },
          { "label" => "Job queue", "values" => [ "List", "LPUSH / BRPOP — what Sidekiq uses" ] },
          { "label" => "Unique visitors", "values" => [ "Set / HyperLogLog", "SADD, or PFADD at scale" ] }
        ],
        "caption" => "Reaching for a String and JSON for everything is the most " \
                     "common Redis mistake." } ],
    [ :prediction, "The stampede",
      { "question" => "A cached homepage query takes 3 seconds to compute and " \
                      "has a 10-minute TTL. At expiry, 2,000 requests arrive " \
                      "in the same second. What happens?",
        "options" => [ "One recomputes, the rest wait for it",
                       "All 2,000 recompute simultaneously",
                       "Redis serves the expired value until one finishes",
                       "The requests queue in Redis" ],
        "answer" => 1,
        "explanation" => "All 2,000 miss, all 2,000 run the 3-second query, and " \
                         "the database falls over. This is a **cache stampede**. " \
                         "The fixes are a lock so only one recomputes, or " \
                         "recomputing slightly before expiry." } ],
    [ :interactive, "Open the Redis Vault",
      { "kind" => "algorithm_visualizer", "algorithm_slug" => "linear-search",
        "prompt" => "The Redis Vault lab lets you run commands against a " \
                    "simulated instance and watch memory and TTLs change.",
        "note" => "Try SET with EX, then watch the key expire. Then try INCR " \
                  "for a counter and ZADD for a leaderboard." } ],
    [ :code_demo, "Fetch-or-compute, and its sharp edges",
      { "code" => "# The common shape\nRails.cache.fetch(\"product/\#{id}\", expires_in: 10.minutes) do\n  expensive_lookup(id)\nend\n\n# Versioned key: a write changes the key, so no deletion is needed\nRails.cache.fetch(\"product/\#{id}/\#{product.updated_at.to_i}\") { ... }\n\n# Guard against a stampede: only one worker recomputes\nRails.cache.fetch(key, expires_in: 10.minutes, race_condition_ttl: 10.seconds) { ... }",
        "language" => "ruby",
        "annotations" => [
          "A versioned key never needs explicit invalidation — the old key just ages out.",
          "race_condition_ttl lets one caller recompute while others briefly " \
          "serve the stale value.",
          "Cache the *expensive* part, not the whole response, or you cache " \
          "per-user data by accident."
        ] } ],
    [ :pitfall, "Redis is not a database",
      { "body" => "It is memory-first: an eviction policy will delete your keys " \
                  "when memory fills, and a restart can lose recent writes " \
                  "depending on persistence settings. Anything you cannot " \
                  "recompute does not belong there alone." } ],
    [ :comparison, "Redis vs PostgreSQL",
      { "rows" => [
          { "aspect" => "Durability", "redis" => "Configurable, weaker", "pg" => "ACID" },
          { "aspect" => "Latency", "redis" => "Sub-millisecond", "pg" => "Milliseconds" },
          { "aspect" => "Size limit", "redis" => "Must fit in RAM", "pg" => "Disk" },
          { "aspect" => "Queries", "redis" => "By key, by structure", "pg" => "Arbitrary SQL" },
          { "aspect" => "Loss on eviction", "redis" => "Expected", "pg" => "Never" }
        ],
        "columns" => { "redis" => "Redis", "pg" => "PostgreSQL" } } ],
    [ :scenario, "In production",
      { "situation" => "Redis goes down at 09:00. The application returns 500s " \
                       "on every page, not just slow pages.",
        "question" => "What was wrong with the design?",
        "answer" => "The cache was a hard dependency rather than an optimisation. " \
                    "A cache read that raises should be rescued and fall through " \
                    "to the source of truth — slower, but serving. If sessions " \
                    "were also in Redis then every user was logged out too, " \
                    "which is a separate decision worth making deliberately." } ],
    [ :interview, "How this is asked",
      { "question" => "Redis is faster than PostgreSQL. Why not keep everything " \
                      "in Redis?",
        "good_answer" => "Because the speed comes from being in memory, and that " \
                         "is also the limitation: it must fit in RAM, eviction " \
                         "will discard keys under pressure, and durability is " \
                         "weaker than a relational database's. It is the right " \
                         "store for data you can recompute or afford to lose, " \
                         "and the wrong one for your system of record." } ],
    [ :revision, "Recall",
      { "prompt" => "Name the three invalidation strategies.",
        "answer" => "TTL expiry, explicit deletion on write, and key versioning." } ]
  ]
)

challenge!(
  slug: "cache-fetch-or-compute", title: "Fetch, or compute once",
  topic: r1, skill_slug: "redis-caching", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Implement `Cache#fetch(key)` taking a block.\n\n" \
          "Return the stored value if the key is present. Otherwise call the " \
          "block, store the result, and return it. The block must run **once " \
          "per key**, and a stored `nil` or `false` must still count as a hit — " \
          "that is the bug most implementations have.",
  starter: "class Cache\n" \
           "  def initialize\n" \
           "    @store = {}\n" \
           "  end\n\n" \
           "  def fetch(key)\n" \
           "    # Your code here\n" \
           "  end\n" \
           "end\n",
  solution: "class Cache\n" \
            "  def initialize\n" \
            "    @store = {}\n" \
            "  end\n\n" \
            "  def fetch(key)\n" \
            "    return @store[key] if @store.key?(key)\n" \
            "    @store[key] = yield\n" \
            "  end\n" \
            "end\n",
  explanation: "`@store[key] || yield` is the tempting version and it is wrong: " \
               "a cached `nil` or `false` is falsy, so the block runs again every " \
               "time and the \"cache\" never hits for those values. Asking " \
               "`key?` distinguishes \"absent\" from \"present but falsy\", which " \
               "is exactly why Rails' own cache has to handle this case.",
  tests: [
    [ "computes on a miss", "c = Cache.new; c.fetch(:a) { 1 }", "1" ],
    [ "returns the stored value on a hit",
      "c = Cache.new; c.fetch(:a) { 1 }; c.fetch(:a) { 2 }", "1" ],
    [ "runs the block once per key",
      "c = Cache.new; n = 0; 3.times { c.fetch(:a) { n += 1 } }; n", "1" ],
    [ "treats a stored nil as a hit",
      "c = Cache.new; n = 0; c.fetch(:a) { n += 1; nil }; c.fetch(:a) { n += 1; nil }; n", "1" ],
    [ "treats a stored false as a hit",
      "c = Cache.new; c.fetch(:a) { false }; c.fetch(:a) { true }", "false" ],
    [ "keeps keys independent",
      "c = Cache.new; [c.fetch(:a) { 1 }, c.fetch(:b) { 2 }]", "[1, 2]", true ]
  ],
  hints: [
    [ :nudge, "What happens if the computed value is `nil`?", 3 ],
    [ :concept, "`@store[key] || yield` cannot tell \"missing\" from " \
                "\"stored but falsy\".", 4 ],
    [ :solution, "Check `@store.key?(key)` rather than the value's truthiness.", 9 ]
  ]
)

challenge!(
  slug: "debug-cache-stampede", title: "Everyone recomputes at once",
  topic: r1, skill_slug: "redis-caching", type: :debug, difficulty: :hard, xp: 55,
  prompt: "`fetch_guarded` should let only the **first** caller compute a key " \
          "while it is in flight; later callers must wait and reuse that " \
          "result rather than recomputing.\n\n" \
          "It tracks in-flight keys but never consults the record, so every " \
          "caller still computes. Fix it so the block runs once per key.\n\n" \
          "(Single-threaded here; `@pending` stands in for a distributed lock.)",
  starter: "class Cache\n" \
           "  def initialize\n" \
           "    @store = {}\n" \
           "    @pending = {}\n" \
           "  end\n\n" \
           "  def fetch_guarded(key)\n" \
           "    return @store[key] if @store.key?(key)\n" \
           "    @pending[key] = true\n" \
           "    value = yield\n" \
           "    @store[key] = value\n" \
           "    value\n" \
           "  end\n" \
           "end\n",
  solution: "class Cache\n" \
            "  def initialize\n" \
            "    @store = {}\n" \
            "    @pending = {}\n" \
            "  end\n\n" \
            "  def fetch_guarded(key)\n" \
            "    return @store[key] if @store.key?(key)\n" \
            "    return @pending[key] if @pending.key?(key)\n" \
            "    @pending[key] = yield\n" \
            "    @store[key] = @pending.delete(key)\n" \
            "  end\n" \
            "end\n",
  explanation: "The original wrote to `@pending` and never read it, so the guard " \
               "did nothing — a lock you do not check is not a lock. Returning " \
               "the in-flight value means later callers reuse the first " \
               "computation. In a real system `@pending` is a Redis SETNX lock " \
               "with a TTL, and the same reasoning applies: take the lock, and " \
               "have everyone else respect it.",
  tests: [
    [ "computes once for repeated calls",
      "c = Cache.new; n = 0; 3.times { c.fetch_guarded(:a) { n += 1 } }; n", "1" ],
    [ "returns the computed value",
      "c = Cache.new; c.fetch_guarded(:a) { 7 }", "7" ],
    [ "serves later callers the first result",
      "c = Cache.new; c.fetch_guarded(:a) { 7 }; c.fetch_guarded(:a) { 9 }", "7" ],
    [ "keeps keys independent",
      "c = Cache.new; n = 0; c.fetch_guarded(:a) { n += 1 }; c.fetch_guarded(:b) { n += 1 }; n", "2" ],
    [ "clears the in-flight record once stored",
      "c = Cache.new; c.fetch_guarded(:a) { 1 }; c.instance_variable_get(:@pending)", "{}" ],
    [ "handles a nil result", "c = Cache.new; n = 0; 2.times { c.fetch_guarded(:a) { n += 1; nil } }; n",
      "1", true ]
  ],
  hints: [
    [ :nudge, "`@pending` is written but never read. What should a second " \
              "caller do with it?", 3 ],
    [ :concept, "A lock nobody checks is not a lock. Return the in-flight value " \
                "instead of computing again.", 5 ],
    [ :solution, "Add `return @pending[key] if @pending.key?(key)`, then move the " \
                 "value into `@store` and delete the pending entry.", 11 ]
  ]
)

question!(
  body: "Redis is faster than PostgreSQL. Why not store everything in Redis?",
  skill_slug: "redis-caching", type: "architecture", band: :mid, difficulty: :medium,
  topic: r1, company_type: "product",
  model: "The speed comes from being in memory, which is also the constraint: " \
         "the dataset must fit in RAM, eviction discards keys under memory " \
         "pressure, and durability is weaker than a relational database's. " \
         "Redis suits data you can recompute or afford to lose — caches, " \
         "counters, queues, sessions — and is the wrong choice for a system of " \
         "record.",
  mistakes: "Treating Redis as durable storage, or making a cache read a hard " \
            "dependency so an outage becomes a total outage.",
  answer_key: { "keywords" => [ "memory", "ram", "evict", "durab", "persist",
                                "recompute", "source of truth" ],
                "required" => [ "memory" ] },
  related: [ "eviction policies", "cache invalidation", "durability" ],
  follow_ups: [
    { body: "What happens to your application when Redis goes down?",
      trigger: "always",
      expects: [ "fall back", "rescue", "degrade", "slow", "source of truth" ],
      model: "It should degrade, not fail: a cache read that raises is rescued " \
             "and falls through to the database. If sessions live in Redis then " \
             "users are logged out, which is a trade worth deciding deliberately." },
    { body: "How would you handle cache invalidation for a frequently edited record?",
      trigger: "always",
      expects: [ "ttl", "delete", "version", "updated_at", "key" ],
      model: "Version the key with the record's `updated_at`, so a write produces " \
             "a new key and the old one ages out — no explicit deletion to forget." },
    { body: "You mentioned TTL. What is a cache stampede and how do you prevent it?",
      trigger: "keyword", keywords: [ "ttl", "expire", "expiry" ],
      expects: [ "stampede", "lock", "simultaneous", "thundering", "race" ],
      model: "When a popular key expires, every concurrent request misses and " \
             "recomputes at once, which can overwhelm the database. Prevent it " \
             "with a lock so only one recomputes, or by refreshing slightly " \
             "before expiry." }
  ]
)

# ====================================================================== Sidekiq
j1 = mission!(
  curriculum_module: jobs_mod, slug: "jobs-run-twice", position: 1,
  name: "Your job will run twice", skill_slug: "background-jobs",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "A worker charges a card, then the process is killed before it can " \
        "acknowledge the job. The queue, correctly, hands the job to another " \
        "worker. The customer is charged twice.",
  summary: "At-least-once delivery, idempotency, retries and poison jobs.",
  blocks: [
    [ :prose, "At-least-once, not exactly-once",
      { "body" => "Sidekiq fetches a job, runs it, then acknowledges. If the " \
                  "process dies between running and acknowledging, the job is " \
                  "retried — because the queue cannot tell \"finished but " \
                  "unacknowledged\" from \"never ran\". Exactly-once delivery is " \
                  "not something a queue can give you; **idempotent jobs** are " \
                  "how you get exactly-once *effects*." } ],
    [ :visual, "Where a job can die",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "fetch", "points_to" => "job leaves the queue" },
                     { "label" => "perform", "points_to" => "side effects happen here" },
                     { "label" => "acknowledge", "points_to" => "job is forgotten" } ],
        "objects" => [ { "id" => "job leaves the queue", "value" => "crash here: job is retried, safely" },
                       { "id" => "side effects happen here", "value" => "crash here: effects applied, job retried anyway" },
                       { "id" => "job is forgotten", "value" => "crash here: same as above" } ],
        "caption" => "The dangerous window is between the side effect and the " \
                     "acknowledgement. It cannot be closed — only made harmless." } ],
    [ :prediction, "Which job is safe to retry?",
      { "question" => "Which of these can be run twice with no visible harm?",
        "options" => [ "`user.increment!(:login_count)`",
                       "`user.update!(last_login_at: time)`",
                       "`Payment.create!(amount: 100)`",
                       "`mailer.welcome(user).deliver_now`" ],
        "answer" => 1,
        "explanation" => "Setting a field to a fixed value is idempotent: doing " \
                         "it twice leaves the same state. Incrementing, creating " \
                         "a row, and sending an email all produce a second effect. " \
                         "The usual fixes are a unique constraint, an " \
                         "idempotency key, or a guard that checks whether the " \
                         "work is already done." } ],
    [ :code_demo, "Making a job idempotent",
      { "code" => "# Not safe: a retry charges again\ndef perform(order_id)\n  order = Order.find(order_id)\n  Stripe::Charge.create(amount: order.total)\n  order.update!(status: \"paid\")\nend\n\n# Safe: the guard makes a second run a no-op\ndef perform(order_id)\n  order = Order.find(order_id)\n  return if order.paid?                 # already done\n\n  Stripe::Charge.create(\n    amount: order.total,\n    idempotency_key: \"order-\#{order.id}\"  # the provider dedupes too\n  )\n  order.update!(status: \"paid\")\nend",
        "language" => "ruby",
        "annotations" => [
          "The guard handles the retry; the idempotency key handles the case " \
          "where the charge succeeded but the status update did not.",
          "Pass ids, never objects: the record may have changed by the time the " \
          "job runs, and a serialised object will be stale.",
          "A unique database constraint is the most reliable guard of all — it " \
          "cannot be raced."
        ] } ],
    [ :pitfall, "The retry storm",
      { "body" => "A job that always fails and retries 25 times with backoff " \
                  "keeps a queue busy for weeks. Worse, a job that fails because " \
                  "a dependency is down will be joined by every other job " \
                  "failing for the same reason — thousands of retries hammering " \
                  "a service that is already struggling. Cap retries, and send " \
                  "permanent failures to the dead set rather than retrying " \
                  "forever." } ],
    [ :interactive, "Idempotent or not?",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these are safe to run twice?",
        "cases" => [
          { "sql" => "UPDATE users SET status = 'active' WHERE id = 1",
            "risk" => false, "why" => "Safe — same final state." },
          { "sql" => "UPDATE accounts SET balance = balance - 100",
            "risk" => true, "why" => "Not safe — relative change applied twice." },
          { "sql" => "INSERT with a unique constraint on an idempotency key",
            "risk" => false, "why" => "Safe — the second insert is rejected." },
          { "sql" => "Send a webhook to a third party",
            "risk" => true, "why" => "Not safe unless the receiver dedupes." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "10,000 jobs are stuck in the retry set. The queue is " \
                       "growing and the dashboard shows the same error on all " \
                       "of them: a timeout calling a third-party API.",
        "question" => "What do you do first, and what do you fix afterwards?",
        "answer" => "First stop the bleeding: pause or drain that queue so the " \
                    "retries stop hammering an already-failing dependency, " \
                    "rather than deleting jobs you may need. Then fix the cause " \
                    "— add a timeout and a circuit breaker so the call fails " \
                    "fast instead of occupying a worker, cap the retry count, " \
                    "and make the job idempotent so replaying the backlog is " \
                    "safe. Retry with jitter so the backlog does not all arrive " \
                    "at once." } ],
    [ :interview, "How this is asked",
      { "question" => "How do you make a background job safe to retry?",
        "good_answer" => "Assume at-least-once delivery and design for it: guard " \
                         "on whether the work is already done, use a unique " \
                         "constraint or idempotency key so a duplicate cannot " \
                         "take effect, and pass record ids rather than " \
                         "serialised objects. I would also bound retries so a " \
                         "permanently failing job lands in the dead set instead " \
                         "of retrying forever." } ],
    [ :revision, "Recall",
      { "prompt" => "Why can a queue not promise exactly-once delivery?",
        "answer" => "It cannot distinguish a job that finished but was not " \
                    "acknowledged from one that never ran, so it must retry." } ]
  ]
)

challenge!(
  slug: "idempotent-job", title: "Make the job safe to retry",
  topic: j1, skill_slug: "background-jobs", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Implement `ChargeJob#perform(order)` where `order` is a hash with " \
          "`:id`, `:total` and `:status`.\n\n" \
          "Charge the order by calling `charge!(order)` and set `:status` to " \
          "`\"paid\"`. Running it twice for the same order must charge **once** " \
          "— an already-paid order is a no-op.\n\n" \
          "Return `:charged` when you charged, `:skipped` when you did not.",
  starter: "class ChargeJob\n" \
           "  def perform(order)\n" \
           "    # Your code here\n" \
           "  end\n" \
           "end\n",
  solution: "class ChargeJob\n" \
            "  def perform(order)\n" \
            "    return :skipped if order[:status] == \"paid\"\n" \
            "    charge!(order)\n" \
            "    order[:status] = \"paid\"\n" \
            "    :charged\n" \
            "  end\n" \
            "end\n",
  explanation: "The guard is the whole idea: check whether the work is already " \
               "done before doing it. Note the ordering — charge first, then " \
               "mark paid. Reversed, a crash between the two would mark the " \
               "order paid without charging, which is a worse failure than " \
               "charging twice.",
  tests: [
    [ "charges an unpaid order",
      "$charges = 0; def charge!(o); $charges += 1; end; " \
      "ChargeJob.new.perform({id: 1, total: 10, status: 'pending'})", ":charged" ],
    [ "skips an already-paid order",
      "$charges = 0; def charge!(o); $charges += 1; end; " \
      "ChargeJob.new.perform({id: 1, total: 10, status: 'paid'})", ":skipped" ],
    [ "charges only once across two runs",
      "$charges = 0; def charge!(o); $charges += 1; end; " \
      "o = {id: 1, total: 10, status: 'pending'}; j = ChargeJob.new; " \
      "j.perform(o); j.perform(o); $charges", "1" ],
    [ "marks the order paid",
      "$charges = 0; def charge!(o); $charges += 1; end; " \
      "o = {id: 1, total: 10, status: 'pending'}; ChargeJob.new.perform(o); o[:status]",
      '"paid"' ],
    [ "does not charge an already-paid order at all",
      "$charges = 0; def charge!(o); $charges += 1; end; " \
      "ChargeJob.new.perform({id: 1, total: 10, status: 'paid'}); $charges", "0", true ]
  ],
  hints: [
    [ :nudge, "What should the job do if it notices the work is already done?", 2 ],
    [ :concept, "Guard on the current state before performing the side effect.", 4 ],
    [ :solution, "`return :skipped if order[:status] == \"paid\"`, then charge " \
                 "and set the status.", 9 ]
  ]
)

challenge!(
  slug: "debug-retry-backoff", title: "The retry storm",
  topic: j1, skill_slug: "background-jobs", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`retry_delays(attempts)` should return the backoff delay in seconds " \
          "before each retry, as exponential backoff: 1, 2, 4, 8, ... capped at " \
          "300 seconds, for the given number of attempts.\n\n" \
          "It returns a constant 1-second delay, so a failing job retries " \
          "immediately and forever — a retry storm. Fix it.",
  starter: "def retry_delays(attempts)\n" \
           "  (1..attempts).map { |n| 2 ** 0 }\n" \
           "end\n",
  solution: "def retry_delays(attempts)\n" \
            "  (1..attempts).map { |n| [2 ** (n - 1), 300].min }\n" \
            "end\n",
  explanation: "`2 ** 0` is 1 for every attempt — constant, not exponential. " \
               "`2 ** (n - 1)` gives 1, 2, 4, 8..., and the cap stops the delay " \
               "growing to hours. Backoff matters because the usual reason a job " \
               "fails is a dependency under strain, and retrying immediately " \
               "makes that worse.",
  tests: [
    [ "grows exponentially", "retry_delays(4)", "[1, 2, 4, 8]" ],
    [ "caps at 300 seconds", "retry_delays(12).last", "300" ],
    [ "returns one delay for one attempt", "retry_delays(1)", "[1]" ],
    [ "returns empty for zero attempts", "retry_delays(0)", "[]" ],
    [ "never exceeds the cap", "retry_delays(20).max", "300" ],
    [ "is non-decreasing", "d = retry_delays(10); d == d.sort", "true", true ]
  ],
  hints: [
    [ :nudge, "What is `2 ** 0`? Does it depend on `n` at all?", 2 ],
    [ :concept, "Exponential means the exponent grows with the attempt number.", 3 ],
    [ :solution, "`[2 ** (n - 1), 300].min`", 8 ]
  ]
)

question!(
  body: "10,000 Sidekiq jobs are stuck retrying with the same third-party " \
        "timeout. Walk me through handling it.",
  skill_slug: "background-jobs", type: "scenario", band: :senior, difficulty: :hard,
  topic: j1, company_type: "product",
  model: "Stop the bleeding first: pause or drain the affected queue so retries " \
         "stop hammering a dependency that is already failing, rather than " \
         "deleting jobs that may be needed. Then fix the cause — a timeout and " \
         "circuit breaker so the call fails fast instead of holding a worker, a " \
         "capped retry count so permanent failures reach the dead set, " \
         "idempotency so replaying the backlog is safe, and jitter so the " \
         "retries do not all arrive together.",
  mistakes: "Clearing the retry set without understanding what the jobs did, or " \
            "raising concurrency to 'get through them', which increases load on " \
            "the failing dependency.",
  answer_key: { "keywords" => [ "pause", "drain", "circuit", "timeout", "idempot",
                                "dead", "backoff", "jitter" ],
                "required" => [ "idempot" ] },
  related: [ "circuit breakers", "idempotency", "dead letter queues" ],
  follow_ups: [
    { body: "Why not just raise worker concurrency to clear the backlog faster?",
      trigger: "keyword", keywords: [ "concurrency", "workers", "scale", "faster" ],
      expects: [ "worse", "load", "dependency", "hammer" ],
      model: "Because the dependency is the bottleneck. More workers means more " \
             "concurrent calls to a service that is already timing out, which " \
             "makes recovery slower and can take it down entirely." },
    { body: "How do you know it is safe to replay the backlog?",
      trigger: "always",
      expects: [ "idempot", "guard", "unique", "duplicate" ],
      model: "Only if the jobs are idempotent. If they are not, replaying risks " \
             "duplicate charges or emails, and the jobs need a guard or a unique " \
             "constraint before the backlog is released." }
  ]
)

# ======================================================================== RSpec
t1 = mission!(
  curriculum_module: test_mod, slug: "what-to-assert", position: 1,
  name: "Tests that fail for the right reason", skill_slug: "testing-rspec",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "A suite with 2,000 passing tests that nobody trusts is worse than 200 " \
        "that fail loudly. The difference is what they assert.",
  summary: "Behaviour over implementation, doubles that lie, and flaky tests.",
  blocks: [
    [ :prose, "Assert behaviour, not implementation",
      { "body" => "A test that asserts *what* the code did survives refactoring. " \
                  "A test that asserts *how* it did it — which private method " \
                  "was called, in what order — breaks every time you improve " \
                  "the code, which teaches people to delete tests." } ],
    [ :visual, "What each test actually proves",
      { "kind" => "join_result",
        "result" => { "columns" => [ "assertion", "survives a refactor?", "proves the behaviour?" ],
                      "rows" => [
                        [ "expect(calc.total(100)).to eq(90)", "yes", "yes" ],
                        [ "expect(calc).to receive(:apply_rate)", "no", "no" ],
                        [ "expect(@rate).to eq(0.1)", "no", "no" ],
                        [ "expect(response).to have_http_status(:ok)", "yes", "partly" ]
                      ] },
        "caption" => "Only the first row is worth keeping unconditionally. The " \
                     "middle two assert how the code is written, so they break " \
                     "on every improvement — which is how suites lose trust." } ],
    [ :comparison, "The testing pyramid, and why",
      { "rows" => [
          { "aspect" => "Unit", "speed" => "Milliseconds", "confidence" => "Narrow",
            "when" => "Logic with branches and edge cases" },
          { "aspect" => "Request", "speed" => "Tens of ms", "confidence" => "Real stack",
            "when" => "Auth, params, status codes, serialisation" },
          { "aspect" => "System / browser", "speed" => "Seconds", "confidence" => "End to end",
            "when" => "A few critical journeys only" }
        ],
        "columns" => { "speed" => "Speed", "confidence" => "Confidence", "when" => "Use for" } } ],
    [ :prediction, "Which test is worth keeping?",
      { "question" => "Two tests for a discount calculator. Which gives more " \
                      "confidence?",
        "options" => [ "`expect(calc).to receive(:apply_rate)` then call it",
                       "`expect(calc.total(100)).to eq(90)`",
                       "`expect(calc.instance_variable_get(:@rate)).to eq(0.1)`",
                       "All three are equivalent" ],
        "answer" => 1,
        "explanation" => "Only the second asserts observable behaviour. The first " \
                         "passes even if `apply_rate` does nothing, and the third " \
                         "breaks the moment you rename a variable. A mock that " \
                         "asserts a call was made proves the call, not the result." } ],
    [ :code_demo, "A double that lies",
      { "code" => "# This passes forever, even after Gateway#charge is renamed.\ngateway = double(\"Gateway\", charge: true)\nexpect(gateway).to receive(:charge)\n\n# instance_double verifies the method actually exists on the real class\ngateway = instance_double(Gateway, charge: true)\n\n# Better still for pure logic: no double at all\nexpect(Discount.new(rate: 0.1).total(100)).to eq(90)",
        "language" => "ruby",
        "annotations" => [
          "A plain `double` will happily stub a method that no longer exists — " \
          "your test passes while production breaks.",
          "`instance_double` fails if the method is missing or the arity is wrong.",
          "Reach for a double at a boundary (network, clock, payment provider), " \
          "not for your own domain objects."
        ] } ],
    [ :pitfall, "Flaky tests are worse than no tests",
      { "body" => "A test that fails one run in twenty trains everyone to re-run " \
                  "CI instead of reading failures. The usual causes are order " \
                  "dependence (shared state between examples), real time " \
                  "(`Time.now` near a boundary), and unordered collections " \
                  "asserted as ordered. Fix or delete — never retry." } ],
    [ :interactive, "Double, or not?",
      { "kind" => "risk_spotter",
        "prompt" => "Where does a test double belong?",
        "cases" => [
          { "sql" => "A payment provider's HTTP API", "risk" => false,
            "why" => "Yes — a boundary you do not own and cannot call in tests." },
          { "sql" => "Your own Discount value object", "risk" => true,
            "why" => "No — use the real one. Doubling it tests your stub." },
          { "sql" => "The system clock in a date-boundary test", "risk" => false,
            "why" => "Yes — freeze time so the test is deterministic." },
          { "sql" => "The database in a model validation test", "risk" => true,
            "why" => "No — validations are cheap to test for real, and the " \
                     "double would hide schema drift." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A payment bug reaches production. The suite was green, " \
                       "and there is a test asserting " \
                       "`expect(gateway).to receive(:charge)`.",
        "question" => "Why did the test not catch it?",
        "answer" => "That test asserts the call was made, not that the charge " \
                    "was correct or that the response was handled. A mock " \
                    "returning `true` cannot tell you what happens when the " \
                    "provider returns a decline or times out. The gap is covered " \
                    "by asserting the resulting state for each response the " \
                    "provider can actually give — ideally with " \
                    "`instance_double` so a renamed method fails the test." } ],
    [ :interview, "How this is asked",
      { "question" => "When would you use a mock, and what is the risk?",
        "good_answer" => "At boundaries I do not own — HTTP APIs, the clock, " \
                         "payment providers — to keep tests fast and " \
                         "deterministic. The risk is that a mock encodes my " \
                         "assumption about that boundary, so the test passes " \
                         "while reality differs. I use verifying doubles so a " \
                         "signature change fails, and keep a small number of " \
                         "real end-to-end tests over the critical paths." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is asserting behaviour better than asserting implementation?",
        "answer" => "Behaviour assertions survive refactoring; implementation " \
                    "assertions break on every improvement and get deleted." } ]
  ]
)

challenge!(
  slug: "assert-behaviour", title: "Assert the outcome, not the call",
  topic: t1, skill_slug: "testing-rspec", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Write `Discount#total(amount)` returning the amount after discount, " \
          "rounded to 2 decimal places.\n\n" \
          "A discount is built with a `rate` between 0 and 1. A rate outside " \
          "that range must raise `ArgumentError` at construction — an invalid " \
          "object should never exist.",
  starter: "class Discount\n" \
           "  def initialize(rate:)\n" \
           "    # Your code here\n" \
           "  end\n\n" \
           "  def total(amount)\n" \
           "    # Your code here\n" \
           "  end\n" \
           "end\n",
  solution: "class Discount\n" \
            "  def initialize(rate:)\n" \
            "    raise ArgumentError, \"rate must be between 0 and 1\" unless (0..1).cover?(rate)\n" \
            "    @rate = rate\n" \
            "  end\n\n" \
            "  def total(amount)\n" \
            "    (amount * (1 - @rate)).to_f.round(2)\n" \
            "  end\n" \
            "end\n",
  explanation: "Validating in the constructor means every `Discount` that exists " \
               "is valid, so `total` needs no defensive checks. Note the `to_f`: " \
               "with an integer rate, `100 * (1 - 1)` is the Integer 0, so " \
               "without it the return type changes with the input — exactly the " \
               "kind of inconsistency a test asserting the observable result " \
               "catches and a mock never would.",
  tests: [
    [ "applies a 10% discount", "Discount.new(rate: 0.1).total(100)", "90.0" ],
    [ "applies no discount at rate 0", "Discount.new(rate: 0).total(100)", "100.0" ],
    [ "applies a full discount at rate 1", "Discount.new(rate: 1).total(100)", "0.0" ],
    [ "rounds to two places", "Discount.new(rate: 0.333).total(10)", "6.67" ],
    [ "rejects a rate above 1",
      "begin; Discount.new(rate: 1.5); rescue ArgumentError; 'raised'; end", '"raised"' ],
    [ "rejects a negative rate",
      "begin; Discount.new(rate: -0.1); rescue ArgumentError; 'raised'; end", '"raised"' ],
    [ "handles zero amount", "Discount.new(rate: 0.2).total(0)", "0.0", true ]
  ],
  hints: [
    [ :nudge, "Validate where the object is created, so it cannot exist in a " \
              "bad state.", 2 ],
    [ :concept, "`(0..1).cover?(rate)` checks the range; `round(2)` handles the " \
                "money formatting.", 4 ],
    [ :solution, "Raise ArgumentError in `initialize` unless the rate is in " \
                 "0..1, then `(amount * (1 - @rate)).round(2)`.", 9 ]
  ]
)

challenge!(
  slug: "debug-order-dependent-test", title: "The test that only fails second",
  topic: t1, skill_slug: "testing-rspec", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`Counter` is used by a test suite. `Counter.record(name)` tallies a " \
          "name and `Counter.tally_for(name)` reads it.\n\n" \
          "The counts leak between runs because the state is shared and never " \
          "reset — the in-memory equivalent of an order-dependent test. " \
          "Add `Counter.reset!` and make it work, without changing the other " \
          "two methods' behaviour.",
  starter: "class Counter\n" \
           "  @@counts = Hash.new(0)\n\n" \
           "  def self.record(name)\n" \
           "    @@counts[name] += 1\n" \
           "  end\n\n" \
           "  def self.tally_for(name)\n" \
           "    @@counts[name]\n" \
           "  end\n" \
           "end\n",
  solution: "class Counter\n" \
            "  @@counts = Hash.new(0)\n\n" \
            "  def self.record(name)\n" \
            "    @@counts[name] += 1\n" \
            "  end\n\n" \
            "  def self.tally_for(name)\n" \
            "    @@counts[name]\n" \
            "  end\n\n" \
            "  def self.reset!\n" \
            "    @@counts = Hash.new(0)\n" \
            "  end\n" \
            "end\n",
  explanation: "Shared mutable state is the most common cause of order-dependent " \
               "tests: example A passes alone, fails after example B. Replacing " \
               "the hash rather than clearing it also drops any default-proc " \
               "surprises. In a real suite this is what a `before` hook or " \
               "transactional fixtures do for you.",
  tests: [
    [ "records a count", "Counter.reset!; Counter.record(:a); Counter.tally_for(:a)", "1" ],
    [ "accumulates", "Counter.reset!; 3.times { Counter.record(:a) }; Counter.tally_for(:a)", "3" ],
    [ "reset clears everything",
      "Counter.record(:a); Counter.reset!; Counter.tally_for(:a)", "0" ],
    [ "unknown names are zero", "Counter.reset!; Counter.tally_for(:never)", "0" ],
    [ "keeps names independent",
      "Counter.reset!; Counter.record(:a); Counter.record(:b); " \
      "[Counter.tally_for(:a), Counter.tally_for(:b)]", "[1, 1]" ],
    [ "reset is idempotent",
      "Counter.reset!; Counter.reset!; Counter.tally_for(:a)", "0", true ]
  ],
  hints: [
    [ :nudge, "What makes one example's result depend on whether another ran " \
              "first?", 2 ],
    [ :concept, "Shared class-level state. A reset must restore it to its " \
                "initial condition, including the default.", 4 ],
    [ :solution, "`def self.reset!; @@counts = Hash.new(0); end`", 8 ]
  ]
)

question!(
  body: "Your suite is green but a payment bug reached production. There is a " \
        "test asserting the gateway received :charge. Why did it not catch it?",
  skill_slug: "testing-rspec", type: "scenario", band: :mid, difficulty: :hard,
  topic: t1,
  model: "That test asserts a call happened, not that the outcome was correct. " \
         "A double returning true cannot tell you what the code does when the " \
         "provider declines or times out, and a plain double will keep passing " \
         "even if the real method is renamed. The gap is covered by asserting " \
         "the resulting state for each response the provider can really give, " \
         "using a verifying double so signature drift fails the test.",
  mistakes: "Mocking your own domain objects, or treating a message expectation " \
            "as proof the behaviour is right.",
  answer_key: { "keywords" => [ "behaviour", "outcome", "state", "instance_double",
                                "verifying", "decline", "timeout" ],
                "required" => [ "outcome" ] },
  follow_ups: [
    { body: "What is the difference between `double` and `instance_double`?",
      trigger: "always",
      expects: [ "verif", "exist", "signature", "arity" ],
      model: "`instance_double` is a verifying double: it checks the stubbed " \
             "method exists on the real class with a compatible signature, so a " \
             "rename or arity change fails the test. A plain `double` will stub " \
             "anything." },
    { body: "How would you test the decline path without calling the real API?",
      trigger: "always",
      expects: [ "stub", "return", "raise", "assert state", "each response" ],
      model: "Stub the verifying double to return each response the provider can " \
             "produce — success, decline, timeout — and assert the order's " \
             "resulting state for each, rather than asserting the call." }
  ]
)
