include SeedDSL
# Phase 9: integrated boss battles and the final championship. These combine
# skills across worlds, which is what makes them a capstone rather than another
# mission — each stage is from a different discipline (spec 52, 81, 82).
puts "  Phase 9: capstone boss battles"

bosses = [
  { slug: "the-black-friday-outage", title: "Black Friday",
    boss_name: "Peak Traffic", skill: "query-performance", world: "database-dungeon",
    difficulty: :expert, xp_reward: 500,
    scenario: "11:40 on the busiest trading day of the year. Checkout p95 has " \
              "gone from 240ms to 9 seconds. Error rate is 4%. The database is " \
              "at 97% CPU, the Sidekiq retry set has 22,000 jobs in it, and " \
              "Redis was restarted twenty minutes ago by someone trying to " \
              "help.\n\n" \
              "Four stages: diagnose, choose the first action, fix the " \
              "amplification, then say what you would change permanently.",
    debrief: "The order of operations is the lesson. Stopping the " \
             "amplification comes before fixing the cause, because retries and " \
             "a cold cache keep the system down long after the original " \
             "trigger has passed. The permanent fixes — idempotency, backoff " \
             "with jitter, a circuit breaker, and a cache that degrades rather " \
             "than fails — are all things that make the *next* incident " \
             "shorter rather than preventing this one.",
    stages: [
      { "label" => "Diagnose", "kind" => "open",
        "prompt" => "Redis was restarted, so every cache key is gone. The " \
                    "database is at 97% CPU and the retry set is growing. " \
                    "Explain the causal chain in your own words.",
        "keywords" => [ "cache", "cold", "database", "retr", "amplif" ],
        "explanation" => "Correct: the cache restart sent all read traffic to " \
                         "the database, which saturated; slow responses caused " \
                         "timeouts; timeouts caused retries; retries added load " \
                         "to an already-saturated database. The restart was the " \
                         "trigger, the retries are why it has not recovered." },
      { "label" => "First action", "kind" => "choice",
        "prompt" => "What do you do first?",
        "options" => [
          "Add database read replicas",
          "Pause the retrying queue to stop the amplification",
          "Restart the application servers",
          "Roll back the last deploy"
        ],
        "answer" => "1",
        "explanation" => "Pausing the queue stops new load arriving at a " \
                         "saturated dependency, which is the only action that " \
                         "helps within seconds.",
        "wrong_hint" => "Two of these take many minutes to have any effect, " \
                        "and one is unrelated to the evidence. Which one " \
                        "reduces load right now?" },
      { "label" => "Stop the amplification", "kind" => "open",
        "prompt" => "The queue is paused and the database is recovering. " \
                    "Before you release 22,000 jobs, what must be true?",
        "keywords" => [ "idempot", "backoff", "jitter", "batch", "duplicate" ],
        "explanation" => "Exactly: the jobs must be idempotent, or releasing " \
                         "them risks duplicate charges and emails. Release them " \
                         "with backoff and jitter so they do not all arrive at " \
                         "once and cause a second outage." },
      { "label" => "Prevent the next one", "kind" => "open",
        "prompt" => "Name the changes you would make permanently, and say " \
                    "which one you would do first.",
        "keywords" => [ "circuit", "degrade", "idempot", "jitter", "warm", "cap" ],
        "explanation" => "Good: a cache read that falls back to the database " \
                         "instead of failing, a circuit breaker so a slow " \
                         "dependency fails fast, capped retries with jitter, " \
                         "and idempotent jobs. Idempotency first, because " \
                         "without it you cannot safely replay anything." }
    ] },

  { slug: "the-leaking-worker", title: "The Leaking Worker",
    boss_name: "Slow Creep", skill: "memory-model", world: "computer-city",
    difficulty: :hard, xp_reward: 400,
    scenario: "A background worker's memory grows by about 40MB an hour and is " \
              "OOM-killed roughly once a day. Restarting it fixes nothing for " \
              "long. The code has not changed in three weeks, but the data " \
              "volume has tripled.\n\n" \
              "Three stages: name the mechanism, pick the diagnostic, then fix " \
              "it properly.",
    debrief: "Ruby does not leak memory on its own — it retains what is still " \
             "reachable. That single reframing turns an unsolvable problem " \
             "into a search for the reference that is still held, and a heap " \
             "diff finds it far faster than reading code.",
    stages: [
      { "label" => "Name the mechanism", "kind" => "open",
        "prompt" => "Is this a memory leak? Explain what is actually happening " \
                    "in a garbage-collected runtime.",
        "keywords" => [ "retain", "reachable", "reference", "gc", "unbounded" ],
        "explanation" => "Right: GC frees anything unreachable, so growing " \
                         "memory means something is still holding a reference. " \
                         "It is retention, not a leak — and the thing retaining " \
                         "is usually unbounded." },
      { "label" => "Choose the diagnostic", "kind" => "choice",
        "prompt" => "What tells you where the memory is going, fastest?",
        "options" => [
          "Call GC.start more often",
          "Compare two heap dumps taken an hour apart",
          "Increase the container's memory limit",
          "Read the worker's code looking for loops"
        ],
        "answer" => "1",
        "explanation" => "A heap diff names the class that is accumulating, " \
                         "which points straight at the holder.",
        "wrong_hint" => "One of these hides the problem, one does nothing, and " \
                        "one is slow and unreliable. Which produces evidence?" },
      { "label" => "Fix it", "kind" => "open",
        "prompt" => "The diff shows a class-level hash used for memoisation, " \
                    "keyed by record id, that is never cleared. What do you do?",
        "keywords" => [ "bound", "evict", "lru", "ttl", "limit", "unbounded" ],
        "explanation" => "Correct: bound it with a size limit and eviction, or " \
                         "a TTL. If the key space is genuinely unbounded then " \
                         "memoisation is the wrong tool and the value should be " \
                         "recomputed or cached externally." }
    ] },

  { slug: "the-leaked-invoice", title: "The Leaked Invoice",
    boss_name: "Broken Authorisation", skill: "web-security",
    world: "security-fortress", difficulty: :expert, xp_reward: 450,
    scenario: "A customer emails to say they can see another company's " \
              "invoice by changing a number in the URL. While investigating " \
              "you also notice the profile form accepts a `role` parameter, " \
              "and a report endpoint interpolates a `sort` parameter straight " \
              "into an ORDER BY.\n\n" \
              "Four stages: rank the findings, fix the worst, fix the " \
              "injection, then make it not recur.",
    debrief: "Ranking by what an attacker gains is the senior skill here. " \
             "Reading one invoice is bad; becoming an admin is every invoice " \
             "plus everything else, so mass assignment outranks the IDOR even " \
             "though the IDOR is what the customer noticed. And the durable " \
             "fix for all three is the same shape: make the safe path the " \
             "default, and let a scanner fail the build when it is not taken.",
    stages: [
      { "label" => "Rank them", "kind" => "choice",
        "prompt" => "Which do you fix first?",
        "options" => [
          "The IDOR — a customer is actively affected",
          "The mass assignment — it allows privilege escalation",
          "The SQL injection — it is the most famous",
          "All three at once"
        ],
        "answer" => "1",
        "explanation" => "Privilege escalation dominates: an attacker who can " \
                         "make themselves an admin obtains everything the other " \
                         "two findings would give them, and more.",
        "wrong_hint" => "Rank by what the attacker gains, not by what was " \
                        "reported first or what is best known." },
      { "label" => "Fix the escalation", "kind" => "open",
        "prompt" => "How do you stop a user setting their own role, and how do " \
                    "you make that stick across the codebase?",
        "keywords" => [ "permit", "allow", "explicit", "exclude", "strong param" ],
        "explanation" => "Right: permit an explicit list of attributes with " \
                         "role excluded, so anything not named is dropped by " \
                         "default rather than requiring someone to remember to " \
                         "block it." },
      { "label" => "Fix the injection", "kind" => "open",
        "prompt" => "The sort parameter goes into ORDER BY. A bind parameter " \
                    "will not work here. Why, and what do you do instead?",
        "keywords" => [ "identifier", "allow", "list", "map", "whitelist", "column" ],
        "explanation" => "Exactly: a column name is an identifier, not a value, " \
                         "so it cannot be bound. Map the parameter through an " \
                         "allow-list of permitted columns and fall back to a " \
                         "default." },
      { "label" => "Make it not recur", "kind" => "open",
        "prompt" => "All three bugs are habits rather than one-off slips. What " \
                    "changes so the next one is caught before review?",
        "keywords" => [ "scope", "policy", "brakeman", "ci", "default", "test" ],
        "explanation" => "Good: scope lookups through the owner association so " \
                         "an unauthorised record is simply not found, put " \
                         "authorisation in policy objects so the rule has one " \
                         "home, and run a static scanner in CI so an " \
                         "interpolated query fails the build." }
    ] }
]

bosses.each do |attrs|
  skill_slug = attrs.delete(:skill)
  world_slug = attrs.delete(:world)
  BossBattle.find_or_create_by!(slug: attrs[:slug]) do |b|
    b.assign_attributes(attrs)
    b.skill = skill!(skill_slug)
    b.world = world!(world_slug)
  end
end

puts "  Phase 9: championship interview track"

# The final interview championship (spec 82): rounds across every world,
# at the deepest band, in production-incident pressure mode.
InterviewTemplate.find_or_create_by!(slug: "developer-championship") do |t|
  t.name = "Developer Championship"
  t.experience_band = :principal
  t.question_count = 12
  t.summary = "Twelve rounds across every world, at the deepest band. " \
              "Expect every claim to be probed. This is the final exam, and " \
              "it reports where you stand rather than whether you passed."
  t.round_specs = [
    { "name" => "Round 1 — Programming", "skills" => %w[ruby-basics ruby-collections ruby-blocks], "count" => 1 },
    { "name" => "Round 2 — Algorithms", "skills" => %w[algorithmic-thinking complexity sorting], "count" => 1 },
    { "name" => "Round 3 — Data structures", "skills" => %w[hash-maps arrays-strings searching], "count" => 1 },
    { "name" => "Round 4 — SQL", "skills" => %w[sql-basics sql-joins sql-aggregation], "count" => 2 },
    { "name" => "Round 5 — Databases", "skills" => %w[indexing query-performance], "count" => 1 },
    { "name" => "Round 6 — Redis & jobs", "skills" => %w[redis-caching background-jobs], "count" => 1 },
    { "name" => "Round 7 — Frontend", "skills" => %w[js-semantics event-loop dom-rendering], "count" => 1 },
    { "name" => "Round 8 — Testing", "skills" => %w[testing-rspec], "count" => 1 },
    { "name" => "Round 9 — Security", "skills" => %w[web-security], "count" => 1 },
    { "name" => "Round 10 — Architecture", "skills" => %w[oop-design design-patterns architecture], "count" => 1 },
    { "name" => "Round 11 — Distributed systems", "skills" => %w[distributed-systems concurrency], "count" => 1 },
    { "name" => "Round 12 — Production debugging", "types" => %w[debugging scenario optimization], "count" => 1 }
  ]
end

# A capstone quest that routes through the hardest content.
QuestTemplate.find_or_create_by!(slug: "championship-run") do |q|
  q.name = "Championship run"
  q.alert_label = "Final challenge"
  q.xp_reward = 600
  q.difficulty = 5
  q.skill = Skill.find_by(slug: "query-performance")
  q.briefing = "Everything you have learned, in one run.\n\n" \
               "Survive Black Friday, then defend your reasoning in the " \
               "Developer Championship interview. The incident rewards acting " \
               "in the right order; the interview rewards being able to say " \
               "why."
  q.step_specs = [
    { "label" => "Survive the Black Friday outage", "kind" => "boss",
      "target_type" => "BossBattle", "target_slug" => "the-black-friday-outage" },
    { "label" => "Fix the double-counted revenue query", "kind" => "challenge",
      "target_type" => "Challenge", "target_slug" => "optimize-join-duplicates" },
    { "label" => "Complete the Developer Championship interview", "kind" => "interview" }
  ]
end
