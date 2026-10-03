include SeedDSL
# Closes the learning loop for the SQL missions so each satisfies the
# definition of done (spec 80): a debugging challenge and an interview
# question with follow-up probes.
puts "  completing the loop for the SQL missions"

t = ->(slug) { Topic.find_by!(slug: slug) }

# ----------------------------------------------------- debugging challenges
sql_challenge!(
  slug: "sql-debug-equals-null", title: "The filter that returns nothing",
  topic: t.("select-and-where"), skill_slug: "sql-basics",
  type: :debug, difficulty: :easy, xp: 40,
  prompt: "This query should list the `name` of every employee who has **no " \
          "manager** (their `manager_id` is NULL), ordered by name.\n\n" \
          "It returns zero rows instead — no error, just nothing. Chen has no " \
          "manager, so there should be one row.\n\nFind the bug and fix it.",
  starter: "SELECT name\nFROM employees\nWHERE manager_id = NULL\nORDER BY name",
  solution: "SELECT name\nFROM employees\nWHERE manager_id IS NULL\nORDER BY name",
  ordered: true,
  explanation: "NULL means \"unknown\", and comparing anything to unknown yields " \
               "unknown — which is not true, so the row is filtered out. " \
               "`= NULL` is never true for any value, not even for NULL itself. " \
               "Testing for NULL requires `IS NULL`. This is the same rule that " \
               "silently turns a LEFT JOIN into an INNER JOIN when you filter a " \
               "right-hand column in WHERE.",
  hints: [
    [ :nudge, "There is no syntax error, so the query is valid SQL. What does " \
              "the comparison actually evaluate to?", 3 ],
    [ :concept, "In SQL, `anything = NULL` is not false — it is unknown, and only " \
                "true rows survive WHERE.", 4 ],
    [ :solution, "Use `IS NULL` instead of `= NULL`.", 8 ]
  ]
)

sql_challenge!(
  slug: "sql-debug-wrong-order-direction", title: "The lowest paid employee, allegedly",
  topic: t.("order-and-limit"), skill_slug: "sql-basics",
  type: :debug, difficulty: :easy, xp: 40,
  prompt: "This query should return the `name` and `salary` of the **lowest " \
          "paid** employee.\n\n" \
          "It returns the highest paid instead. Fix it, and make the result " \
          "deterministic so it cannot change between runs.",
  starter: "SELECT name, salary\nFROM employees\nORDER BY salary DESC\nLIMIT 1",
  solution: "SELECT name, salary\nFROM employees\nORDER BY salary ASC, name ASC\nLIMIT 1",
  ordered: true,
  explanation: "`DESC` sorts highest first, so LIMIT 1 took the top earner. " \
               "Beyond the direction, adding `name ASC` matters: several " \
               "employees share salaries in this dataset, and without a unique " \
               "tie-break the row LIMIT 1 returns is not guaranteed to be stable.",
  hints: [
    [ :nudge, "Read the ORDER BY direction against what the prompt asked for.", 2 ],
    [ :concept, "ASC is lowest-first. And a LIMIT over a non-unique sort key " \
                "needs a tie-break to be reproducible.", 4 ],
    [ :solution, "`ORDER BY salary ASC, name ASC LIMIT 1`.", 8 ]
  ]
)

sql_challenge!(
  slug: "sql-debug-aggregate-in-where", title: "Aggregate in the wrong clause",
  topic: t.("group-by-and-having"), skill_slug: "sql-aggregation",
  type: :debug, difficulty: :medium, xp: 45,
  prompt: "This query should return each department's `name` and `headcount` " \
          "for departments with **more than two** employees, ordered by " \
          "headcount descending then name.\n\n" \
          "PostgreSQL refuses to run it. Read the error, then put the condition " \
          "where it belongs.",
  starter: "SELECT d.name, count(*) AS headcount\nFROM departments d\nJOIN employees e ON e.department_id = d.id\nWHERE count(*) > 2\nGROUP BY d.name\nORDER BY headcount DESC, d.name",
  solution: "SELECT d.name, count(*) AS headcount\nFROM departments d\nJOIN employees e ON e.department_id = d.id\nGROUP BY d.name\nHAVING count(*) > 2\nORDER BY headcount DESC, d.name",
  ordered: true,
  explanation: "WHERE is evaluated before GROUP BY, so the groups — and " \
               "therefore `count(*)` — do not exist yet. HAVING runs after " \
               "grouping, which is why an aggregate condition belongs there. " \
               "The rule of thumb: WHERE filters rows, HAVING filters groups.",
  hints: [
    [ :nudge, "The error names the problem. Which clause is allowed to see an " \
              "aggregate?", 3 ],
    [ :concept, "Clause order is roughly FROM, WHERE, GROUP BY, HAVING, SELECT, " \
                "ORDER BY. WHERE comes before the groups exist.", 4 ],
    [ :solution, "Move `count(*) > 2` from WHERE into HAVING.", 9 ]
  ]
)

sql_challenge!(
  slug: "sql-debug-window-in-where", title: "Filtering on a window function",
  topic: t.("window-functions"), skill_slug: "sql-aggregation",
  type: :debug, difficulty: :hard, xp: 55,
  prompt: "This query should return each customer's `name` and the " \
          "`placed_on` date of their **most recent paid order** — one row per " \
          "customer, ordered by name.\n\n" \
          "PostgreSQL rejects it. The logic is right; the shape is not.",
  starter: "SELECT c.name, o.placed_on\nFROM orders o\nJOIN customers c ON c.id = o.customer_id\nWHERE o.status = 'paid'\n  AND row_number() OVER (PARTITION BY o.customer_id ORDER BY o.placed_on DESC, o.id DESC) = 1\nORDER BY c.name",
  solution: "WITH ranked AS (\n  SELECT customer_id, placed_on,\n         row_number() OVER (PARTITION BY customer_id ORDER BY placed_on DESC, id DESC) AS rn\n  FROM orders\n  WHERE status = 'paid'\n)\nSELECT c.name, r.placed_on\nFROM ranked r\nJOIN customers c ON c.id = r.customer_id\nWHERE r.rn = 1\nORDER BY c.name",
  ordered: true,
  explanation: "Window functions are computed after WHERE has already run, so a " \
               "window function can never appear in WHERE. The fix is structural: " \
               "compute the row number in a CTE (or subquery), then filter on it " \
               "in the outer query. `row_number()` is the right choice here " \
               "because it guarantees exactly one row per customer even when two " \
               "orders share a date — which Acme's two 2024-03-02 orders would " \
               "otherwise cause.",
  requires: [ { label: "a CTE or subquery, since a window function cannot go in WHERE",
                pattern: "WITH\\s|\\(\\s*SELECT" } ],
  hints: [
    [ :nudge, "The error is about where the window function appears, not what it " \
              "computes.", 4 ],
    [ :concept, "WHERE is evaluated before window functions, so the rank has to " \
                "be computed one level deeper and filtered outside.", 5 ],
    [ :pseudocode, "WITH ranked AS (SELECT ..., row_number() OVER (...) AS rn " \
                   "FROM orders WHERE status = 'paid') SELECT ... WHERE rn = 1", 8 ],
    [ :solution, "Wrap it in a CTE that computes `rn`, then filter `WHERE rn = 1` " \
                 "in the outer query.", 13 ]
  ]
)

# ------------------------------------------------------ interview questions
question!(
  body: "What is the difference between WHERE and HAVING, and why can't WHERE " \
        "reference an aggregate?",
  skill_slug: "sql-aggregation", type: "scenario", band: :junior, difficulty: :easy,
  topic: t.("group-by-and-having"),
  model: "WHERE filters individual rows before grouping; HAVING filters groups " \
         "after aggregation. WHERE cannot reference an aggregate because it is " \
         "evaluated before GROUP BY has produced any groups, so the aggregate " \
         "does not exist yet.",
  explanation: "The answer is really about clause evaluation order.",
  mistakes: "Saying HAVING is just \"WHERE for GROUP BY\" without explaining the " \
            "ordering, or claiming they are interchangeable.",
  answer_key: { "keywords" => [ "row", "group", "before", "after", "aggregate", "order" ],
                "required" => [ "group" ] },
  related: [ "clause evaluation order", "GROUP BY", "aggregates" ],
  follow_ups: [
    { body: "If a condition could go in either clause, which would you choose " \
            "and why?",
      trigger: "always",
      expects: [ "where", "fewer rows", "early", "cheaper", "performance" ],
      model: "WHERE, because filtering before grouping means fewer rows have to " \
             "be grouped at all. HAVING runs on data that has already been " \
             "aggregated, so it cannot reduce that work." },
    { body: "Can you use a column alias defined in SELECT inside HAVING?",
      trigger: "always",
      expects: [ "no", "select", "after", "order by" ],
      model: "Not portably — SELECT is evaluated after HAVING, so the alias does " \
             "not exist yet. ORDER BY runs later still, which is why an alias " \
             "does work there." }
  ]
)

question!(
  body: "A report must show the top earner in each department, including ties. " \
        "How would you write it, and what breaks if you use ROW_NUMBER?",
  skill_slug: "sql-aggregation", type: "architecture", band: :mid, difficulty: :hard,
  topic: t.("window-functions"), company_type: "product",
  model: "Rank within each department using RANK or DENSE_RANK in a CTE, then " \
         "filter to rank 1 in the outer query — a window function cannot go in " \
         "WHERE because it is evaluated afterwards. ROW_NUMBER would break the " \
         "requirement: it never produces a tie, so for two employees on the same " \
         "top salary it arbitrarily picks one and silently drops the other.",
  explanation: "This question tests both the top-N-per-group shape and awareness " \
               "of how the three ranking functions treat ties.",
  mistakes: "Using ROW_NUMBER and losing tied rows, or trying to filter on the " \
            "window function directly in WHERE.",
  answer_key: { "keywords" => [ "rank", "dense_rank", "cte", "subquery", "tie",
                                "row_number", "partition" ],
                "required" => [ "tie" ] },
  related: [ "window functions", "CTEs", "top-N per group" ],
  follow_ups: [
    { body: "What is the difference between RANK and DENSE_RANK here?",
      trigger: "always",
      expects: [ "gap", "skip", "consecutive" ],
      model: "After a tie RANK leaves a gap (1, 2, 2, 4) while DENSE_RANK does " \
             "not (1, 2, 2, 3). For filtering to rank 1 they behave identically; " \
             "the difference matters for \"top 3\"." },
    { body: "Why can't you just put the window function in WHERE?",
      trigger: "always",
      expects: [ "evaluated", "after", "order", "cte" ],
      model: "Window functions are computed after WHERE in the evaluation order, " \
             "so the value is not available to filter on. You need a CTE or " \
             "subquery to materialise it first." },
    { body: "How would this perform on 50 million orders?",
      trigger: "keyword", keywords: [ "performance", "fast", "slow", "scale", "index" ],
      expects: [ "sort", "index", "partition", "memory", "explain" ],
      model: "The window needs the data sorted by the partition and order keys, " \
             "so a composite index on (department_id, salary DESC) can let the " \
             "planner avoid an explicit sort. I would read EXPLAIN ANALYZE and " \
             "check whether the sort spills to disk." }
  ]
)

question!(
  body: "Why does `WHERE manager_id = NULL` return no rows instead of raising " \
        "an error?",
  skill_slug: "sql-basics", type: "output_prediction", band: :junior, difficulty: :easy,
  topic: t.("select-and-where"),
  model: "NULL represents an unknown value, so any comparison with it evaluates " \
         "to unknown rather than true or false. WHERE keeps only rows where the " \
         "condition is true, so every row is discarded. It is valid SQL, which is " \
         "why there is no error — you need IS NULL.",
  explanation: "Three-valued logic is the single most common source of silently " \
               "wrong SQL.",
  mistakes: "Expecting an error, or assuming `= NULL` behaves like `IS NULL`.",
  answer_key: { "keywords" => [ "unknown", "null", "is null", "true", "three" ],
                "required" => [ "is null" ] },
  follow_ups: [
    { body: "What does `NULL = NULL` evaluate to?",
      trigger: "always",
      expects: [ "unknown", "null", "not true" ],
      model: "Unknown, not true — which is why `IS NULL` and `IS NOT DISTINCT " \
             "FROM` exist." },
    { body: "How does this bite a NOT IN subquery?",
      trigger: "always",
      expects: [ "no rows", "null", "not exists", "empty" ],
      model: "If the subquery returns even one NULL, `NOT IN` yields unknown for " \
             "every row and the query returns nothing. `NOT EXISTS` does not have " \
             "that problem, which is why it is the safer default." }
  ]
)

question!(
  body: "Your paginated list sometimes shows the same record on two consecutive " \
        "pages. The data is not changing. What is wrong?",
  skill_slug: "sql-basics", type: "debugging", band: :mid, difficulty: :medium,
  topic: t.("order-and-limit"),
  model: "The ORDER BY is not unique, so rows that tie on the sort key have no " \
         "guaranteed order. Each query is free to order them differently, so a " \
         "row can appear on page one and again on page two. Adding a unique " \
         "tie-break column such as the primary key makes the ordering total and " \
         "the pagination stable.",
  explanation: "Unstable sort keys are the usual cause of duplicate or skipped " \
               "rows in pagination.",
  mistakes: "Blaming caching or replication lag before checking whether the sort " \
            "key is unique.",
  answer_key: { "keywords" => [ "order by", "unique", "tie", "stable", "primary key" ],
                "required" => [ "tie" ] },
  follow_ups: [
    { body: "The list is 500,000 rows deep. What is wrong with OFFSET as well?",
      trigger: "always",
      expects: [ "slow", "scan", "discard", "keyset", "seek" ],
      model: "OFFSET makes the database produce and discard every skipped row, so " \
             "deep pages get progressively slower. Keyset pagination — " \
             "`WHERE (sort_key, id) < (last_key, last_id)` — stays fast because " \
             "it seeks straight to the position." }
  ]
)
