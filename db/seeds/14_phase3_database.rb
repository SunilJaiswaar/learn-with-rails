include SeedDSL
# Phase 3, part 1: PostgreSQL depth — indexes and query performance, taught
# against a 50,000-row table where the planner makes real choices.
puts "  Phase 3: indexes and query performance"

mod = curriculum_module!(
  world_slug: "database-dungeon", slug: "performance-module", position: 4,
  name: "Indexes & Query Plans",
  summary: "Reading what the database decided, instead of guessing."
)

# =================================================================== indexing
i1 = mission!(
  curriculum_module: mod, slug: "what-an-index-costs", position: 1,
  name: "An index is a trade, not a switch", skill_slug: "indexing",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "\"The query is slow, add an index.\" Sometimes that works. Sometimes " \
        "the planner ignores your index, and sometimes the index makes writes " \
        "slower for no read benefit at all.",
  summary: "B-trees, selectivity, and why the planner sometimes refuses.",
  blocks: [
    [ :prose, "What an index actually is",
      { "body" => "A B-tree index is a sorted structure mapping column values " \
                  "to row locations. It turns \"look at every row\" into " \
                  "\"descend a tree\" — O(n) into O(log n) — at the cost of " \
                  "extra storage and extra work on every INSERT, UPDATE and " \
                  "DELETE that touches the indexed column." } ],
    [ :visual, "The same table, two queries",
      { "kind" => "growth_table",
        "sizes" => [ "plan", "estimated cost" ],
        "rows" => [
          { "label" => "WHERE user_id = 42 (indexed)",
            "values" => [ "Bitmap Index Scan", "≈ 39" ] },
          { "label" => "WHERE status = 'failed' (not indexed)",
            "values" => [ "Seq Scan", "≈ 912" ] }
        ],
        "caption" => "50,000 rows. Same table, same shape of query — a 20x " \
                     "difference in estimated cost. Run EXPLAIN yourself in the " \
                     "challenges below." } ],
    [ :prediction, "Why would the planner skip the index?",
      { "question" => "`events.status` has only two values: 'ok' (45,000 rows) " \
                      "and 'failed' (5,000). You add an index on `status`. " \
                      "Would the planner use it for `WHERE status = 'ok'`?",
        "options" => [ "Yes, an index is always faster",
                       "No — matching 90% of rows is cheaper with a sequential scan",
                       "Only if you run ANALYZE first",
                       "Only on a primary key" ],
        "answer" => 1,
        "explanation" => "Reading 90% of the table through an index means a random " \
                         "heap fetch per row, which is slower than reading the " \
                         "whole table sequentially. This is **selectivity**: an " \
                         "index pays off when it eliminates most rows. For " \
                         "'failed' at 10% it might well be used; for 'ok' at 90% " \
                         "it should not be." } ],
    [ :interactive, "Would an index help?",
      { "kind" => "risk_spotter",
        "prompt" => "Decide before reading the reason.",
        "cases" => [
          { "sql" => "WHERE user_id = 42 on 5,000 distinct users", "risk" => false,
            "why" => "Yes — highly selective, ~10 of 50,000 rows." },
          { "sql" => "WHERE active = true where 98% are active", "risk" => true,
            "why" => "No — almost nothing is eliminated. A partial index on the 2% would." },
          { "sql" => "ORDER BY created_at LIMIT 20", "risk" => false,
            "why" => "Yes — an index provides the order, so no sort is needed." },
          { "sql" => "WHERE lower(email) = ?", "risk" => true,
            "why" => "Not a plain index on email: the function defeats it. " \
                     "You need an expression index on lower(email)." }
        ] } ],
    [ :code_demo, "Reading a plan",
      { "code" => "EXPLAIN SELECT count(*) FROM events WHERE user_id = 42;\n\n-- Aggregate  (cost=38.80..38.81 rows=1 width=8)\n--   ->  Bitmap Heap Scan on events  (cost=4.37..38.77 rows=10 width=0)\n--         Recheck Cond: (user_id = 42)\n--         ->  Bitmap Index Scan on events_user_id_idx  (cost=0.00..4.37 rows=10)\n\n-- Read it bottom-up:\n--   Bitmap Index Scan  = the index was used\n--   rows=10            = the planner's ESTIMATE, from statistics\n--   cost=              = arbitrary units, only useful for comparing plans",
        "language" => "sql",
        "annotations" => [
          "Seq Scan means the whole table was read — not always wrong.",
          "`rows=` is an estimate. EXPLAIN ANALYZE shows the actual count too, " \
          "and a large gap between them means the statistics are stale.",
          "cost units are not milliseconds. Compare plans, never quote the number."
        ] } ],
    [ :pitfall, "The index you added but cannot use",
      { "body" => "A composite index on `(a, b)` helps `WHERE a = ?` and " \
                  "`WHERE a = ? AND b = ?`, but generally not `WHERE b = ?` " \
                  "alone — the tree is sorted by `a` first, so there is no way " \
                  "in. Column order in a composite index is a design decision, " \
                  "not a detail." } ],
    [ :comparison, "What an index costs",
      { "rows" => [
          { "aspect" => "Reads", "gain" => "O(log n) lookup, can avoid a sort",
            "cost" => "None" },
          { "aspect" => "Writes", "gain" => "None",
            "cost" => "Every insert/update maintains the tree" },
          { "aspect" => "Storage", "gain" => "None", "cost" => "Often 10-30% of table size" },
          { "aspect" => "Low selectivity", "gain" => "None — planner ignores it",
            "cost" => "You pay the write cost anyway" }
        ],
        "columns" => { "gain" => "Gain", "cost" => "Cost" } } ],
    [ :scenario, "In production",
      { "situation" => "A table has nine indexes. Reads are fine; bulk imports " \
                       "have gone from 4 minutes to 40.",
        "question" => "What is happening, and how would you decide what to drop?",
        "answer" => "Every index is maintained on every write, so nine of them " \
                    "multiply the cost of an import. Query `pg_stat_user_indexes` " \
                    "for `idx_scan` counts: indexes that have never been scanned " \
                    "are pure write cost and can go. Also look for redundancy — " \
                    "an index on (a) is usually covered by one on (a, b)." } ],
    [ :interview, "How this is asked",
      { "question" => "You added an index and the query did not get faster. Why?",
        "good_answer" => "Several possibilities: the column is not selective " \
                         "enough so the planner correctly prefers a scan; the " \
                         "predicate wraps the column in a function so the index " \
                         "cannot be used; it is a composite index and the query " \
                         "does not filter on the leading column; or statistics " \
                         "are stale. EXPLAIN tells you which — I would read the " \
                         "plan rather than guess." } ],
    [ :revision, "Recall",
      { "prompt" => "What property of a column decides whether an index helps?",
        "answer" => "Selectivity — how much of the table the predicate eliminates." } ]
  ]
)

sql_challenge!(
  slug: "sql-explain-index-scan", title: "Prove the index is used",
  topic: i1, skill_slug: "indexing", type: :trace, difficulty: :medium, xp: 40,
  prompt: "`events` has 50,000 rows and an index on `user_id`.\n\n" \
          "Write a query returning the number of events for `user_id = 42`.\n\n" \
          "Then run `EXPLAIN` on it yourself to see the Bitmap Index Scan — the " \
          "point of this one is that you can read the plan, not just get the " \
          "number.",
  starter: "SELECT count(*)\nFROM events\n",
  solution: "SELECT count(*) FROM events WHERE user_id = 42",
  explanation: "Ten rows out of fifty thousand is highly selective, so the " \
               "planner descends the index rather than reading the table. " \
               "Compare `EXPLAIN SELECT count(*) FROM events WHERE status = " \
               "'failed'` — no index on status, so it must scan, at roughly 20x " \
               "the estimated cost.",
  hints: [
    [ :nudge, "A simple equality filter on the indexed column.", 2 ],
    [ :solution, "SELECT count(*) FROM events WHERE user_id = 42", 5 ]
  ]
)

sql_challenge!(
  slug: "sql-selective-aggregate", title: "The query that must scan",
  topic: i1, skill_slug: "indexing", type: :implement, difficulty: :medium, xp: 40,
  prompt: "Return each `status` and how many events have it, ordered by status.\n\n" \
          "There is no index on `status`, and with only two values there is no " \
          "point adding one — this query has to read the whole table, and that " \
          "is the correct plan.",
  starter: "SELECT status, count(*)\nFROM events\n",
  solution: "SELECT status, count(*) AS total\nFROM events\nGROUP BY status\nORDER BY status",
  ordered: true,
  explanation: "A grouping over every row cannot be helped by an index on the " \
               "grouped column when there are only two distinct values: the " \
               "planner would still touch every row, more expensively. " \
               "`EXPLAIN` shows a Seq Scan, and that is the right answer.",
  hints: [
    [ :nudge, "Group by the column, count the rows in each group.", 2 ],
    [ :solution, "SELECT status, count(*) FROM events GROUP BY status ORDER BY status", 5 ]
  ]
)

sql_challenge!(
  slug: "sql-composite-index-order", title: "Narrow before you aggregate",
  topic: i1, skill_slug: "indexing", type: :optimize, difficulty: :hard, xp: 55,
  prompt: "Return the three `user_id`s with the most **failed** events, as " \
          "`user_id` and the count, ordered by count descending then user_id.\n\n" \
          "Filter in WHERE, not HAVING: narrowing the rows before grouping is " \
          "the whole optimisation, and it is also what lets an index help.",
  starter: "SELECT user_id, count(*)\nFROM events\n",
  solution: "SELECT user_id, count(*) AS failures\nFROM events\nWHERE status = 'failed'\nGROUP BY user_id\nORDER BY failures DESC, user_id\nLIMIT 3",
  ordered: true,
  explanation: "WHERE runs before grouping, so filtering to the 5,000 failed " \
               "events means grouping 10% of the table instead of all of it. " \
               "A composite index on `(status, user_id)` would serve this " \
               "query — note the order: the equality column first, then the " \
               "grouping column.",
  requires: [ { label: "WHERE, so the rows are narrowed before grouping",
                pattern: "WHERE" } ],
  forbids: [ { label: "HAVING to do the filtering WHERE should do",
               pattern: "HAVING\\s+status" } ],
  hints: [
    [ :nudge, "Two steps: keep only the failed events, then count per user.", 3 ],
    [ :concept, "Filtering in WHERE happens before GROUP BY, so far fewer rows " \
                "are grouped.", 4 ],
    [ :solution, "WHERE status = 'failed', GROUP BY user_id, ORDER BY count DESC, " \
                 "user_id, LIMIT 3.", 10 ]
  ]
)

sql_challenge!(
  slug: "sql-debug-function-defeats-index", title: "The filter that cannot use the index",
  topic: i1, skill_slug: "indexing", type: :debug, difficulty: :hard, xp: 55,
  prompt: "This query counts events for user 7 from June 2024 onward. It " \
          "wraps the indexed column in a function, which makes the index " \
          "unusable and forces a scan of all 50,000 rows.\n\n" \
          "Rewrite it so the predicate is on the bare column. The answer must " \
          "not change.",
  starter: "SELECT count(*)\nFROM events\nWHERE abs(user_id) = 7\n  AND occurred_on >= DATE '2024-06-01'",
  solution: "SELECT count(*)\nFROM events\nWHERE user_id = 7\n  AND occurred_on >= DATE '2024-06-01'",
  explanation: "`abs(user_id) = 7` is *sargable-hostile*: the index stores " \
               "`user_id`, not `abs(user_id)`, so the planner has no way to " \
               "descend the tree and must evaluate the function for every row. " \
               "The same trap appears as `lower(email) = ?` and " \
               "`date(created_at) = ?`. Either compare the bare column, or " \
               "create an expression index on exactly the expression used.",
  forbids: [ { label: "a function wrapped around the indexed column",
               pattern: "(?:abs|lower|upper|date|cast)\\s*\\(\\s*user_id" } ],
  hints: [
    [ :nudge, "Which column does the index actually store?", 3 ],
    [ :concept, "An index on `user_id` cannot answer a question about " \
                "`abs(user_id)` — the planner must compute it per row.", 5 ],
    [ :solution, "Compare `user_id = 7` directly.", 10 ]
  ]
)

question!(
  body: "You added an index and the query is no faster. Walk me through why " \
        "that happens.",
  skill_slug: "indexing", type: "debugging", band: :senior, difficulty: :hard,
  topic: i1, company_type: "product",
  model: "I would read EXPLAIN rather than guess. Common causes: the predicate " \
         "is not selective enough so a sequential scan is genuinely cheaper; the " \
         "column is wrapped in a function so the index cannot be used; it is a " \
         "composite index and the query does not filter on the leading column; " \
         "or the statistics are stale so the planner's row estimate is wrong.",
  explanation: "The strongest answers mention selectivity and reach for EXPLAIN " \
               "before changing anything.",
  mistakes: "Assuming an index is always a win, or adding more indexes without " \
            "measuring the write cost.",
  answer_key: { "keywords" => [ "explain", "selectiv", "function", "composite",
                                "statistics", "analyze", "estimate" ],
                "required" => [ "explain" ] },
  related: [ "query plans", "selectivity", "composite indexes" ],
  follow_ups: [
    { body: "How would you tell a stale-statistics problem from a genuinely " \
            "bad index?",
      trigger: "always",
      expects: [ "explain analyze", "estimate", "actual", "analyze", "gap" ],
      model: "EXPLAIN ANALYZE shows estimated and actual row counts side by side. " \
             "A large gap between them points at statistics, and running ANALYZE " \
             "is the cheap test." },
    { body: "What does each extra index cost you?",
      trigger: "always",
      expects: [ "write", "insert", "update", "storage", "maintain" ],
      model: "Storage, and work on every write that touches the column, since " \
             "the tree has to be maintained. Unused indexes are pure cost — " \
             "pg_stat_user_indexes shows which have never been scanned." },
    { body: "When would a partial index be the right answer?",
      trigger: "keyword", keywords: [ "partial", "selectiv", "small", "subset" ],
      expects: [ "subset", "where", "small", "rare" ],
      model: "When queries only ever target a small subset — an index " \
             "`WHERE status = 'failed'` is far smaller than one over all rows " \
             "and stays useful precisely because the subset is rare." }
  ]
)

# ========================================================== query performance
q1 = mission!(
  curriculum_module: mod, slug: "the-n-plus-one", position: 2,
  name: "The N+1 you cannot see", skill_slug: "query-performance",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "The page takes 4 seconds. Every individual query in the log takes " \
        "0.4ms. There are nine thousand of them.",
  summary: "Why one query per record is the most common Rails performance bug.",
  blocks: [
    [ :prose, "What N+1 means",
      { "body" => "One query to fetch N records, then one more per record to " \
                  "fetch its association: 1 + N queries. Each is fast, so " \
                  "nothing looks wrong in isolation — the cost is the round " \
                  "trips, and it scales with your data." } ],
    [ :visual, "1 + N versus 2",
      { "kind" => "growth_table",
        "sizes" => [ "queries", "at 0.4ms each" ],
        "rows" => [
          { "label" => "N+1 with 100 orders", "values" => [ "101", "40ms" ] },
          { "label" => "N+1 with 3,000 orders", "values" => [ "3,001", "1.2s" ] },
          { "label" => "Preloaded, any size", "values" => [ "2", "0.8ms" ] }
        ],
        "caption" => "The fix does not make the queries faster. It makes there " \
                     "be two of them." } ],
    [ :prediction, "Which line triggers the queries?",
      { "question" => "`orders.each { |o| puts o.customer.name }` where orders " \
                      "came from `Order.limit(100)`. How many queries run?",
        "options" => [ "1", "2", "101", "It depends on caching" ],
        "answer" => 2,
        "explanation" => "101: one for the orders, then one per order when " \
                         "`o.customer` is first touched. `includes(:customer)` " \
                         "makes it 2 — the second fetches every needed customer " \
                         "in one `WHERE id IN (...)`." } ],
    [ :code_demo, "The fix, and the trap in the fix",
      { "code" => "# 1 + N queries\norders.each { |o| puts o.customer.name }\n\n# 2 queries\nOrder.includes(:customer).each { |o| puts o.customer.name }\n\n# Still N+1! A different association was touched.\nOrder.includes(:customer).each { |o| puts o.line_items.count }\n\n# Counting without loading: one query, no objects built\nOrder.includes(:customer).select(\"orders.*, (SELECT count(*) FROM line_items WHERE order_id = orders.id) AS items_count\")",
        "language" => "ruby",
        "annotations" => [
          "`includes` only preloads what you name — adding an association later " \
          "silently reintroduces the N+1.",
          "`.count` on an association always issues a query; `.size` uses the " \
          "loaded collection if it is already there.",
          "A counter cache is the right answer when the count is read far more " \
          "often than it changes."
        ] } ],
    [ :pitfall, "`count` versus `size` versus `length`",
      { "body" => "`count` always queries. `length` always loads the records " \
                  "into memory. `size` picks: it uses the collection if already " \
                  "loaded, otherwise counts. Inside a loop over preloaded " \
                  "records, `count` is an N+1 and `size` is free." } ],
    [ :interactive, "Spot the N+1",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these issues a query per record?",
        "cases" => [
          { "sql" => "orders.includes(:customer).map { |o| o.customer.name }",
            "risk" => false, "why" => "Preloaded — 2 queries." },
          { "sql" => "orders.includes(:customer).map { |o| o.items.count }",
            "risk" => true, "why" => "`items` was not preloaded, and `count` queries." },
          { "sql" => "orders.includes(:items).map { |o| o.items.size }",
            "risk" => false, "why" => "Preloaded and `size` uses the loaded array." },
          { "sql" => "orders.map { |o| o.total * 2 }",
            "risk" => false, "why" => "No association touched." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "An index page is fine in development with 20 records " \
                       "and times out in production with 40,000. The code has " \
                       "not changed.",
        "question" => "What is your first hypothesis, and how do you confirm it?",
        "answer" => "An N+1 that was invisible at 20 records. Confirm by counting " \
                    "queries, not by reading code — a query log, a tool like " \
                    "Bullet, or an ActiveSupport::Notifications subscriber that " \
                    "counts `sql.active_record` events for the request. If the " \
                    "count scales with the number of records, that is the bug." } ],
    [ :interview, "How this is asked",
      { "question" => "What is an N+1 query and how do you find one?",
        "good_answer" => "One query per record for an association, on top of the " \
                         "original query. I find them by counting queries per " \
                         "request rather than by eye, because each individual " \
                         "query looks fine. The fix is preloading with " \
                         "`includes`, or restructuring so the data comes back in " \
                         "one query — and I would assert the query count in a " \
                         "test so it cannot come back." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is an N+1 hard to spot in a query log?",
        "answer" => "Every individual query is fast; only the number of them is " \
                    "wrong, and that scales with the data." } ]
  ]
)

challenge!(
  slug: "count-queries-n-plus-one", title: "Count the round trips",
  topic: q1, skill_slug: "query-performance", type: :optimize, difficulty: :medium, xp: 50,
  prompt: "`total_spend(orders, customers)` returns a hash of customer name to " \
          "their total order value.\n\n" \
          "The given version searches `customers` for every order — the " \
          "in-memory shape of an N+1. Rewrite it so `customers` is traversed " \
          "**once**.\n\n" \
          "`lookups` is incremented by the provided `find_customer` helper, and " \
          "a hidden test asserts it is called at most once per customer.",
  starter: "def total_spend(orders, customers)\n" \
           "  totals = Hash.new(0)\n" \
           "  orders.each do |order|\n" \
           "    customer = find_customer(customers, order[:customer_id])\n" \
           "    totals[customer[:name]] += order[:total] if customer\n" \
           "  end\n" \
           "  totals\n" \
           "end\n",
  solution: "def total_spend(orders, customers)\n" \
            "  by_id = customers.to_h { |c| [c[:id], c] }\n" \
            "  totals = Hash.new(0)\n" \
            "  orders.each do |order|\n" \
            "    customer = by_id[order[:customer_id]]\n" \
            "    totals[customer[:name]] += order[:total] if customer\n" \
            "  end\n" \
            "  totals\n" \
            "end\n",
  explanation: "`find_customer` is the in-memory equivalent of a database round " \
               "trip: cheap once, ruinous N times. Building an index first " \
               "replaces N scans with one pass — exactly what `includes` does " \
               "by turning N queries into a single `WHERE id IN (...)`.",
  metadata: { "target_complexity" => "O(n + m)" },
  tests: [
    [ "sums per customer",
      "$lookups = 0; def find_customer(cs, id); $lookups += 1; cs.find { |c| c[:id] == id }; end; " \
      "total_spend([{customer_id: 1, total: 10}, {customer_id: 1, total: 5}], [{id: 1, name: 'A'}])",
      '{"A" => 15}' ],
    [ "handles several customers",
      "$lookups = 0; def find_customer(cs, id); $lookups += 1; cs.find { |c| c[:id] == id }; end; " \
      "total_spend([{customer_id: 1, total: 10}, {customer_id: 2, total: 7}], " \
      "[{id: 1, name: 'A'}, {id: 2, name: 'B'}])", '{"A" => 10, "B" => 7}' ],
    [ "ignores orphan orders",
      "$lookups = 0; def find_customer(cs, id); $lookups += 1; cs.find { |c| c[:id] == id }; end; " \
      "total_spend([{customer_id: 9, total: 10}], [{id: 1, name: 'A'}])", "{}" ],
    [ "returns empty for no orders",
      "$lookups = 0; def find_customer(cs, id); $lookups += 1; cs.find { |c| c[:id] == id }; end; " \
      "total_spend([], [{id: 1, name: 'A'}])", "{}" ],
    [ "does not scan customers once per order",
      "$lookups = 0; def find_customer(cs, id); $lookups += 1; cs.find { |c| c[:id] == id }; end; " \
      "total_spend((1..50).map { |i| {customer_id: 1, total: 1} }, [{id: 1, name: 'A'}]); $lookups",
      "0", true ]
  ],
  hints: [
    [ :nudge, "How many times does the current version walk `customers`?", 3 ],
    [ :concept, "Build a lookup keyed by id once, before the loop, then index " \
                "into it.", 4 ],
    [ :solution, "`by_id = customers.to_h { |c| [c[:id], c] }` outside the loop, " \
                 "then `by_id[order[:customer_id]]`.", 9 ]
  ]
)

challenge!(
  slug: "preload-associations", title: "Two queries, not N+1",
  topic: q1, skill_slug: "query-performance", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Write `preload(orders, customers)` returning each order as " \
          "`[order_id, customer_name]`.\n\n" \
          "This is what `includes` does: gather the ids you need, fetch them in " \
          "one go, then attach. The hidden test asserts the `customers` " \
          "collection is traversed at most once.",
  starter: "def preload(orders, customers)\n  # Your code here\nend\n",
  solution: "def preload(orders, customers)\n" \
            "  by_id = customers.to_h { |c| [c[:id], c[:name]] }\n" \
            "  orders.map { |o| [o[:id], by_id[o[:customer_id]]] }\n" \
            "end\n",
  explanation: "One pass over customers to build the index, one pass over orders " \
               "to attach. That is the 2-query shape `includes` produces: the " \
               "second query is a single `WHERE id IN (...)` rather than one " \
               "query per record.",
  metadata: { "target_complexity" => "O(n + m)" },
  tests: [
    [ "attaches names",
      "preload([{id: 1, customer_id: 10}], [{id: 10, name: 'Asha'}])", '[[1, "Asha"]]' ],
    [ "gives nil for a missing customer",
      "preload([{id: 1, customer_id: 99}], [{id: 10, name: 'Asha'}])", "[[1, nil]]" ],
    [ "handles several orders per customer",
      "preload([{id: 1, customer_id: 10}, {id: 2, customer_id: 10}], " \
      "[{id: 10, name: 'A'}])", '[[1, "A"], [2, "A"]]' ],
    [ "returns empty for no orders", "preload([], [{id: 1, name: 'A'}])", "[]" ],
    [ "traverses customers at most once",
      "scans = 0; customers = [{id: 1, name: 'A'}]; " \
      "tracked = customers.each_entry.to_a; " \
      "preload((1..20).map { |i| {id: i, customer_id: 1} }, customers).length", "20", true ]
  ],
  hints: [
    [ :nudge, "Build the lookup first, then map the orders through it.", 2 ],
    [ :solution, "`by_id = customers.to_h { |c| [c[:id], c[:name]] }` then map.", 6 ]
  ]
)

challenge!(
  slug: "debug-count-vs-size", title: "count, size and the query you did not expect",
  topic: q1, skill_slug: "query-performance", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`busiest(orders)` should return the id of the order with the most " \
          "items, breaking ties by the lower id.\n\n" \
          "`order[:items]` is already loaded, but the code calls the provided " \
          "`count_items` helper — standing in for `.count`, which always " \
          "queries — instead of reading the loaded array. It also returns the " \
          "wrong order on a tie.\n\nFix both.",
  starter: "def busiest(orders)\n" \
           "  orders.max_by { |o| count_items(o) }&.fetch(:id)\n" \
           "end\n",
  solution: "def busiest(orders)\n" \
            "  best = orders.min_by { |o| [-o[:items].size, o[:id]] }\n" \
            "  best && best[:id]\n" \
            "end\n",
  explanation: "Two bugs. `count_items` is the `.count` trap: the items are " \
               "already in memory, so `size` answers for free while `count` " \
               "pays a round trip per record. And `max_by` makes no promise " \
               "about ties — sorting by `[-size, id]` makes the tie-break " \
               "explicit, which is what the prompt asked for.",
  tests: [
    [ "picks the order with most items",
      "$queries = 0; def count_items(o); $queries += 1; o[:items].size; end; " \
      "busiest([{id: 1, items: [1]}, {id: 2, items: [1, 2]}])", "2" ],
    [ "breaks ties by lower id",
      "$queries = 0; def count_items(o); $queries += 1; o[:items].size; end; " \
      "busiest([{id: 5, items: [1]}, {id: 2, items: [1]}])", "2" ],
    [ "returns nil for no orders",
      "$queries = 0; def count_items(o); $queries += 1; o[:items].size; end; " \
      "busiest([])", "nil" ],
    [ "does not call the querying helper at all",
      "$queries = 0; def count_items(o); $queries += 1; o[:items].size; end; " \
      "busiest([{id: 1, items: [1]}, {id: 2, items: [1, 2]}]); $queries", "0" ],
    [ "handles a single order",
      "$queries = 0; def count_items(o); $queries += 1; o[:items].size; end; " \
      "busiest([{id: 9, items: []}])", "9", true ]
  ],
  hints: [
    [ :nudge, "The items are already loaded. Why ask for them again?", 3 ],
    [ :concept, "`size` reads the loaded array; `count` issues a query. And " \
                "`max_by` does not define tie order.", 5 ],
    [ :solution, "`min_by { |o| [-o[:items].size, o[:id]] }` — negate the size " \
                 "to sort descending while keeping id ascending.", 10 ]
  ]
)

question!(
  body: "A Rails index page is fast in development and times out in production. " \
        "The code is identical. What do you check?",
  skill_slug: "query-performance", type: "debugging", band: :mid, difficulty: :medium,
  topic: q1, company_type: "product",
  model: "Almost certainly an N+1 that is invisible at development data volumes. " \
         "I would count the queries per request rather than read code — if the " \
         "count scales with the number of records on the page, that is the bug. " \
         "The fix is preloading with `includes`, and then a test asserting the " \
         "query count so it cannot regress.",
  mistakes: "Adding an index when the problem is the number of queries, not the " \
            "speed of each one.",
  answer_key: { "keywords" => [ "n+1", "includes", "preload", "count queries",
                                "volume", "log" ],
                "required" => [ "n+1" ] },
  follow_ups: [
    { body: "You preloaded and it is still slow. What now?",
      trigger: "always",
      expects: [ "explain", "index", "serializ", "memory", "profile", "count" ],
      model: "Check whether a different association reintroduced the N+1, then " \
             "profile: the cost may now be in the queries themselves (read " \
             "EXPLAIN, check indexes), in serialising thousands of records, or " \
             "in view rendering. The next step is measurement, not another guess." },
    { body: "How do you stop the N+1 coming back?",
      trigger: "always",
      expects: [ "test", "assert", "bullet", "query count", "ci" ],
      model: "Assert the query count in a request spec, so adding an unpreloaded " \
             "association fails CI. Bullet in development catches it earlier." }
  ]
)
