# The spec's worked example (section 5): "Learn SQL joins" broken into eight
# micro-missions plus a boss battle.
include SeedDSL
puts "  Database Dungeon: joins"

mod = curriculum_module!(
  world_slug: "database-dungeon", slug: "joins-module", position: 2,
  name: "Joins", summary: "Two tables meet, and everything that can go wrong."
)

# ---------------------------------------------------------------- mission 1
m1 = mission!(
  curriculum_module: mod, slug: "two-tables-meet", position: 1,
  name: "Two tables meet", skill_slug: "sql-joins", minutes: 4, xp: 10,
  hook: "You have customers in one table and orders in another. " \
        "Your report needs the customer's name next to the order total. " \
        "Neither table alone can answer that.",
  summary: "Why joins exist at all, before any syntax.",
  blocks: [
    [ :visual, "The two tables",
      { "kind" => "tables",
        "tables" => [
          { "name" => "customers",
            "columns" => %w[id name],
            "rows" => [ [ 1, "Asha" ], [ 2, "Bruno" ], [ 3, "Chen" ] ] },
          { "name" => "orders",
            "columns" => %w[id customer_id total],
            "rows" => [ [ 10, 1, 250 ], [ 11, 1, 90 ], [ 12, 2, 400 ] ] }
        ],
        "caption" => "orders.customer_id points at customers.id. That pointer is the join." } ],
    [ :prose, "The idea in one line",
      { "body" => "A join matches rows from one table with rows from another " \
                  "using a condition you supply. Nothing more mysterious than that." } ],
    [ :prediction, "Before any syntax",
      { "question" => "Chen (id 3) has no rows in orders. If you ask for " \
                      "\"every customer with their orders\", how many rows " \
                      "should mention Chen?",
        "options" => [
          "Zero — Chen has no orders",
          "One — Chen appears once with empty order columns",
          "Three — one per order in the table"
        ],
        "answer" => 1,
        "explanation" => "It depends on which join you ask for, and that is the " \
                         "whole lesson. An INNER JOIN drops Chen entirely. " \
                         "A LEFT JOIN keeps Chen once, with NULLs where the " \
                         "order columns would be." } ],
    [ :interactive, "Match them by hand",
      { "kind" => "pair_matching",
        "prompt" => "Pair each order with its customer using customer_id.",
        "left" => [ "order 10 (customer_id 1)", "order 11 (customer_id 1)",
                    "order 12 (customer_id 2)" ],
        "right" => [ "Asha (id 1)", "Asha (id 1)", "Bruno (id 2)" ],
        "note" => "Notice Asha appears twice. One customer, two orders — that is " \
                  "where join duplicates come from." } ],
    [ :scenario, "In production",
      { "situation" => "A teammate exports \"all customers\" by joining to orders, " \
                       "then emails the list to the sales team.",
        "question" => "Sales complains that 400 customers are missing. What happened?",
        "answer" => "They used an INNER JOIN, so every customer who has never " \
                    "ordered vanished from the export. Customers with no orders " \
                    "are exactly the ones sales wanted to call." } ],
    [ :interview, "How this is asked",
      { "question" => "What is a JOIN, and what decides how many rows come back?",
        "good_answer" => "A join matches rows across tables on a condition. The " \
                         "row count is driven by how many matches each row finds: " \
                         "one-to-many matches multiply rows, and the join type " \
                         "decides whether unmatched rows survive." } ],
    [ :revision, "Recall",
      { "prompt" => "Without looking: what are the two things a join needs?",
        "answer" => "A second table, and a condition that says which rows correspond." } ]
  ]
)

# ---------------------------------------------------------------- mission 2
m2 = mission!(
  curriculum_module: mod, slug: "inner-join", position: 2,
  name: "INNER JOIN", skill_slug: "sql-joins", minutes: 6, xp: 10, difficulty: :easy,
  hook: "You join customers to orders and get 3 rows back from a 3-customer " \
        "table. Looks right. It is not.",
  summary: "The join that keeps only matches — and silently drops everything else.",
  blocks: [
    [ :code_demo, "The query",
      { "code" => "SELECT c.name, o.total\nFROM customers c\nINNER JOIN orders o\n  ON o.customer_id = c.id;",
        "language" => "sql",
        "annotations" => [
          "FROM names the left table.",
          "INNER JOIN names the right table.",
          "ON is the condition. Without it you get a cross join."
        ] } ],
    [ :visual, "What survives",
      { "kind" => "join_result",
        "result" => { "columns" => %w[name total],
                      "rows" => [ [ "Asha", 250 ], [ "Asha", 90 ], [ "Bruno", 400 ] ] },
        "dropped" => [ "Chen — no matching order" ],
        "caption" => "Asha appears twice because she has two orders. " \
                     "Chen is gone because INNER keeps only matches." } ],
    [ :prose, "The rule",
      { "body" => "INNER JOIN returns a row only where the condition is true on " \
                  "both sides. An unmatched row on either side is dropped with no " \
                  "warning and no NULL to hint that it happened." } ],
    [ :prediction, "Count the rows",
      { "question" => "customers has 3 rows. orders has 3 rows. How many rows does " \
                      "the INNER JOIN above return?",
        "options" => [ "3", "4", "6", "9" ],
        "answer" => 0,
        "explanation" => "Three: one per order that found a customer. The count " \
                         "follows the matches, not the table sizes. Chen " \
                         "contributes nothing." } ],
    [ :pitfall, "The silent data loss",
      { "body" => "This is the single most common SQL reporting bug: using INNER " \
                  "JOIN for a report that is supposed to list everything. The " \
                  "query runs, returns rows, and quietly omits the records with no " \
                  "match. Nothing errors, so nobody notices until a number is wrong." } ],
    [ :scenario, "In production",
      { "situation" => "A revenue dashboard INNER JOINs orders to payments. " \
                       "Finance reports revenue is understated by 8%.",
        "question" => "Where would you look first?",
        "answer" => "Orders with no payment row — refunds, pending captures or " \
                    "failed webhook writes. The INNER JOIN dropped them. " \
                    "A LEFT JOIN plus an explicit filter would have exposed them." } ],
    [ :interview, "How this is asked",
      { "question" => "When would an INNER JOIN lose data you wanted?",
        "good_answer" => "Whenever the report is about the left table rather than " \
                         "the intersection: customers without orders, products " \
                         "never sold, users who never logged in." } ],
    [ :revision, "Recall",
      { "prompt" => "An INNER JOIN returned fewer rows than you expected. " \
                    "What is the first thing to check?",
        "answer" => "Which rows failed the ON condition and were therefore dropped." } ]
  ]
)

# ---------------------------------------------------------------- mission 3
m3 = mission!(
  curriculum_module: mod, slug: "left-join", position: 3,
  name: "LEFT JOIN and why NULL appears", skill_slug: "sql-joins",
  minutes: 7, xp: 15, difficulty: :easy,
  hook: "You switch to LEFT JOIN to keep every customer. Now Chen is back — " \
        "but his total is NULL, and SUM gives you a number you did not expect.",
  summary: "Keeping unmatched rows, and handling the NULLs that come with them.",
  blocks: [
    [ :code_demo, "Keep every customer",
      { "code" => "SELECT c.name, o.total\nFROM customers c\nLEFT JOIN orders o\n  ON o.customer_id = c.id;",
        "language" => "sql",
        "annotations" => [ "LEFT keeps every row of the left table.",
                           "Unmatched right-hand columns become NULL." ] } ],
    [ :visual, "Now with NULLs",
      { "kind" => "join_result",
        "result" => { "columns" => %w[name total],
                      "rows" => [ [ "Asha", 250 ], [ "Asha", 90 ],
                                  [ "Bruno", 400 ], [ "Chen", nil ] ] },
        "caption" => "Chen survives with total = NULL. The NULL is not missing " \
                     "data — it is the join telling you there was no match." } ],
    [ :prose, "Where the NULL comes from",
      { "body" => "The NULL is manufactured by the join itself. There is no row in " \
                  "orders for Chen, so SQL invents one filled with NULL to keep " \
                  "Chen's row intact." } ],
    [ :prediction, "The aggregate trap",
      { "question" => "You now run COUNT(o.id) and COUNT(*) grouped by customer. " \
                      "For Chen, what do they return?",
        "options" => [
          "Both return 0",
          "Both return 1",
          "COUNT(o.id) returns 0 and COUNT(*) returns 1",
          "COUNT(o.id) returns 1 and COUNT(*) returns 0"
        ],
        "answer" => 2,
        "explanation" => "COUNT(*) counts rows, and Chen has one row — so 1. " \
                         "COUNT(o.id) counts non-NULL values of o.id, and Chen's " \
                         "is NULL — so 0. This is why \"customers with zero " \
                         "orders\" reports are so often wrong by one." } ],
    [ :comparison, "INNER vs LEFT",
      { "rows" => [
          { "aspect" => "Unmatched left rows", "inner" => "Dropped", "left" => "Kept, with NULLs" },
          { "aspect" => "Row count", "inner" => "Matches only", "left" => "At least one per left row" },
          { "aspect" => "Right for", "inner" => "The intersection", "left" => "A report about the left table" },
          { "aspect" => "Risk", "inner" => "Silent data loss", "left" => "NULL handling in aggregates" }
        ],
        "columns" => { "inner" => "INNER JOIN", "left" => "LEFT JOIN" } } ],
    [ :interactive, "Find the ones with nothing",
      { "kind" => "query_builder",
        "prompt" => "How do you list only the customers who have never ordered?",
        "answer" => "LEFT JOIN orders, then WHERE o.id IS NULL",
        "note" => "This is the anti-join. The LEFT JOIN keeps everyone, then the " \
                  "IS NULL filter keeps only the rows the join could not match." } ],
    [ :scenario, "In production",
      { "situation" => "A churn report LEFT JOINs users to subscriptions and filters " \
                       "WHERE s.cancelled_at IS NULL to find active users. " \
                       "It is counting users who never subscribed as active.",
        "question" => "Why, and how would you fix it?",
        "answer" => "Users with no subscription row also have a NULL cancelled_at, " \
                    "so they pass the filter. Fix it by requiring the subscription " \
                    "to exist: add s.id IS NOT NULL, or move the condition into " \
                    "the ON clause and use INNER JOIN." } ],
    [ :interview, "How this is asked",
      { "question" => "What is the difference between putting a condition in the ON " \
                      "clause and putting it in WHERE, for a LEFT JOIN?",
        "good_answer" => "In ON, the condition decides what counts as a match, and " \
                         "unmatched left rows still survive with NULLs. In WHERE, " \
                         "it filters after the join, so a condition on a " \
                         "right-hand column discards the NULL rows and quietly " \
                         "turns the LEFT JOIN into an INNER JOIN." } ],
    [ :revision, "Recall",
      { "prompt" => "Why does a WHERE on a right-table column break a LEFT JOIN?",
        "answer" => "Because NULL fails the comparison, so every unmatched row is " \
                    "filtered out and the join behaves as INNER." } ]
  ]
)

# ---------------------------------------------------------------- mission 4
m4 = mission!(
  curriculum_module: mod, slug: "join-duplicates", position: 4,
  name: "Join duplicates", skill_slug: "sql-joins", minutes: 7, xp: 15,
  difficulty: :medium,
  hook: "Your revenue total is exactly double the real figure. " \
        "The query looks correct. The join is lying to you.",
  summary: "Why one-to-many joins multiply rows, and what that does to SUM.",
  blocks: [
    [ :visual, "One row becomes many",
      { "kind" => "fan_out",
        "left" => "order 10 (total 250)",
        "right" => [ "item A", "item B" ],
        "caption" => "Joining orders to order_items duplicates the order row once " \
                     "per item. order.total is now repeated twice." } ],
    [ :prose, "The multiplication rule",
      { "body" => "A join does not add columns to a row — it produces one row per " \
                  "matching pair. If a left row matches three right rows, every " \
                  "left-hand value appears three times." } ],
    [ :prediction, "What does SUM do?",
      { "question" => "order 10 has total 250 and two items. You run " \
                      "SUM(o.total) over the joined rows. What comes back?",
        "options" => [ "250", "500", "750", "NULL" ],
        "answer" => 1,
        "explanation" => "500. The join repeated order 10 twice, so SUM added 250 " \
                         "twice. The number is wrong even though both tables are " \
                         "correct — the duplication came from the join." } ],
    [ :pitfall, "Why this is so dangerous",
      { "body" => "Double-counting produces a plausible number, not an error. " \
                  "A total that is 2x or 1.4x off looks like a business change, " \
                  "so it survives review. Any time you SUM a column from the " \
                  "\"one\" side of a one-to-many join, suspect this first." } ],
    [ :comparison, "Three ways to fix it",
      { "rows" => [
          { "aspect" => "Aggregate first, then join",
            "how" => "Subquery or CTE that sums items per order",
            "when" => "Best default: correct and readable" },
          { "aspect" => "SUM(DISTINCT ...)",
            "how" => "Only works if values happen to be unique",
            "when" => "Rarely — two orders of 250 would collapse to one" },
          { "aspect" => "Count on the many side only",
            "how" => "COUNT(DISTINCT o.id)",
            "when" => "When you want cardinality, not a sum" }
        ],
        "columns" => { "how" => "How", "when" => "When to use" } } ],
    [ :interactive, "Spot the risk",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these joins can multiply rows?",
        "cases" => [
          { "sql" => "users JOIN profiles ON profiles.user_id = users.id (one profile per user)",
            "risk" => false, "why" => "One-to-one: no multiplication." },
          { "sql" => "orders JOIN order_items ON items.order_id = orders.id",
            "risk" => true, "why" => "One-to-many: one order, many items." },
          { "sql" => "orders JOIN customers ON customers.id = orders.customer_id",
            "risk" => false, "why" => "Many-to-one: each order has one customer." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A nightly job reports gross merchandise value by joining " \
                       "orders, order_items and shipments, then SUM(orders.total). " \
                       "GMV jumped 60% overnight with no traffic change.",
        "question" => "What is your first hypothesis?",
        "answer" => "Someone shipped orders in multiple parcels, so the shipments " \
                    "join now fans out further and multiplies order totals again. " \
                    "Aggregate each child table separately before joining." } ],
    [ :interview, "How this is asked",
      { "question" => "Your SUM is too high after adding a join. Walk me through " \
                      "how you would confirm the cause.",
        "good_answer" => "Compare COUNT(*) before and after the join; if it grew, " \
                         "the join fanned out. Then group by the left key and look " \
                         "for keys with more than one row. Fix by aggregating the " \
                         "many side in a subquery or CTE before joining." } ],
    [ :revision, "Recall",
      { "prompt" => "You added a join and a total went up. What is the mechanism?",
        "answer" => "Row multiplication from a one-to-many match, which repeats " \
                    "the left-hand value once per child row." } ]
  ]
)

# --------------------------------------------------------------- challenges
# The join concepts are exercised in Ruby so they run in the sandbox: the
# learner implements the join semantics by hand, which is a sharper test of
# understanding than writing SQL a grader string-matches.
challenge!(
  slug: "implement-inner-join", title: "Implement INNER JOIN by hand",
  topic: m2, skill_slug: "sql-joins", type: :implement, difficulty: :easy, xp: 30,
  prompt: "Write `inner_join(customers, orders)`.\n\n" \
          "Each customer is a hash `{ id:, name: }`. Each order is " \
          "`{ id:, customer_id:, total: }`.\n\n" \
          "Return an array of `[name, total]` pairs — one per order that has a " \
          "matching customer, in the order the orders appear. " \
          "Orders whose customer_id matches nothing are dropped, which is " \
          "exactly what INNER JOIN does.",
  starter: "def inner_join(customers, orders)\n  # Your code here\nend\n",
  solution: "def inner_join(customers, orders)\n" \
            "  by_id = customers.to_h { |c| [c[:id], c] }\n" \
            "  orders.filter_map do |order|\n" \
            "    customer = by_id[order[:customer_id]]\n" \
            "    [customer[:name], order[:total]] if customer\n" \
            "  end\nend\n",
  explanation: "Indexing the customers by id first turns the lookup from O(n) " \
               "into O(1), making the whole join O(n + m) instead of O(n*m). " \
               "That is exactly the hash join a database planner chooses.",
  metadata: { "target_complexity" => "O(n + m)" },
  tests: [
    [ "matches orders to customers",
      "inner_join([{id: 1, name: 'Asha'}, {id: 2, name: 'Bruno'}], " \
      "[{id: 10, customer_id: 1, total: 250}, {id: 11, customer_id: 2, total: 400}])",
      '[["Asha", 250], ["Bruno", 400]]' ],
    [ "repeats a customer with two orders",
      "inner_join([{id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1, total: 250}, {id: 11, customer_id: 1, total: 90}])",
      '[["Asha", 250], ["Asha", 90]]' ],
    [ "drops customers with no orders",
      "inner_join([{id: 1, name: 'Asha'}, {id: 3, name: 'Chen'}], " \
      "[{id: 10, customer_id: 1, total: 250}])",
      '[["Asha", 250]]' ],
    [ "drops orphan orders",
      "inner_join([{id: 1, name: 'Asha'}], [{id: 99, customer_id: 42, total: 10}])",
      "[]" ],
    [ "handles empty input", "inner_join([], [])", "[]", true ]
  ],
  hints: [
    [ :nudge, "You need to find a customer by id for each order. " \
              "What is the fastest way to look something up by key?", 2 ],
    [ :concept, "Scanning the customers array for every order is O(n*m). " \
                "A Hash keyed by id makes each lookup O(1).", 3 ],
    [ :pseudocode, "by_id = customers.to_h { |c| [c[:id], c] }\n" \
                   "then for each order, look up by_id[order[:customer_id]]\n" \
                   "keep the pair only when the lookup found something", 5 ],
    [ :solution, "Use `filter_map`: it maps and drops nils in one pass, which is " \
                 "precisely \"keep only the matches\".", 8 ]
  ]
)

challenge!(
  slug: "debug-left-join-count", title: "The report says zero customers churned",
  topic: m3, skill_slug: "sql-joins", type: :debug, difficulty: :medium, xp: 50,
  prompt: "This function should count how many customers have **no** orders.\n\n" \
          "It returns 0 for every input, even when customers clearly have no " \
          "orders. The LEFT JOIN semantics are modelled correctly — the bug is " \
          "in how the unmatched rows are detected.\n\n" \
          "Find it and fix it.",
  starter: "def customers_with_no_orders(customers, orders)\n" \
           "  joined = customers.map do |customer|\n" \
           "    matches = orders.select { |o| o[:customer_id] == customer[:id] }\n" \
           "    if matches.empty?\n" \
           "      { name: customer[:name], order_id: nil }\n" \
           "    else\n" \
           "      { name: customer[:name], order_id: matches.first[:id] }\n" \
           "    end\n" \
           "  end\n\n" \
           "  # Intended: keep the rows the join could not match.\n" \
           "  joined.count { |row| row[:order_id] == nil.to_s }\n" \
           "end\n",
  solution: "def customers_with_no_orders(customers, orders)\n" \
            "  joined = customers.map do |customer|\n" \
            "    matches = orders.select { |o| o[:customer_id] == customer[:id] }\n" \
            "    { name: customer[:name], order_id: matches.first&.fetch(:id) }\n" \
            "  end\n" \
            "  joined.count { |row| row[:order_id].nil? }\n" \
            "end\n",
  explanation: "`nil.to_s` is the empty string `\"\"`, and `nil == \"\"` is false, " \
               "so the filter never matched. This is the Ruby echo of the SQL rule " \
               "that you must test NULL with `IS NULL`, never with `= NULL` — " \
               "a comparison against NULL is never true.",
  tests: [
    [ "counts the one customer with no orders",
      "customers_with_no_orders([{id: 1, name: 'Asha'}, {id: 3, name: 'Chen'}], " \
      "[{id: 10, customer_id: 1, total: 250}])", "1" ],
    [ "returns 0 when everyone has ordered",
      "customers_with_no_orders([{id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1, total: 250}])", "0" ],
    [ "counts all when nobody has ordered",
      "customers_with_no_orders([{id: 1, name: 'Asha'}, {id: 2, name: 'Bruno'}], [])",
      "2" ],
    [ "handles no customers", "customers_with_no_orders([], [])", "0", true ]
  ],
  hints: [
    [ :nudge, "The join logic is fine. Print the `joined` array and compare it " \
              "with what the final `count` is actually testing for.", 2 ],
    [ :concept, "What is the value of `nil.to_s`? And is it equal to `nil`?", 4 ],
    [ :solution, "`nil.to_s` is `\"\"`. Test for nil directly with `.nil?`.", 8 ]
  ]
)

challenge!(
  slug: "optimize-join-duplicates", title: "The revenue total is double",
  topic: m4, skill_slug: "sql-joins", type: :optimize, difficulty: :hard, xp: 60,
  prompt: "`total_revenue(orders, items)` should return the sum of each order's " \
          "total, counted **once** per order.\n\n" \
          "The current version joins orders to items first and then sums, so an " \
          "order with three items contributes its total three times.\n\n" \
          "Return the correct total. Only orders that have at least one item " \
          "should be counted — an order with no items has not shipped anything.",
  starter: "def total_revenue(orders, items)\n" \
           "  joined = orders.flat_map do |order|\n" \
           "    items.select { |i| i[:order_id] == order[:id] }\n" \
           "         .map { |item| { total: order[:total], item: item[:id] } }\n" \
           "  end\n" \
           "  joined.sum { |row| row[:total] }\n" \
           "end\n",
  solution: "def total_revenue(orders, items)\n" \
            "  order_ids_with_items = items.map { |i| i[:order_id] }.to_set\n" \
            "  orders.sum { |order| order_ids_with_items.include?(order[:id]) ? order[:total] : 0 }\n" \
            "end\n",
  explanation: "The fix is to stop summing across the fanned-out rows. Decide " \
               "which orders qualify, then sum each order exactly once. " \
               "In SQL this is the difference between SUM over a joined result " \
               "and `WHERE EXISTS (SELECT 1 FROM items ...)`.",
  metadata: { "target_complexity" => "O(n + m)" },
  tests: [
    [ "counts an order with two items once",
      "total_revenue([{id: 10, total: 250}], " \
      "[{id: 1, order_id: 10}, {id: 2, order_id: 10}])", "250" ],
    [ "sums two orders once each",
      "total_revenue([{id: 10, total: 250}, {id: 11, total: 100}], " \
      "[{id: 1, order_id: 10}, {id: 2, order_id: 10}, {id: 3, order_id: 11}])", "350" ],
    [ "excludes orders with no items",
      "total_revenue([{id: 10, total: 250}, {id: 12, total: 999}], " \
      "[{id: 1, order_id: 10}])", "250" ],
    [ "returns 0 when there are no items",
      "total_revenue([{id: 10, total: 250}], [])", "0" ],
    [ "handles duplicate item rows for the same order",
      "total_revenue([{id: 10, total: 50}], " \
      "[{id: 1, order_id: 10}, {id: 2, order_id: 10}, {id: 3, order_id: 10}])", "50", true ]
  ],
  hints: [
    [ :nudge, "Ask what the unit of your sum is. You want one addend per order, " \
              "but the joined array has one row per item.", 3 ],
    [ :concept, "Invert the problem: instead of walking the join, walk the orders " \
                "and ask \"does this order have any items?\"", 4 ],
    [ :pseudocode, "ids = Set of items' order_id values\n" \
                   "sum order[:total] for orders whose id is in ids", 6 ],
    [ :solution, "A Set of order ids with items gives O(1) membership, so the whole " \
                 "thing is one pass over each array.", 10 ]
  ]
)

# ---------------------------------------------------------------- questions
question!(
  body: "What is the difference between an INNER JOIN and a LEFT JOIN?",
  skill_slug: "sql-joins", type: "scenario", band: :junior, difficulty: :easy,
  topic: m3,
  model: "An INNER JOIN returns only rows where the ON condition matched on both " \
         "sides. A LEFT JOIN returns every row from the left table, filling the " \
         "right-hand columns with NULL where there was no match.",
  explanation: "The distinction matters most for reports about the left table: " \
               "customers with no orders, products never sold.",
  mistakes: "Saying LEFT JOIN is \"just slower\", or forgetting that unmatched " \
            "rows produce NULLs that then break aggregates and WHERE clauses.",
  answer_key: { "keywords" => [ "inner", "left", "null", "unmatched", "match" ],
                "required" => [ "null" ] },
  related: [ "NULL semantics", "anti-join", "aggregate functions" ],
  follow_ups: [
    { body: "You said unmatched rows become NULL. What happens if you then add " \
            "`WHERE orders.status = 'paid'` to that LEFT JOIN?",
      trigger: "always",
      expects: [ "inner", "filter", "null", "discard" ],
      model: "The NULL rows fail the comparison and are filtered out, so the " \
             "LEFT JOIN silently behaves like an INNER JOIN. The condition " \
             "belongs in the ON clause if you want to keep unmatched rows.",
      children: [
        { body: "So how would you write it to keep every customer but only count " \
                "their paid orders?",
          trigger: "always",
          expects: [ "on", "condition", "left" ],
          model: "Move the status condition into the ON clause: " \
                 "LEFT JOIN orders o ON o.customer_id = c.id AND o.status = 'paid'." }
      ] },
    { body: "How would you list only the customers who have never placed an order?",
      trigger: "always",
      expects: [ "is null", "left join", "not exists", "anti" ],
      model: "LEFT JOIN orders and filter WHERE orders.id IS NULL, or use " \
             "NOT EXISTS. Both express an anti-join." },
    { body: "You mentioned performance. Which of the two is actually more " \
            "expensive, and why?",
      trigger: "keyword", keywords: [ "slow", "fast", "performance", "expensive" ],
      expects: [ "depends", "planner", "rows", "index" ],
      model: "Neither is inherently faster. The planner picks a strategy from " \
             "statistics; a LEFT JOIN simply cannot reduce the left row count, " \
             "so it may do more work. Read EXPLAIN rather than guessing." }
  ]
)

question!(
  body: "Your revenue report shows exactly double the expected total after " \
        "someone added a join to the line items table. Why, and how do you fix it?",
  skill_slug: "sql-joins", type: "debugging", band: :mid, difficulty: :hard,
  topic: m4, company_type: "product", interview_type: "technical",
  model: "The one-to-many join fans out each order into one row per line item, so " \
         "SUM(orders.total) adds the same total once per item. Fix it by " \
         "aggregating the line items in a subquery or CTE before joining, or by " \
         "summing a column that genuinely belongs to the many side.",
  explanation: "Row multiplication is the mechanism behind almost every " \
               "'the number is too big' reporting bug.",
  mistakes: "Reaching for SELECT DISTINCT or SUM(DISTINCT total), which happens " \
            "to work on sample data but collapses genuinely equal values.",
  answer_key: { "keywords" => [ "duplicate", "one-to-many", "fan", "subquery",
                                "cte", "aggregate", "multiply" ],
                "required" => [ "duplicate" ] },
  related: [ "GROUP BY", "CTEs", "cardinality" ],
  follow_ups: [
    { body: "You suggested DISTINCT. What breaks if two different orders both " \
            "total exactly 250?",
      trigger: "keyword", keywords: [ "distinct" ],
      expects: [ "collapse", "lose", "same value", "undercount" ],
      model: "SUM(DISTINCT total) would count 250 once, undercounting. DISTINCT " \
             "deduplicates values, not rows, so it is the wrong tool." },
    { body: "How would you prove the join is the cause before changing anything?",
      trigger: "always",
      expects: [ "count", "before", "after", "group by" ],
      model: "Compare COUNT(*) with and without the join, then GROUP BY the order " \
             "id and look for keys with more than one row." },
    { body: "Write the shape of the corrected query.",
      trigger: "always",
      expects: [ "cte", "with", "subquery", "group by", "sum" ],
      model: "WITH item_totals AS (SELECT order_id, SUM(amount) AS amount FROM " \
             "order_items GROUP BY order_id) SELECT ... FROM orders o JOIN " \
             "item_totals t ON t.order_id = o.id." }
  ]
)

question!(
  body: "A LEFT JOIN query returns 1,000 rows. After you add " \
        "`AND right_table.deleted_at IS NULL` to the ON clause, it still returns " \
        "1,000 rows. Is that expected?",
  skill_slug: "sql-joins", type: "output_prediction", band: :senior, difficulty: :hard,
  topic: m3,
  model: "Yes. A condition in the ON clause only changes what counts as a match. " \
         "Rows that no longer match are kept as NULL-filled rows rather than " \
         "removed, so a LEFT JOIN's row count cannot drop below the left table's " \
         "row count.",
  explanation: "This is the clearest demonstration that ON filters matches while " \
               "WHERE filters results.",
  answer_key: { "keywords" => [ "yes", "on", "match", "null", "left", "row count" ],
                "required" => [ "null" ] },
  follow_ups: [
    { body: "What would the row count have been if you had put that condition in " \
            "WHERE instead?",
      trigger: "always",
      expects: [ "fewer", "inner", "filter", "drop" ],
      model: "Fewer rows: WHERE runs after the join and discards the NULL rows, " \
             "collapsing it into an INNER JOIN." }
  ]
)
