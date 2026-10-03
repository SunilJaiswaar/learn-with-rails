include SeedDSL
# Phase 2: SQL depth. These missions use the live SQL playground, so every
# challenge here is a real query executed against the fixture dataset.
puts "  Database Dungeon: SQL basics"

mod = curriculum_module!(
  world_slug: "database-dungeon", slug: "sql-foundations", position: 1,
  name: "SQL Foundations", summary: "Asking a database a precise question."
)

# ---------------------------------------------------------------- mission 1
s1 = mission!(
  curriculum_module: mod, slug: "select-and-where", position: 1,
  name: "The shape of an answer", skill_slug: "sql-basics", minutes: 5, xp: 10,
  hook: "You need the names of everyone earning over 80,000. The table has " \
        "eight rows and six columns. Asking for all of it and filtering in " \
        "Ruby works — until the table has eight million rows.",
  summary: "SELECT chooses columns, WHERE chooses rows. Both matter.",
  blocks: [
    [ :visual, "The employees table",
      { "kind" => "tables",
        "tables" => [
          { "name" => "employees",
            "columns" => %w[id name department_id salary hired_on],
            "rows" => [ [ 1, "Chen", 1, "120000.00", "2018-01-15" ],
                        [ 2, "Priya", 1, "95000.00", "2019-03-01" ],
                        [ 3, "Wei", 1, "95000.00", "2020-07-20" ],
                        [ 4, "Aisha", 1, "78000.00", "2021-09-06" ],
                        [ 5, "Bruno", 2, "82000.00", "2019-11-11" ] ] }
        ],
        "caption" => "Eight employees in total. This is the dataset every SQL " \
                     "challenge in this world queries." } ],
    [ :prose, "Two independent choices",
      { "body" => "A query makes two separate decisions: which **columns** to " \
                  "return (SELECT) and which **rows** to return (WHERE). " \
                  "Confusing them is the root of most beginner SQL errors." } ],
    [ :code_demo, "Columns and rows",
      { "code" => "-- every column, every row\nSELECT * FROM employees;\n\n-- two columns, every row\nSELECT name, salary FROM employees;\n\n-- two columns, some rows\nSELECT name, salary\nFROM employees\nWHERE salary > 80000;\n\n-- ordered, so the answer is deterministic\nSELECT name, salary\nFROM employees\nWHERE salary > 80000\nORDER BY salary DESC;",
        "language" => "sql",
        "annotations" => [
          "`SELECT *` in application code is a habit worth losing: it breaks " \
          "when a column is added and fetches data you do not use.",
          "Without ORDER BY the database may return rows in any order.",
          "WHERE runs before ORDER BY, which is why you cannot filter on a " \
          "column alias defined in SELECT."
        ] } ],
    [ :prediction, "How many rows?",
      { "question" => "There are 8 employees. Three earn more than 80,000 " \
                      "(120000, 95000, 95000) and one earns exactly 82000. " \
                      "How many rows does `WHERE salary > 80000` return?",
        "options" => [ "3", "4", "5", "8" ],
        "answer" => 1,
        "explanation" => "Four: 120000, 95000, 95000 and 82000 are all strictly " \
                         "greater than 80000. `>` excludes equality — if you " \
                         "wanted 80000 itself you need `>=`." } ],
    [ :interactive, "Pick the right clause",
      { "kind" => "risk_spotter",
        "prompt" => "Which clause does each job?",
        "cases" => [
          { "sql" => "Return only the name and salary columns",
            "risk" => false, "why" => "SELECT — it chooses columns." },
          { "sql" => "Return only employees in department 1",
            "risk" => false, "why" => "WHERE — it chooses rows." },
          { "sql" => "Return the highest earner first",
            "risk" => true, "why" => "ORDER BY. Without it the order is undefined." },
          { "sql" => "Return at most 3 rows",
            "risk" => true, "why" => "LIMIT — and it is only meaningful with ORDER BY." }
        ] } ],
    [ :pitfall, "NULL is not a value",
      { "body" => "`WHERE manager_id = NULL` returns nothing — not an error, " \
                  "just zero rows. NULL means \"unknown\", and comparing " \
                  "anything to unknown yields unknown, which is not true. " \
                  "You must write `WHERE manager_id IS NULL`." } ],
    [ :scenario, "In production",
      { "situation" => "An export endpoint runs `SELECT * FROM employees` and " \
                       "filters in Ruby. The table grows to 2 million rows and " \
                       "the endpoint starts timing out and exhausting memory.",
        "question" => "What is the fix, and why is it not just \"add an index\"?",
        "answer" => "Push the filter into the query so the database returns only " \
                    "the rows you need. An index helps the database find them, " \
                    "but if the query still asks for all 2 million rows, Ruby " \
                    "still has to materialise 2 million objects. Reduce the " \
                    "result set first, then make the lookup fast." } ],
    [ :interview, "How this is asked",
      { "question" => "Why is `SELECT *` discouraged in application code?",
        "good_answer" => "It fetches columns you do not need, which costs I/O and " \
                         "memory; it breaks silently when the schema changes; it " \
                         "prevents index-only scans; and it makes the query's " \
                         "intent unclear to the next reader." } ],
    [ :revision, "Recall",
      { "prompt" => "Which clause chooses columns, and which chooses rows?",
        "answer" => "SELECT chooses columns; WHERE chooses rows." } ]
  ]
)

# ---------------------------------------------------------------- mission 2
s2 = mission!(
  curriculum_module: mod, slug: "order-and-limit", position: 2,
  name: "Top N, and the tie that breaks it", skill_slug: "sql-basics",
  minutes: 6, xp: 15, difficulty: :easy,
  hook: "\"Give me the top earner.\" You write ORDER BY salary DESC LIMIT 1 " \
        "and ship it. Two people earn exactly the same amount, and your report " \
        "silently picks one of them at random.",
  summary: "ORDER BY, LIMIT, and why ties make LIMIT 1 a lie.",
  blocks: [
    [ :prose, "LIMIT is not a tie-breaker",
      { "body" => "`LIMIT 1` returns one row. If two rows tie for first place, " \
                  "SQL is free to return either. The result is not wrong — your " \
                  "question was ambiguous." } ],
    [ :visual, "The tie in the data",
      { "kind" => "join_result",
        "result" => { "columns" => %w[name salary],
                      "rows" => [ [ "Chen", "120000.00" ],
                                  [ "Priya", "95000.00" ],
                                  [ "Wei", "95000.00" ],
                                  [ "Bruno", "82000.00" ] ] },
        "caption" => "Priya and Wei both earn 95,000. Any query about \"the " \
                     "second highest salary\" has to decide what that means." } ],
    [ :prediction, "Second highest: which answer?",
      { "question" => "Salaries are 120000, 95000, 95000, 82000, 78000... " \
                      "What should \"the second highest salary\" be?",
        "options" => [ "95000 — the second distinct value",
                       "95000 — the second row",
                       "82000 — skipping both 95000s",
                       "It depends on what the question means" ],
        "answer" => 3,
        "explanation" => "Both readings are defensible. \"Second highest salary\" " \
                         "usually means the second *distinct* value (95000), but " \
                         "\"the second highest paid employee\" is a different " \
                         "question. In an interview, say which you are answering." } ],
    [ :code_demo, "Three ways, three meanings",
      { "code" => "-- second distinct salary value\nSELECT DISTINCT salary\nFROM employees\nORDER BY salary DESC\nOFFSET 1 LIMIT 1;\n\n-- deterministic ordering with a tie-break\nSELECT name, salary\nFROM employees\nORDER BY salary DESC, name ASC\nLIMIT 3;\n\n-- every employee at the top salary, however many there are\nSELECT name, salary\nFROM employees\nWHERE salary = (SELECT max(salary) FROM employees);",
        "language" => "sql",
        "annotations" => [
          "OFFSET skips rows; combined with DISTINCT it walks distinct values.",
          "Adding a second ORDER BY column makes the result reproducible.",
          "The subquery form returns all tied rows, which is usually what the " \
          "business actually wanted."
        ] } ],
    [ :comparison, "LIMIT vs a subquery for \"the top\"",
      { "rows" => [
          { "aspect" => "Ties", "limit" => "Picks arbitrarily", "sub" => "Returns all tied rows" },
          { "aspect" => "Rows returned", "limit" => "Exactly N", "sub" => "However many tie" },
          { "aspect" => "Determinism", "limit" => "Only with a full ORDER BY", "sub" => "Deterministic" },
          { "aspect" => "Use when", "limit" => "You need a fixed page size",
            "sub" => "You need everyone at the extreme" }
        ],
        "columns" => { "limit" => "ORDER BY + LIMIT", "sub" => "= (SELECT max(...))" } } ],
    [ :interactive, "Make it deterministic",
      { "kind" => "query_builder",
        "prompt" => "A paginated list keeps showing the same row on page 1 and " \
                    "page 2. What is missing?",
        "answer" => "A unique tie-break column in ORDER BY, e.g. ORDER BY salary DESC, id ASC",
        "note" => "Pagination over a non-unique sort key is unstable: rows can " \
                  "appear twice or be skipped entirely between pages." } ],
    [ :pitfall, "OFFSET gets slower as it grows",
      { "body" => "`OFFSET 100000 LIMIT 20` makes the database find and discard " \
                  "100,000 rows before returning 20. For deep pagination, filter " \
                  "on the last seen key instead (`WHERE id > ?`), which stays fast." } ],
    [ :scenario, "In production",
      { "situation" => "A leaderboard uses `ORDER BY score DESC LIMIT 10`. " \
                       "Users complain that someone at rank 10 vanishes and " \
                       "reappears between refreshes without their score changing.",
        "question" => "What is happening?",
        "answer" => "Several users share that score, so the database is free to " \
                    "order them differently each time. Add a stable tie-break " \
                    "such as `ORDER BY score DESC, user_id ASC`." } ],
    [ :interview, "How this is asked",
      { "question" => "Write a query for the second highest salary. Then: what " \
                      "if two people share the highest?",
        "good_answer" => "I would clarify whether \"second highest\" means the " \
                         "second distinct value or the second employee. For the " \
                         "distinct value: SELECT DISTINCT salary ... ORDER BY " \
                         "salary DESC OFFSET 1 LIMIT 1, which naturally handles " \
                         "the tie because DISTINCT collapses it." } ],
    [ :revision, "Recall",
      { "prompt" => "Why can ORDER BY ... LIMIT 1 give a different row each run?",
        "answer" => "Because ties are unordered unless the ORDER BY includes a " \
                    "unique tie-break column." } ]
  ]
)

# --------------------------------------------------------- SQL challenges
sql_challenge!(
  slug: "sql-filter-high-earners", title: "Who earns over 80,000?",
  topic: s1, skill_slug: "sql-basics", type: :implement, difficulty: :intro, xp: 25,
  prompt: "Return the `name` and `salary` of every employee earning **more " \
          "than** 80,000.\n\n" \
          "Order by salary from highest to lowest, breaking ties by name " \
          "ascending so the result is deterministic.",
  starter: "SELECT name, salary\nFROM employees\n",
  solution: "SELECT name, salary\nFROM employees\nWHERE salary > 80000\nORDER BY salary DESC, name ASC",
  ordered: true,
  explanation: "`>` is strict, so 80,000 itself is excluded. The second ORDER BY " \
               "column matters: Priya and Wei both earn 95,000, and without a " \
               "tie-break the database may return them in either order.",
  hints: [
    [ :nudge, "Two clauses: one to choose the rows, one to order them.", 2 ],
    [ :concept, "\"More than\" is `>`, not `>=`. And ties need a second ORDER BY " \
                "column to be reproducible.", 3 ],
    [ :solution, "SELECT name, salary FROM employees WHERE salary > 80000 " \
                 "ORDER BY salary DESC, name ASC", 7 ]
  ]
)

sql_challenge!(
  slug: "sql-second-highest-salary", title: "The second highest salary",
  topic: s2, skill_slug: "sql-basics", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Return a single column, `salary`, containing the **second highest " \
          "distinct** salary.\n\n" \
          "Two employees tie at 95,000, so a naive \"skip one row\" answer gets " \
          "this wrong. Think in terms of distinct *values*, not rows.",
  starter: "SELECT salary\nFROM employees\n",
  solution: "SELECT DISTINCT salary\nFROM employees\nORDER BY salary DESC\nOFFSET 1 LIMIT 1",
  # On this dataset `OFFSET 1 LIMIT 1` without DISTINCT happens to return the
  # right number, so the challenge insists on the construct that makes the
  # answer correct in general rather than correct by luck.
  requires: [ { label: "DISTINCT, so a tie at the top cannot fool the query",
                pattern: "DISTINCT" } ],
  explanation: "DISTINCT collapses the tie, so OFFSET 1 skips one distinct value " \
               "rather than one row. Without DISTINCT you would skip Chen's " \
               "120,000 and land on the *first* 95,000 — right answer by luck, " \
               "and wrong the moment the top salary is shared.",
  hints: [
    [ :nudge, "If you order rows and skip one, which row do you land on when two " \
              "people share a salary?", 3 ],
    [ :concept, "You want distinct salary *values*, then skip the first.", 4 ],
    [ :pseudocode, "SELECT DISTINCT salary ... ORDER BY salary DESC ... skip 1, take 1", 5 ],
    [ :solution, "Use `OFFSET 1 LIMIT 1` after `SELECT DISTINCT salary ORDER BY " \
                 "salary DESC`.", 9 ]
  ]
)

sql_challenge!(
  slug: "sql-customers-never-ordered", title: "Customers who never ordered",
  topic: s1, skill_slug: "sql-basics", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Return the `name` of every customer who has **never** placed an " \
          "order, ordered by name.\n\n" \
          "This is the anti-join from the joins module, written for real.",
  starter: "SELECT c.name\nFROM customers c\n",
  solution: "SELECT c.name\nFROM customers c\nLEFT JOIN orders o ON o.customer_id = c.id\nWHERE o.id IS NULL\nORDER BY c.name",
  ordered: true,
  explanation: "The LEFT JOIN keeps every customer, then `o.id IS NULL` keeps " \
               "only the ones the join could not match. `NOT EXISTS` expresses " \
               "the same thing and is often clearer.",
  hints: [
    [ :nudge, "An INNER JOIN can only ever return customers who *do* have " \
              "orders. Which join keeps the others?", 3 ],
    [ :concept, "Keep everyone with a LEFT JOIN, then filter to the rows where " \
                "the order side came back NULL.", 4 ],
    [ :solution, "LEFT JOIN orders, then `WHERE o.id IS NULL`. Remember NULL " \
                 "needs `IS NULL`, never `= NULL`.", 8 ]
  ]
)
