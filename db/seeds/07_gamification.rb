include SeedDSL
puts "  achievements, quests, bosses, interview tracks"

# Achievements reward demonstrated work, never clicking (spec 49, 69).
achievements = [
  { slug: "first-blood", name: "First Blood", rule_key: "challenges_solved",
    threshold: 1, xp_reward: 25, tier: :bronze, icon: "⚑",
    description: "Solve your first coding challenge." },
  { slug: "ten-solved", name: "Getting Dangerous", rule_key: "challenges_solved",
    threshold: 10, xp_reward: 100, tier: :silver, icon: "⬢",
    description: "Solve 10 different challenges." },
  { slug: "bug-hunter", name: "Bug Hunter", rule_key: "debug_challenges_solved",
    threshold: 3, xp_reward: 120, tier: :silver, icon: "🐞",
    description: "Fix three broken programs. Debugging is the skill that " \
                 "transfers to every job." },
  { slug: "optimiser", name: "Optimiser", rule_key: "optimize_challenges_solved",
    threshold: 3, xp_reward: 150, tier: :gold, icon: "⚡",
    description: "Make three slow solutions fast." },
  { slug: "unaided", name: "No Hints Needed", rule_key: "no_hint_solves",
    threshold: 5, xp_reward: 160, tier: :gold, icon: "🔒",
    description: "Solve five challenges without revealing a single hint." },
  { slug: "week-streak", name: "Seven Days", rule_key: "streak_days",
    threshold: 7, xp_reward: 90, tier: :bronze, icon: "🔥",
    description: "Practise seven days in a row." },
  { slug: "month-streak", name: "Thirty Days", rule_key: "longest_streak",
    threshold: 30, xp_reward: 400, tier: :legendary, icon: "🔥",
    description: "Reach a thirty-day streak. Consistency beats intensity." },
  { slug: "first-mastery", name: "Genuinely Mastered", rule_key: "skills_mastered",
    threshold: 1, xp_reward: 200, tier: :gold, icon: "★",
    description: "Reach strong mastery in a skill — proven across prediction, " \
                 "implementation, debugging and explanation." },
  { slug: "boss-slayer", name: "Boss Slayer", rule_key: "bosses_defeated",
    threshold: 1, xp_reward: 150, tier: :silver, icon: "☠",
    description: "Defeat your first boss battle." },
  { slug: "interviewed", name: "In The Room", rule_key: "interviews_completed",
    threshold: 1, xp_reward: 80, tier: :bronze, icon: "◎",
    description: "Complete a full interview simulation." },
  { slug: "interview-regular", name: "Interview Fit",
    rule_key: "interviews_completed", threshold: 5, xp_reward: 250, tier: :gold,
    icon: "◎", description: "Complete five interview simulations." },
  { slug: "quest-runner", name: "On Call", rule_key: "quests_completed",
    threshold: 5, xp_reward: 180, tier: :silver, icon: "🚨",
    description: "Complete five daily missions." },
  { slug: "level-ten", name: "Double Digits", rule_key: "level",
    threshold: 10, xp_reward: 120, tier: :silver, icon: "▲",
    description: "Reach level 10." },
  { slug: "ten-missions", name: "Explorer", rule_key: "topics_completed",
    threshold: 10, xp_reward: 100, tier: :bronze, icon: "✦",
    description: "Finish ten missions." }
]
achievements.each do |attrs|
  Achievement.find_or_create_by!(slug: attrs[:slug]) { |a| a.assign_attributes(attrs) }
end

# Daily quests are framed as production alerts (spec 51).
quests = [
  { slug: "database-cpu-alert", name: "Database CPU at 95%",
    alert_label: "Production database alert", xp_reward: 350, difficulty: 3,
    skill: "query-performance",
    briefing: "PagerDuty woke you at 02:14. The primary database is at 95% CPU " \
              "and the API is timing out. One report query is responsible.\n\n" \
              "Find it, explain the plan, fix it, and prove the fix.",
    step_specs: [
      { "label" => "Read the join duplication mission", "kind" => "topic",
        "target_type" => "Topic", "target_slug" => "join-duplicates" },
      { "label" => "Fix the double-counted revenue query", "kind" => "challenge",
        "target_type" => "Challenge", "target_slug" => "optimize-join-duplicates" },
      { "label" => "Explain the cause in an interview answer", "kind" => "question" }
    ] },
  { slug: "slow-endpoint", name: "The endpoint that takes 8 seconds",
    alert_label: "Latency alert", xp_reward: 320, difficulty: 3,
    skill: "complexity",
    briefing: "A single endpoint has gone from 200ms to 8 seconds. Traffic is " \
              "flat. The code shipped last week added a nested loop.\n\n" \
              "Diagnose the complexity, then remove a level.",
    step_specs: [
      { "label" => "Work through why Big-O matters at scale", "kind" => "topic",
        "target_type" => "Topic", "target_slug" => "why-big-o" },
      { "label" => "Rewrite the O(n^2) lookup as O(n)", "kind" => "challenge",
        "target_type" => "Challenge", "target_slug" => "two-sum-optimised" }
    ] },
  { slug: "search-hangs", name: "The search that never returns",
    alert_label: "Incident", xp_reward: 300, difficulty: 2, skill: "searching",
    briefing: "A worker process is pinned at 100% CPU and never finishes. " \
              "The last deploy touched the lookup helper.\n\n" \
              "Find the infinite loop and prove your fix with the edge cases.",
    step_specs: [
      { "label" => "Study the binary search invariants", "kind" => "topic",
        "target_type" => "Topic", "target_slug" => "binary-search" },
      { "label" => "Fix the hanging search", "kind" => "challenge",
        "target_type" => "Challenge", "target_slug" => "debug-binary-search" }
    ] },
  { slug: "data-leak-between-requests", name: "Users see each other's data",
    alert_label: "Security incident", xp_reward: 380, difficulty: 4,
    skill: "ruby-collections",
    briefing: "Support has three reports of users seeing another account's " \
              "values in an API response. Nothing in the request handling looks " \
              "wrong.\n\nFind the shared mutable state.",
    step_specs: [
      { "label" => "Review reference semantics", "kind" => "topic",
        "target_type" => "Topic", "target_slug" => "variables-are-labels" },
      { "label" => "Fix the shared default collection", "kind" => "challenge",
        "target_type" => "Challenge", "target_slug" => "debug-shared-default" }
    ] }
]
quests.each do |attrs|
  skill_slug = attrs.delete(:skill)
  QuestTemplate.find_or_create_by!(slug: attrs[:slug]) do |q|
    q.assign_attributes(attrs)
    q.skill = skill!(skill_slug)
  end
end

# Boss battles mix disciplines, so one memorised trick is not enough (spec 52).
bosses = [
  { slug: "the-double-counter", title: "The Double Counter",
    boss_name: "Phantom Revenue", skill: "sql-joins", world: "database-dungeon",
    difficulty: :hard, xp_reward: 250,
    scenario: "Finance says last quarter's revenue report is 1.8x too high. " \
              "The orders table is correct. The payments table is correct. " \
              "The report is wrong.\n\n" \
              "Three stages: diagnose, choose the fix, then justify it.",
    debrief: "Row multiplication is the mechanism behind most inflated reports. " \
             "The habit worth keeping: whenever you add a join to a query that " \
             "aggregates, check COUNT(*) before and after.",
    stages: [
      { "label" => "Diagnose", "kind" => "open",
        "prompt" => "The report joins orders to order_items and to shipments, " \
                    "then takes SUM(orders.total). Explain in your own words why " \
                    "the total is inflated.",
        "keywords" => [ "duplicate", "one-to-many", "row", "multipl" ],
        "explanation" => "Correct: each join fans the order row out once per child " \
                         "row, so orders.total is summed once per combination of " \
                         "item and shipment." },
      { "label" => "Choose the fix", "kind" => "choice",
        "prompt" => "Which fix is correct in general?",
        "options" => [
          "Add SELECT DISTINCT to the query",
          "Use SUM(DISTINCT orders.total)",
          "Aggregate order_items and shipments in CTEs, then join those",
          "Divide the result by the number of items"
        ],
        "answer" => "2",
        "explanation" => "Aggregating each child table to one row per order before " \
                         "joining removes the fan-out entirely.",
        "wrong_hint" => "Two of these happen to work on sample data but break when " \
                        "two orders share a total. One is arithmetic coincidence." },
      { "label" => "Justify it", "kind" => "open",
        "prompt" => "Your colleague asks why not just use SUM(DISTINCT total). " \
                    "Answer them.",
        "keywords" => [ "two orders", "same", "equal", "collapse", "undercount" ],
        "explanation" => "Exactly: DISTINCT deduplicates values, not rows, so two " \
                         "genuinely different orders of £250 collapse into one and " \
                         "the total is now too low." }
    ] },

  { slug: "the-infinite-loop", title: "The Infinite Loop",
    boss_name: "The Spinner", skill: "searching", world: "algorithm-arena",
    difficulty: :medium, xp_reward: 220,
    scenario: "A worker is pinned at 100% CPU and never completes. " \
              "The deploy that caused it touched one function: a binary search.\n\n" \
              "Diagnose the invariant that was broken.",
    debrief: "Every loop has an invariant that guarantees progress. " \
             "When a loop hangs, find the variable that was supposed to change and " \
             "prove it actually does on every path.",
    stages: [
      { "label" => "Find the mechanism", "kind" => "open",
        "prompt" => "The loop is `while low < high` and the branches assign " \
                    "`low = mid` and `high = mid`. Explain precisely when this " \
                    "stops making progress.",
        "keywords" => [ "mid", "low", "same", "shrink", "progress", "two" ],
        "explanation" => "With two elements left, mid == low, so `low = mid` " \
                         "changes nothing and the window never shrinks." },
      { "label" => "Pick the correct invariant", "kind" => "choice",
        "prompt" => "`high` is an inclusive bound. Which loop condition and " \
                    "updates are correct?",
        "options" => [
          "while low < high, low = mid, high = mid",
          "while low <= high, low = mid + 1, high = mid - 1",
          "while low <= high, low = mid, high = mid",
          "while low < high, low = mid + 1, high = mid"
        ],
        "answer" => "1",
        "explanation" => "With an inclusive upper bound you must test low <= high, " \
                         "and both bounds must move past mid to guarantee progress.",
        "wrong_hint" => "Check two things: does the loop still run when one " \
                        "candidate remains, and does the window always shrink?" },
      { "label" => "Prove it", "kind" => "open",
        "prompt" => "Which test cases would catch both of the original bugs?",
        "keywords" => [ "two", "single", "last", "empty", "boundary", "first" ],
        "explanation" => "A two-element array catches the hang, and searching for " \
                         "the first and last elements catches the missed boundary. " \
                         "Empty input is worth asserting too." }
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

# Interview tracks. These are interview-PATTERN categories, never any company's
# real proprietary questions (spec 42).
templates = [
  { slug: "junior-backend-screen", name: "Junior Backend Screen",
    experience_band: :junior, question_count: 5, company_type: "product",
    summary: "A first technical screen: fundamentals, with follow-ups that check " \
             "you understand rather than remember.",
    round_specs: [
      { "name" => "Language fundamentals", "skills" => %w[ruby-basics ruby-collections], "count" => 2 },
      { "name" => "SQL", "skills" => %w[sql-joins], "count" => 1 },
      { "name" => "Problem solving", "skills" => %w[complexity hash-maps], "count" => 2 }
    ] },
  { slug: "mid-level-full-loop", name: "Mid-Level Technical Loop",
    experience_band: :mid, question_count: 7,
    summary: "Depth on data access and complexity, plus a debugging scenario.",
    round_specs: [
      { "name" => "Ruby & collections", "skills" => %w[ruby-blocks ruby-collections], "count" => 2 },
      { "name" => "SQL & data", "skills" => %w[sql-joins sql-aggregation], "count" => 2 },
      { "name" => "Algorithms", "skills" => %w[complexity searching hash-maps], "count" => 2 },
      { "name" => "Debugging", "types" => %w[debugging], "count" => 1 }
    ] },
  { slug: "senior-performance-deep-dive", name: "Senior Performance Deep Dive",
    experience_band: :senior, question_count: 6, company_type: "product",
    summary: "Scale, trade-offs and how you investigate. Expect to be pushed on " \
             "every claim you make.",
    round_specs: [
      { "name" => "Complexity at scale", "skills" => %w[complexity hash-maps], "count" => 2 },
      { "name" => "Query performance", "skills" => %w[sql-joins query-performance indexing], "count" => 2 },
      { "name" => "Production debugging", "types" => %w[debugging scenario optimization], "count" => 2 }
    ] },
  { slug: "fintech-correctness", name: "FinTech Correctness Screen",
    experience_band: :mid, question_count: 5, company_type: "fintech",
    summary: "Correctness-first questioning: double counting, NULL handling and " \
             "the cost of being wrong about money.",
    round_specs: [
      { "name" => "Data correctness", "skills" => %w[sql-joins sql-aggregation], "count" => 3 },
      { "name" => "Reference semantics", "skills" => %w[ruby-basics], "count" => 2 }
    ] }
]
templates.each do |attrs|
  InterviewTemplate.find_or_create_by!(slug: attrs[:slug]) { |t| t.assign_attributes(attrs) }
end
