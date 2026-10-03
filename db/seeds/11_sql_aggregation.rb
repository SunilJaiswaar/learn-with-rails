include SeedDSL
puts "  Database Dungeon: aggregation and window functions"

mod = curriculum_module!(
  world_slug: "database-dungeon", slug: "aggregation-module", position: 3,
  name: "Aggregation & Windows",
  summary: "Collapsing rows into answers — and keeping the rows when you need them."
)

# ---------------------------------------------------------------- mission 1
a1 = mission!(
  curriculum_module: mod, slug: "group-by-and-having", position: 1,
  name: "GROUP BY, and the WHERE that came too late", skill_slug: "sql-aggregation",
  minutes: 7, xp: 15, difficulty: :easy,
  hook: "You want departments whose average salary is over 70,000. " \
        "You add `WHERE avg(salary) > 70000` and PostgreSQL tells you " \
        "aggregate functions are not allowed in WHERE. It is right, and the " \
        "reason explains the whole clause order.",
  summary: "GROUP BY collapses rows; HAVING filters the groups; WHERE filters first.",
  blocks: [
    [ :prose, "The order things happen",
      { "body" => "A query is not executed top to bottom. Roughly: FROM, then " \
                  "WHERE, then GROUP BY, then HAVING, then SELECT, then " \
                  "ORDER BY. WHERE runs before the groups exist, so it cannot " \
                  "see an aggregate. HAVING runs after, so it can." } ],
    [ :visual, "Before and after grouping",
      { "kind" => "join_result",
        "result" => { "columns" => [ "department", "avg(salary)", "count(*)" ],
                      "rows" => [ [ "Engineering", "97000.00", "4" ],
                                  [ "Sales", "72000.00", "3" ],
                                  [ "Support", "54000.00", "1" ] ] },
        "caption" => "Eight employee rows collapse into three department rows. " \
                     "Logistics has no employees, so an INNER JOIN drops it " \
                     "entirely — a LEFT JOIN would keep it with count 0." } ],
    [ :prediction, "Which clause?",
      { "question" => "You want only departments averaging over 70,000. " \
                      "Where does that condition belong?",
        "options" => [ "WHERE, because it is a filter",
                       "HAVING, because it filters groups",
                       "ORDER BY, with a LIMIT",
                       "Either works" ],
        "answer" => 1,
        "explanation" => "HAVING. WHERE is evaluated before GROUP BY, so the " \
                         "average does not exist yet. HAVING runs after grouping " \
                         "and is the only place an aggregate condition can go." } ],
    [ :code_demo, "WHERE and HAVING together",
      { "code" => "-- WHERE narrows the ROWS before grouping,\n-- HAVING narrows the GROUPS after.\nSELECT d.name,\n       count(*)        AS headcount,\n       round(avg(e.salary), 2) AS avg_salary\nFROM departments d\nJOIN employees e ON e.department_id = d.id\nWHERE e.hired_on >= '2019-01-01'   -- drop rows first\nGROUP BY d.name\nHAVING avg(e.salary) > 70000       -- then drop groups\nORDER BY avg_salary DESC;",
        "language" => "sql",
        "annotations" => [
          "Every non-aggregated SELECT column must appear in GROUP BY.",
          "An alias defined in SELECT cannot be used in WHERE or HAVING, " \
          "because SELECT is evaluated later — but ORDER BY can use it.",
          "Put a condition in WHERE when it is about a row, in HAVING when it " \
          "is about the group."
        ] } ],
    [ :pitfall, "COUNT(*) and COUNT(column) are different questions",
      { "body" => "`COUNT(*)` counts rows. `COUNT(column)` counts rows where " \
                  "that column is not NULL. After a LEFT JOIN they diverge, " \
                  "which is exactly how \"departments with zero employees\" " \
                  "reports end up claiming every department has at least one." } ],
    [ :comparison, "WHERE vs HAVING",
      { "rows" => [
          { "aspect" => "Runs", "where" => "Before grouping", "having" => "After grouping" },
          { "aspect" => "Can see aggregates", "where" => "No", "having" => "Yes" },
          { "aspect" => "Filters", "where" => "Individual rows", "having" => "Whole groups" },
          { "aspect" => "Performance", "where" => "Reduces work early",
            "having" => "Runs on already-grouped data" }
        ],
        "columns" => { "where" => "WHERE", "having" => "HAVING" } } ],
    [ :interactive, "Row filter or group filter?",
      { "kind" => "risk_spotter",
        "prompt" => "Decide where each condition belongs.",
        "cases" => [
          { "sql" => "Only employees hired since 2020", "risk" => false,
            "why" => "WHERE — a property of one row." },
          { "sql" => "Only departments with more than 2 employees", "risk" => true,
            "why" => "HAVING — a property of the group." },
          { "sql" => "Only departments whose name starts with 'S'", "risk" => false,
            "why" => "WHERE — a property of the row, and filtering early is cheaper." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A daily report groups 40 million order rows by customer " \
                       "and then filters with HAVING to the 200 customers who " \
                       "spent over a threshold. It takes 50 seconds.",
        "question" => "What would you try first?",
        "answer" => "Move whatever you can into WHERE so fewer rows are grouped " \
                    "— a date range is usually available. HAVING cannot be " \
                    "applied before the grouping, so filtering early is the only " \
                    "way to shrink the work. After that, an index supporting the " \
                    "WHERE and the GROUP BY key is the next step." } ],
    [ :interview, "How this is asked",
      { "question" => "What is the difference between WHERE and HAVING?",
        "good_answer" => "WHERE filters rows before grouping and cannot reference " \
                         "aggregates; HAVING filters groups after aggregation and " \
                         "can. Practically, put a condition in WHERE whenever " \
                         "possible because it reduces the rows that have to be " \
                         "grouped at all." } ],
    [ :revision, "Recall",
      { "prompt" => "Why can't WHERE reference avg(salary)?",
        "answer" => "WHERE runs before GROUP BY, so the aggregate does not exist " \
                    "yet. Use HAVING." } ]
  ]
)

# ---------------------------------------------------------------- mission 2
a2 = mission!(
  curriculum_module: mod, slug: "window-functions", position: 2,
  name: "Keeping the rows you just aggregated", skill_slug: "sql-aggregation",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "You need each employee's salary *and* their department's average, on " \
        "the same row. GROUP BY destroys the rows. A window function does not.",
  summary: "OVER (PARTITION BY ...) aggregates without collapsing.",
  blocks: [
    [ :prose, "The difference in one line",
      { "body" => "GROUP BY returns one row per group. A window function returns " \
                  "one row per input row, with the aggregate computed over a " \
                  "\"window\" of related rows alongside it." } ],
    [ :visual, "Same aggregate, different shape",
      { "kind" => "join_result",
        "result" => { "columns" => [ "name", "salary", "dept avg (window)", "rank in dept" ],
                      "rows" => [ [ "Chen", "120000.00", "97000.00", "1" ],
                                  [ "Priya", "95000.00", "97000.00", "2" ],
                                  [ "Wei", "95000.00", "97000.00", "2" ],
                                  [ "Aisha", "78000.00", "97000.00", "4" ] ] },
        "caption" => "Four rows in, four rows out — each carrying its " \
                     "department's average. Note Priya and Wei share rank 2, and " \
                     "RANK() then skips 3." } ],
    [ :prediction, "RANK or DENSE_RANK?",
      { "question" => "Priya and Wei tie for second. With `RANK()`, what rank " \
                      "does the next employee (Aisha) get?",
        "options" => [ "3", "4", "2", "It errors on ties" ],
        "answer" => 1,
        "explanation" => "4. RANK() leaves a gap after a tie: 1, 2, 2, 4. " \
                         "DENSE_RANK() would give 1, 2, 2, 3 with no gap, and " \
                         "ROW_NUMBER() forces 1, 2, 3, 4 by picking arbitrarily " \
                         "between the tied rows." } ],
    [ :code_demo, "The three ranking functions",
      { "code" => "SELECT name,\n       salary,\n       round(avg(salary) OVER (PARTITION BY department_id), 2) AS dept_avg,\n       rank()       OVER (PARTITION BY department_id ORDER BY salary DESC) AS rnk,\n       dense_rank() OVER (PARTITION BY department_id ORDER BY salary DESC) AS dense,\n       row_number() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rn\nFROM employees\nORDER BY department_id, salary DESC, name;",
        "language" => "sql",
        "annotations" => [
          "PARTITION BY is the window's GROUP BY; ORDER BY inside OVER sets the " \
          "order the function sees.",
          "rank() gaps after ties, dense_rank() does not, row_number() never ties.",
          "A window function cannot go in WHERE — it is computed after it. " \
          "Wrap the query in a subquery or CTE to filter on the result."
        ] } ],
    [ :pitfall, "You cannot filter on a window function directly",
      { "body" => "`WHERE rank() OVER (...) = 1` is invalid: window functions are " \
                  "evaluated after WHERE. The fix is a CTE or subquery — compute " \
                  "the rank in the inner query, filter on it in the outer one. " \
                  "That pattern is the standard answer to \"top N per group\"." } ],
    [ :interactive, "Pick the function",
      { "kind" => "risk_spotter",
        "prompt" => "Which window function fits?",
        "cases" => [
          { "sql" => "Top earner per department, including ties", "risk" => true,
            "why" => "rank() or dense_rank() = 1 — both keep every tied row." },
          { "sql" => "Exactly one row per department, ties broken arbitrarily",
            "risk" => false, "why" => "row_number() = 1." },
          { "sql" => "A running total over time", "risk" => true,
            "why" => "sum(...) OVER (ORDER BY date) — the frame grows as you go." },
          { "sql" => "Each row's share of its group total", "risk" => false,
            "why" => "value / sum(value) OVER (PARTITION BY group)." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A \"most recent order per customer\" query self-joins " \
                       "orders to a grouped subquery on max(placed_on). " \
                       "Customers who placed two orders on the same day appear " \
                       "twice, inflating the report.",
        "question" => "How would a window function fix it?",
        "answer" => "Use row_number() OVER (PARTITION BY customer_id ORDER BY " \
                    "placed_on DESC, id DESC) in a CTE, then keep row 1. " \
                    "row_number() guarantees exactly one row per customer even " \
                    "when the ordering column ties, which max() cannot." } ],
    [ :interview, "How this is asked",
      { "question" => "When would you reach for a window function instead of " \
                      "GROUP BY?",
        "good_answer" => "When I need the detail rows and an aggregate over them " \
                         "at the same time — a per-row share of a total, a " \
                         "running total, a rank within a group, or top-N-per-group. " \
                         "GROUP BY collapses the rows, so it cannot answer those " \
                         "without a self-join." } ],
    [ :revision, "Recall",
      { "prompt" => "RANK(), DENSE_RANK(), ROW_NUMBER(): which gaps after a tie, " \
                    "and which never ties?",
        "answer" => "RANK() gaps; DENSE_RANK() does not gap; ROW_NUMBER() never " \
                    "ties." } ]
  ]
)

# ------------------------------------------------- SQL Boss Arena (spec 20)
sql_challenge!(
  slug: "sql-headcount-including-empty", title: "Headcount, including the empty team",
  topic: a1, skill_slug: "sql-aggregation", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Return every department's `name` and its `headcount`.\n\n" \
          "Logistics has **no** employees and must still appear, with a " \
          "headcount of 0. Order by headcount descending, then name.\n\n" \
          "This combines both traps you have met: the join that drops rows, and " \
          "the COUNT that miscounts them.",
  starter: "SELECT d.name, count(?) AS headcount\nFROM departments d\n",
  solution: "SELECT d.name, count(e.id) AS headcount\nFROM departments d\nLEFT JOIN employees e ON e.department_id = d.id\nGROUP BY d.name\nORDER BY headcount DESC, d.name",
  ordered: true,
  explanation: "Two decisions, both necessary. The LEFT JOIN keeps Logistics; " \
               "`count(e.id)` rather than `count(*)` makes its headcount 0, " \
               "because the join produced one NULL-filled row for it and " \
               "COUNT ignores NULLs in a column.",
  requires: [ { label: "a LEFT JOIN, so the empty department survives",
                pattern: "LEFT\\s+(?:OUTER\\s+)?JOIN" } ],
  hints: [
    [ :nudge, "Two separate mistakes are possible here: losing Logistics, and " \
              "giving it a headcount of 1.", 3 ],
    [ :concept, "An INNER JOIN drops departments with no employees. A LEFT JOIN " \
                "keeps them — but then count(*) counts the NULL row.", 4 ],
    [ :pseudocode, "departments LEFT JOIN employees, GROUP BY department name, " \
                   "and count a column from the employees side", 6 ],
    [ :solution, "`count(e.id)` after a LEFT JOIN: COUNT of a column skips NULLs, " \
                 "so the unmatched row contributes 0.", 10 ]
  ]
)

sql_challenge!(
  slug: "sql-top-earner-per-group", title: "Top earner in every department",
  topic: a2, skill_slug: "sql-aggregation", type: :implement, difficulty: :hard, xp: 60,
  prompt: "Return the `name` and `salary` of the highest earner in **each** " \
          "department.\n\n" \
          "If a department has two people tied at the top, return both. " \
          "Order by salary descending, then name.\n\n" \
          "Solve it with a window function, not a self-join.",
  starter: "WITH ranked AS (\n  SELECT name, salary, department_id\n  FROM employees\n)\nSELECT name, salary\nFROM ranked\n",
  solution: "WITH ranked AS (\n  SELECT name, salary,\n         dense_rank() OVER (PARTITION BY department_id ORDER BY salary DESC) AS rk\n  FROM employees\n)\nSELECT name, salary\nFROM ranked\nWHERE rk = 1\nORDER BY salary DESC, name",
  ordered: true,
  explanation: "This is the canonical top-N-per-group shape: rank inside a CTE, " \
               "filter on the rank outside it. A window function cannot be used " \
               "in WHERE because it is computed after WHERE runs, which is why " \
               "the CTE is required rather than stylistic. " \
               "`dense_rank()` (or `rank()`) keeps tied top earners; " \
               "`row_number()` would silently drop one of them.",
  requires: [ { label: "a window function (OVER ...)", pattern: "OVER\\s*\\(" } ],
  hints: [
    [ :nudge, "Rank the employees within their department first. Then keep only " \
              "rank 1.", 3 ],
    [ :concept, "`WHERE rank() OVER (...) = 1` is invalid — window functions are " \
                "evaluated after WHERE. Compute the rank in a CTE, filter outside.", 5 ],
    [ :clue, "PARTITION BY department_id ORDER BY salary DESC gives you the rank " \
             "within each department.", 6 ],
    [ :solution, "Use dense_rank() (not row_number(), which would drop a tied " \
                 "top earner) in a CTE, then `WHERE rk = 1`.", 12 ]
  ]
)

sql_challenge!(
  slug: "sql-running-total", title: "Running revenue",
  topic: a2, skill_slug: "sql-aggregation", type: :implement, difficulty: :hard, xp: 55,
  prompt: "For every **paid** order, return `placed_on` and the running total " \
          "of `total` up to and including that order, ordered by `placed_on` " \
          "then `id`.\n\n" \
          "Cancelled and pending orders are not revenue and must be excluded.\n\n" \
          "Two orders share 2024-03-02, so your ordering needs a tie-break to " \
          "be reproducible.",
  starter: "SELECT placed_on, total\nFROM orders\nWHERE status = 'paid'\n",
  solution: "SELECT placed_on,\n       sum(total) OVER (ORDER BY placed_on, id) AS running_total\nFROM orders\nWHERE status = 'paid'\nORDER BY placed_on, id",
  ordered: true,
  explanation: "`sum(...) OVER (ORDER BY ...)` accumulates over an expanding " \
               "frame: every row sees itself plus everything ordered before it. " \
               "The WHERE runs before the window, so only paid orders are in " \
               "the frame at all — filtering afterwards would leave the " \
               "cancelled order's 999.00 baked into the totals.",
  requires: [ { label: "a window function (OVER ...)", pattern: "OVER\\s*\\(" } ],
  hints: [
    [ :nudge, "A running total is an aggregate that keeps every row. Which tool " \
              "does that?", 3 ],
    [ :concept, "`sum(total) OVER (ORDER BY ...)` sums from the start of the " \
                "window up to the current row.", 5 ],
    [ :clue, "Filter to paid orders in WHERE, before the window sees them.", 6 ],
    [ :solution, "sum(total) OVER (ORDER BY placed_on, id), with " \
                 "WHERE status = 'paid'.", 11 ]
  ]
)

sql_challenge!(
  slug: "sql-missing-dates", title: "The day nobody ordered",
  topic: a2, skill_slug: "sql-aggregation", type: :implement, difficulty: :expert, xp: 70,
  prompt: "Return every date between the first and last order (inclusive) on " \
          "which **no** order was placed, as a single column, ascending.\n\n" \
          "You cannot find a missing row by querying the rows that exist — you " \
          "have to generate the full calendar and subtract. This is the " \
          "\"gaps and islands\" problem.",
  starter: "SELECT d::date\nFROM generate_series(\n  (SELECT min(placed_on) FROM orders),\n  (SELECT max(placed_on) FROM orders),\n  interval '1 day'\n) d\n",
  solution: "SELECT d::date AS missing_date\nFROM generate_series(\n       (SELECT min(placed_on) FROM orders),\n       (SELECT max(placed_on) FROM orders),\n       interval '1 day'\n     ) d\nWHERE d::date NOT IN (SELECT placed_on FROM orders)\nORDER BY 1",
  ordered: true,
  explanation: "`generate_series` manufactures the dates that *should* exist, " \
               "then the anti-join removes the ones that do. The same shape " \
               "answers \"which hours had no traffic\" and \"which days did a " \
               "user not log in\". Watch out with NOT IN: if the subquery can " \
               "return NULL, use NOT EXISTS instead, because NOT IN with a NULL " \
               "yields no rows at all.",
  hints: [
    [ :nudge, "The missing date is not in the orders table. Where could it come " \
              "from?", 4 ],
    [ :concept, "`generate_series(start, stop, interval '1 day')` produces the " \
                "full calendar. Then remove the dates that do appear.", 6 ],
    [ :clue, "generate_series returns timestamps, so cast with `d::date` before " \
             "comparing to a date column.", 7 ],
    [ :solution, "Generate the series between min and max placed_on, then " \
                 "`WHERE d::date NOT IN (SELECT placed_on FROM orders)`.", 14 ]
  ]
)
