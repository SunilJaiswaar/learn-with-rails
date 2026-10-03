include SeedDSL
# Closes the learning loop for every mission so each one satisfies the
# definition of done (spec 80): explanation, visual, interactive, prediction,
# coding challenge, debugging challenge, scenario, interview question,
# follow-up, revision and a mastery target.
puts "  completing the learning loop for every mission"

t = ->(slug) { Topic.find_by!(slug: slug) }

# --------------------------------------------------- missing lesson blocks
def add_block!(topic, type, heading, payload)
  lesson = topic.lessons.ordered.first
  position = (lesson.lesson_blocks.maximum(:position) || -1) + 1
  return if lesson.lesson_blocks.exists?(block_type: type)

  LessonBlock.create!(lesson: lesson, block_type: type, heading: heading,
                      position: position, payload: payload)
end

add_block!(t.("inner-join"), :interactive, "Decide the join type",
  { "kind" => "risk_spotter",
    "prompt" => "Which join does each report need?",
    "cases" => [
      { "sql" => "Revenue per order that has at least one payment",
        "risk" => false, "why" => "INNER JOIN — you want the intersection." },
      { "sql" => "Every customer, with their order count (including zero)",
        "risk" => true, "why" => "LEFT JOIN — INNER would hide the zeroes." },
      { "sql" => "Products that have never been sold",
        "risk" => true, "why" => "LEFT JOIN plus WHERE sales.id IS NULL." }
    ] })

add_block!(t.("binary-search"), :visual, "Halving the window",
  { "kind" => "growth_table",
    "sizes" => [ "n", "comparisons" ],
    "rows" => [
      { "label" => "16", "values" => [ "16", "4" ] },
      { "label" => "1,024", "values" => [ "1,024", "10" ] },
      { "label" => "1,048,576", "values" => [ "1,048,576", "20" ] },
      { "label" => "1,000,000,000", "values" => [ "10^9", "30" ] }
    ],
    "caption" => "Every doubling of the input adds exactly one comparison." })

add_block!(t.("two-pointer-pairs"), :visual, "Why one pointer move is safe",
  { "kind" => "reference_diagram",
    "nodes" => [ { "label" => "left", "points_to" => "small end" },
                 { "label" => "right", "points_to" => "large end" } ],
    "objects" => [ { "id" => "small end", "value" => "sum too small → only left can help" },
                   { "id" => "large end", "value" => "sum too big → only right can help" } ],
    "caption" => "Sortedness means each comparison rules out a whole column or " \
                 "row of the pair matrix, so nothing is skipped." })

# ------------------------------------------------------------- challenges
challenge!(
  slug: "project-customer-names", title: "Project the matching names",
  topic: t.("two-tables-meet"), skill_slug: "sql-joins",
  type: :implement, difficulty: :intro, xp: 20,
  prompt: "Before any join syntax: write `names_with_orders(customers, orders)` " \
          "returning the **names** of customers who have at least one order, " \
          "in the order the customers appear, with no duplicates.",
  starter: "def names_with_orders(customers, orders)\n  # Your code here\nend\n",
  solution: "def names_with_orders(customers, orders)\n" \
            "  ids = orders.map { |o| o[:customer_id] }.to_set\n" \
            "  customers.select { |c| ids.include?(c[:id]) }.map { |c| c[:name] }\n" \
            "end\n",
  explanation: "Building the set of customer ids that appear in orders, then " \
               "filtering, is the semi-join a database performs for EXISTS.",
  metadata: { "target_complexity" => "O(n + m)" },
  tests: [
    [ "keeps only customers with orders",
      "names_with_orders([{id: 1, name: 'Asha'}, {id: 3, name: 'Chen'}], " \
      "[{id: 10, customer_id: 1}])", '["Asha"]' ],
    [ "does not duplicate a customer with two orders",
      "names_with_orders([{id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1}, {id: 11, customer_id: 1}])", '["Asha"]' ],
    [ "preserves customer order",
      "names_with_orders([{id: 2, name: 'Bruno'}, {id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1}, {id: 11, customer_id: 2}])", '["Bruno", "Asha"]' ],
    [ "returns empty when nobody ordered",
      "names_with_orders([{id: 1, name: 'Asha'}], [])", "[]", true ]
  ],
  hints: [
    [ :nudge, "You need to answer \"does this customer appear in orders?\" " \
              "repeatedly. Precompute it once.", 2 ],
    [ :solution, "Collect the order customer_ids into a Set, then select and map.", 6 ]
  ]
)

challenge!(
  slug: "debug-orphan-orders", title: "The orphan order crashes the report",
  topic: t.("two-tables-meet"), skill_slug: "sql-joins",
  type: :debug, difficulty: :easy, xp: 35,
  prompt: "`order_lines(customers, orders)` should return `\"name: total\"` " \
          "strings for orders whose customer exists, skipping orphan orders " \
          "(a customer_id pointing at nothing).\n\n" \
          "It raises `NoMethodError` on nil instead. Fix it.",
  starter: "def order_lines(customers, orders)\n" \
           "  by_id = customers.to_h { |c| [c[:id], c] }\n" \
           "  orders.map do |order|\n" \
           "    customer = by_id[order[:customer_id]]\n" \
           "    \"\#{customer[:name]}: \#{order[:total]}\"\n" \
           "  end\n" \
           "end\n",
  solution: "def order_lines(customers, orders)\n" \
            "  by_id = customers.to_h { |c| [c[:id], c] }\n" \
            "  orders.filter_map do |order|\n" \
            "    customer = by_id[order[:customer_id]]\n" \
            "    \"\#{customer[:name]}: \#{order[:total]}\" if customer\n" \
            "  end\n" \
            "end\n",
  explanation: "An unmatched lookup returns nil, and `nil[:name]` raises. " \
               "This is the Ruby equivalent of forgetting that an outer join " \
               "produces NULL rows you must handle.",
  tests: [
    [ "formats matched orders",
      "order_lines([{id: 1, name: 'Asha'}], [{id: 10, customer_id: 1, total: 250}])",
      '["Asha: 250"]' ],
    [ "skips orphan orders",
      "order_lines([{id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1, total: 250}, {id: 11, customer_id: 99, total: 10}])",
      '["Asha: 250"]' ],
    [ "returns empty when every order is an orphan",
      "order_lines([{id: 1, name: 'Asha'}], [{id: 11, customer_id: 99, total: 10}])",
      "[]" ],
    [ "handles no orders", "order_lines([{id: 1, name: 'A'}], [])", "[]", true ]
  ],
  hints: [
    [ :nudge, "What does `by_id[...]` return when the key is absent?", 2 ],
    [ :solution, "Guard on `customer` and use `filter_map` to drop the misses.", 6 ]
  ]
)

challenge!(
  slug: "debug-inner-join-drops", title: "The export is missing 400 customers",
  topic: t.("inner-join"), skill_slug: "sql-joins",
  type: :debug, difficulty: :easy, xp: 40,
  prompt: "`customer_report(customers, orders)` must return one row per " \
          "customer as `[name, order_count]` — including customers with zero " \
          "orders.\n\n" \
          "It currently drops anyone who has never ordered, exactly as an " \
          "INNER JOIN would. Make it behave like a LEFT JOIN.",
  starter: "def customer_report(customers, orders)\n" \
           "  orders.group_by { |o| o[:customer_id] }.map do |customer_id, group|\n" \
           "    customer = customers.find { |c| c[:id] == customer_id }\n" \
           "    [customer[:name], group.size]\n" \
           "  end\n" \
           "end\n",
  solution: "def customer_report(customers, orders)\n" \
            "  counts = orders.group_by { |o| o[:customer_id] }\n" \
            "                 .transform_values(&:size)\n" \
            "  customers.map { |c| [c[:name], counts.fetch(c[:id], 0)] }\n" \
            "end\n",
  explanation: "Driving the loop from `orders` can only ever produce customers " \
               "that have orders. Driving it from `customers` and looking the " \
               "count up — defaulting to 0 — is what LEFT JOIN does.",
  tests: [
    [ "includes customers with zero orders",
      "customer_report([{id: 1, name: 'Asha'}, {id: 3, name: 'Chen'}], " \
      "[{id: 10, customer_id: 1}])", '[["Asha", 1], ["Chen", 0]]' ],
    [ "counts multiple orders",
      "customer_report([{id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1}, {id: 11, customer_id: 1}])", '[["Asha", 2]]' ],
    [ "returns a row per customer when there are no orders",
      "customer_report([{id: 1, name: 'Asha'}, {id: 2, name: 'Bruno'}], [])",
      '[["Asha", 0], ["Bruno", 0]]' ],
    [ "preserves customer order",
      "customer_report([{id: 2, name: 'Bruno'}, {id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1}])", '[["Bruno", 0], ["Asha", 1]]', true ]
  ],
  hints: [
    [ :nudge, "Which collection are you iterating? Can it ever yield a customer " \
              "with no orders?", 3 ],
    [ :concept, "A LEFT JOIN is driven by the left table. Iterate customers.", 4 ],
    [ :solution, "Precompute counts per customer_id, then map over customers with " \
                 "`fetch(id, 0)`.", 8 ]
  ]
)

challenge!(
  slug: "left-join-with-nulls", title: "Model a LEFT JOIN, NULLs and all",
  topic: t.("left-join"), skill_slug: "sql-joins",
  type: :implement, difficulty: :medium, xp: 40,
  prompt: "Write `left_join(customers, orders)` returning `[name, total]` pairs.\n\n" \
          "Every customer must appear at least once. A customer with no orders " \
          "appears exactly once with `nil` as the total — the NULL the join " \
          "manufactures. A customer with several orders appears once per order.",
  starter: "def left_join(customers, orders)\n  # Your code here\nend\n",
  solution: "def left_join(customers, orders)\n" \
            "  grouped = orders.group_by { |o| o[:customer_id] }\n" \
            "  customers.flat_map do |customer|\n" \
            "    matches = grouped.fetch(customer[:id], [])\n" \
            "    if matches.empty?\n" \
            "      [[customer[:name], nil]]\n" \
            "    else\n" \
            "      matches.map { |order| [customer[:name], order[:total]] }\n" \
            "    end\n" \
            "  end\nend\n",
  explanation: "`flat_map` is the right shape because each customer produces a " \
               "variable number of rows: zero matches still yields one NULL row, " \
               "which is precisely the LEFT JOIN rule.",
  tests: [
    [ "emits a nil row for a customer with no orders",
      "left_join([{id: 3, name: 'Chen'}], [])", '[["Chen", nil]]' ],
    [ "emits one row per order",
      "left_join([{id: 1, name: 'Asha'}], " \
      "[{id: 10, customer_id: 1, total: 250}, {id: 11, customer_id: 1, total: 90}])",
      '[["Asha", 250], ["Asha", 90]]' ],
    [ "mixes matched and unmatched customers",
      "left_join([{id: 1, name: 'Asha'}, {id: 3, name: 'Chen'}], " \
      "[{id: 10, customer_id: 1, total: 250}])",
      '[["Asha", 250], ["Chen", nil]]' ],
    [ "ignores orphan orders",
      "left_join([{id: 1, name: 'Asha'}], [{id: 99, customer_id: 42, total: 5}])",
      '[["Asha", nil]]' ],
    [ "handles no customers", "left_join([], [])", "[]", true ]
  ],
  hints: [
    [ :nudge, "Each customer yields a different number of rows. Which Enumerable " \
              "method flattens that?", 3 ],
    [ :concept, "Group the orders by customer_id first, so each customer is one " \
                "O(1) lookup.", 4 ],
    [ :solution, "`flat_map`, returning `[[name, nil]]` when there are no matches.", 8 ]
  ]
)

challenge!(
  slug: "count-orders-per-customer", title: "COUNT(*) versus COUNT(column)",
  topic: t.("join-duplicates"), skill_slug: "sql-joins",
  type: :implement, difficulty: :medium, xp: 35,
  prompt: "Given LEFT JOIN rows as `[name, order_id]` where `order_id` may be " \
          "nil, write `counts(rows)` returning a Hash mapping each name to " \
          "`[count_star, count_order_id]`.\n\n" \
          "`count_star` counts every row for that name. `count_order_id` counts " \
          "only the rows where `order_id` is not nil — which is exactly how SQL " \
          "treats `COUNT(*)` versus `COUNT(o.id)`.",
  starter: "def counts(rows)\n  # Your code here\nend\n",
  solution: "def counts(rows)\n" \
            "  rows.group_by(&:first).transform_values do |group|\n" \
            "    [group.size, group.count { |(_name, order_id)| !order_id.nil? }]\n" \
            "  end\nend\n",
  explanation: "This is the trap from the mission in code: a customer with no " \
               "orders has one row, so COUNT(*) is 1 while COUNT(o.id) is 0. " \
               "Reports that want \"customers with zero orders\" must count the " \
               "column, not the rows.",
  tests: [
    [ "distinguishes the two counts for an unmatched customer",
      "counts([['Chen', nil]])", '{"Chen" => [1, 0]}' ],
    [ "counts matched rows equally",
      "counts([['Asha', 10], ['Asha', 11]])", '{"Asha" => [2, 2]}' ],
    [ "handles a mix",
      "counts([['Asha', 10], ['Chen', nil]])", '{"Asha" => [1, 1], "Chen" => [1, 0]}' ],
    [ "returns an empty hash for no rows", "counts([])", "{}", true ]
  ],
  hints: [
    [ :nudge, "Group by the name, then ask two different questions of each group.", 2 ],
    [ :solution, "`group_by(&:first).transform_values { |g| [g.size, g.count { ... }] }`", 6 ]
  ]
)

challenge!(
  slug: "debug-double-count-guard", title: "The guard that double-counts",
  topic: t.("join-duplicates"), skill_slug: "sql-joins",
  type: :debug, difficulty: :medium, xp: 45,
  prompt: "`unique_order_total(rows)` receives fanned-out join rows as " \
          "`[order_id, total]` — the same order appears once per line item.\n\n" \
          "It should sum each order's total exactly once. It double-counts. Fix it.",
  starter: "def unique_order_total(rows)\n" \
           "  seen = []\n" \
           "  total = 0\n" \
           "  rows.each do |order_id, amount|\n" \
           "    total += amount\n" \
           "    seen << order_id\n" \
           "  end\n" \
           "  total\n" \
           "end\n",
  solution: "def unique_order_total(rows)\n" \
            "  seen = Set.new\n" \
            "  rows.sum do |order_id, amount|\n" \
            "    next 0 unless seen.add?(order_id)\n" \
            "    amount\n" \
            "  end\nend\n",
  explanation: "`seen` was being filled but never consulted. `Set#add?` returns " \
               "nil when the element was already present, which makes " \
               "\"count this order only the first time\" a single expression.",
  tests: [
    [ "counts a duplicated order once",
      "unique_order_total([[10, 250], [10, 250]])", "250" ],
    [ "sums distinct orders",
      "unique_order_total([[10, 250], [11, 100]])", "350" ],
    [ "handles three duplicates",
      "unique_order_total([[10, 50], [10, 50], [10, 50]])", "50" ],
    [ "returns 0 for no rows", "unique_order_total([])", "0" ],
    [ "mixes duplicates and singles",
      "unique_order_total([[10, 50], [11, 20], [10, 50]])", "70", true ]
  ],
  hints: [
    [ :nudge, "`seen` is written to but never read. What was it for?", 2 ],
    [ :concept, "`Set#add?` returns nil if the value was already there — useful for " \
                "\"first time only\" logic.", 4 ],
    [ :solution, "Skip the row unless `seen.add?(order_id)` is truthy.", 8 ]
  ]
)

challenge!(
  slug: "safe-dup", title: "Copy without sharing",
  topic: t.("variables-are-labels"), skill_slug: "ruby-basics",
  type: :implement, difficulty: :easy, xp: 30,
  prompt: "Write `independent_copy(rows)` where `rows` is an array of arrays.\n\n" \
          "Return a copy such that mutating any inner array of the copy leaves " \
          "the original completely unchanged. The values themselves are integers.",
  starter: "def independent_copy(rows)\n  # Your code here\nend\n",
  solution: "def independent_copy(rows)\n  rows.map(&:dup)\nend\n",
  explanation: "`rows.dup` copies only the outer array, leaving the inner arrays " \
               "shared. Duplicating each element one level down is what makes the " \
               "copy independent — the shallow-versus-deep distinction in one line.",
  tests: [
    [ "returns equal content",
      "independent_copy([[1, 2], [3]])", "[[1, 2], [3]]" ],
    [ "mutating the copy leaves the original intact",
      "original = [[1, 2]]; copy = independent_copy(original); copy[0] << 99; original",
      "[[1, 2]]" ],
    [ "mutating the original leaves the copy intact",
      "original = [[1, 2]]; copy = independent_copy(original); original[0] << 99; copy",
      "[[1, 2]]" ],
    [ "handles an empty outer array", "independent_copy([])", "[]" ],
    [ "handles empty inner arrays", "independent_copy([[], []])", "[[], []]", true ]
  ],
  hints: [
    [ :nudge, "`rows.dup` is not enough. What are the elements, and are they " \
              "shared?", 2 ],
    [ :solution, "`rows.map(&:dup)` duplicates each inner array.", 6 ]
  ]
)

challenge!(
  slug: "debug-shared-mutation", title: "The template that remembers",
  topic: t.("variables-are-labels"), skill_slug: "ruby-basics",
  type: :debug, difficulty: :medium, xp: 45,
  prompt: "`build_response(extra)` should return the base response merged with " \
          "`extra`, without ever changing the shared `BASE` template.\n\n" \
          "Right now each call accumulates the previous call's keys — the bug " \
          "that leaks one user's data into another's response. Fix it.",
  starter: "BASE = { status: \"ok\", data: {} }\n\n" \
           "def build_response(extra)\n" \
           "  BASE.merge!(extra)\n" \
           "end\n",
  solution: "BASE = { status: \"ok\", data: {} }.freeze\n\n" \
            "def build_response(extra)\n" \
            "  BASE.merge(extra)\n" \
            "end\n",
  explanation: "`merge!` mutates the receiver, so the shared constant grows with " \
               "every request. `merge` returns a new hash. Freezing the template " \
               "turns the same mistake into an immediate error instead of a " \
               "silent data leak.",
  tests: [
    [ "merges the extra keys",
      "build_response({user: 1})", '{status: "ok", data: {}, user: 1}' ],
    [ "does not leak keys between calls",
      "build_response({user: 1}); build_response({other: 2})",
      '{status: "ok", data: {}, other: 2}' ],
    [ "leaves the template untouched",
      "build_response({user: 1}); BASE", '{status: "ok", data: {}}' ],
    [ "handles empty extra", "build_response({})", '{status: "ok", data: {}}', true ]
  ],
  hints: [
    [ :nudge, "Call it twice and inspect the second result. Where did the extra " \
              "key come from?", 2 ],
    [ :concept, "In Ruby a trailing `!` usually means \"mutates the receiver\".", 3 ],
    [ :solution, "Use `merge` instead of `merge!`, and `freeze` the constant so " \
                 "this cannot regress.", 8 ]
  ]
)

challenge!(
  slug: "sum-with-map-vs-each", title: "Return the transformed collection",
  topic: t.("each-vs-map"), skill_slug: "ruby-blocks",
  type: :implement, difficulty: :intro, xp: 25,
  prompt: "Write `labels(items)` where each item is `{name:, qty:}`.\n\n" \
          "Return an array of `\"name x qty\"` strings, in input order.",
  starter: "def labels(items)\n  # Your code here\nend\n",
  solution: "def labels(items)\n  items.map { |item| \"\#{item[:name]} x \#{item[:qty]}\" }\nend\n",
  explanation: "This is the canonical `map`: one output element per input " \
               "element. Using `each` with `<<` would work but states the intent " \
               "less directly — and returning the result of `each` by mistake is " \
               "the bug this mission is about.",
  tests: [
    [ "builds one label per item",
      "labels([{name: 'bolt', qty: 2}, {name: 'nut', qty: 5}])",
      '["bolt x 2", "nut x 5"]' ],
    [ "preserves order",
      "labels([{name: 'b', qty: 1}, {name: 'a', qty: 1}])", '["b x 1", "a x 1"]' ],
    [ "returns an empty array for no items", "labels([])", "[]" ],
    [ "handles a zero quantity", "labels([{name: 'x', qty: 0}])", '["x x 0"]', true ]
  ],
  hints: [
    [ :nudge, "One output per input, built from the block's return value. " \
              "Which method is that?", 2 ],
    [ :solution, "`items.map { |item| \"...\" }`", 5 ]
  ]
)

challenge!(
  slug: "debug-each-returns-receiver", title: "The method returns the wrong array",
  topic: t.("each-vs-map"), skill_slug: "ruby-blocks",
  type: :debug, difficulty: :easy, xp: 40,
  prompt: "`doubled(nums)` should return each number doubled. " \
          "It returns the original array instead. One word is wrong.",
  starter: "def doubled(nums)\n" \
           "  nums.each do |n|\n" \
           "    n * 2\n" \
           "  end\n" \
           "end\n",
  solution: "def doubled(nums)\n  nums.map { |n| n * 2 }\nend\n",
  explanation: "`each` returns the receiver and discards the block's value. " \
               "`map` collects it. Nothing else about the code was wrong.",
  tests: [
    [ "doubles each element", "doubled([1, 2, 3])", "[2, 4, 6]" ],
    [ "does not mutate the input", "input = [1, 2]; doubled(input); input", "[1, 2]" ],
    [ "handles negatives", "doubled([-1, 0])", "[-2, 0]" ],
    [ "returns an empty array for empty input", "doubled([])", "[]", true ]
  ],
  hints: [
    [ :nudge, "What does `each` return, regardless of what the block does?", 2 ],
    [ :solution, "Swap `each` for `map`.", 5 ]
  ]
)

challenge!(
  slug: "set-membership-speedup", title: "Replace the linear scan",
  topic: t.("why-big-o"), skill_slug: "complexity",
  type: :implement, difficulty: :easy, xp: 30,
  prompt: "Write `common(list_a, list_b)` returning the values of `list_a` that " \
          "also appear in `list_b`, in `list_a`'s order, without duplicates in " \
          "the output.\n\n" \
          "It must run in O(n + m). The naive `select` + `include?` is O(n*m) " \
          "and will time out on the hidden large test.",
  starter: "def common(list_a, list_b)\n  # Your code here\nend\n",
  solution: "def common(list_a, list_b)\n" \
            "  lookup = list_b.to_set\n" \
            "  list_a.uniq.select { |value| lookup.include?(value) }\n" \
            "end\n",
  explanation: "`Array#include?` is O(n); `Set#include?` hashes and is O(1). " \
               "Converting once outside the loop is the whole optimisation, and " \
               "it is the same fix as the six-hour reconciliation job.",
  metadata: { "target_complexity" => "O(n + m)" },
  time_limit_ms: 3000,
  tests: [
    [ "finds the common values", "common([1, 2, 3], [2, 3, 4])", "[2, 3]" ],
    [ "preserves list_a order", "common([3, 1], [1, 3])", "[3, 1]" ],
    [ "removes duplicates", "common([2, 2, 3], [2, 3])", "[2, 3]" ],
    [ "returns empty when nothing matches", "common([1], [2])", "[]" ],
    [ "is fast on 50,000 elements",
      "common((1..50_000).to_a, (25_000..75_000).to_a).size", "25001", true ]
  ],
  hints: [
    [ :nudge, "The cost is in `include?`. What data structure answers membership " \
              "in constant time?", 2 ],
    [ :concept, "Convert `list_b` to a Set once, before the loop — not inside it.", 4 ],
    [ :solution, "`lookup = list_b.to_set` then select against it.", 8 ]
  ]
)

challenge!(
  slug: "debug-quadratic-dedupe", title: "The deduplicator that times out",
  topic: t.("why-big-o"), skill_slug: "complexity",
  type: :debug, difficulty: :medium, xp: 50,
  prompt: "`dedupe(values)` returns the unique values in first-seen order. " \
          "It is correct but O(n^2), and times out on the large test.\n\n" \
          "Keep the behaviour, remove the quadratic factor.",
  starter: "def dedupe(values)\n" \
           "  result = []\n" \
           "  values.each do |value|\n" \
           "    result << value unless result.include?(value)\n" \
           "  end\n" \
           "  result\n" \
           "end\n",
  solution: "def dedupe(values)\n" \
            "  seen = Set.new\n" \
            "  values.select { |value| seen.add?(value) }\n" \
            "end\n",
  explanation: "`result.include?` rescans the growing output on every element. " \
               "A Set tracks membership in O(1), and `add?` returns nil for a " \
               "value already present, so `select` keeps exactly the first " \
               "occurrence of each.",
  metadata: { "target_complexity" => "O(n)" },
  time_limit_ms: 3000,
  tests: [
    [ "removes duplicates", "dedupe([1, 2, 1, 3])", "[1, 2, 3]" ],
    [ "preserves first-seen order", "dedupe([3, 1, 3, 2])", "[3, 1, 2]" ],
    [ "handles no duplicates", "dedupe([1, 2])", "[1, 2]" ],
    [ "handles an empty array", "dedupe([])", "[]" ],
    [ "is fast on 100,000 elements",
      "dedupe((1..100_000).to_a + (1..100_000).to_a).size", "100000", true ]
  ],
  hints: [
    [ :nudge, "`result.include?` is a scan, and `result` grows. That is the n^2.", 3 ],
    [ :concept, "Track what you have seen in a Set alongside the output.", 4 ],
    [ :solution, "`values.select { |v| seen.add?(v) }` — add? is truthy only the " \
                 "first time.", 8 ]
  ]
)

challenge!(
  slug: "binary-search-insert-point", title: "Where would it go?",
  topic: t.("binary-search"), skill_slug: "searching",
  type: :implement, difficulty: :medium, xp: 45,
  prompt: "Write `insert_point(sorted, target)` returning the index at which " \
          "`target` should be inserted to keep `sorted` sorted.\n\n" \
          "If `target` already exists, return the index of its **leftmost** " \
          "occurrence. Must run in O(log n).",
  starter: "def insert_point(sorted, target)\n  # Your code here\nend\n",
  solution: "def insert_point(sorted, target)\n" \
            "  low = 0\n" \
            "  high = sorted.length   # exclusive bound\n" \
            "  while low < high\n" \
            "    mid = (low + high) / 2\n" \
            "    if sorted[mid] < target\n" \
            "      low = mid + 1\n" \
            "    else\n" \
            "      high = mid\n" \
            "    end\n" \
            "  end\n" \
            "  low\nend\n",
  explanation: "This is the lower-bound variant. Note the bound is now " \
               "**exclusive**, so the loop is `low < high` and `high = mid` — the " \
               "opposite of the inclusive version. Mixing the two conventions is " \
               "what causes most binary-search bugs.",
  metadata: { "target_complexity" => "O(log n)" },
  tests: [
    [ "inserts in the middle", "insert_point([1, 3, 5, 7], 4)", "2" ],
    [ "inserts at the start", "insert_point([5, 7], 1)", "0" ],
    [ "inserts at the end", "insert_point([1, 3], 9)", "2" ],
    [ "returns the leftmost existing index", "insert_point([1, 3, 3, 3, 5], 3)", "1" ],
    [ "handles an empty array", "insert_point([], 4)", "0" ],
    [ "handles a single element below target", "insert_point([1], 2)", "1", true ],
    [ "handles a single element above target", "insert_point([9], 2)", "0", true ]
  ],
  hints: [
    [ :nudge, "You are not looking for equality — you are looking for the first " \
              "index whose value is not less than the target.", 3 ],
    [ :concept, "Use an exclusive upper bound: `high = length`, loop while " \
                "`low < high`, and never skip mid on the upper side.", 5 ],
    [ :pseudocode, "while low < high:\n  mid = (low + high) / 2\n" \
                   "  if a[mid] < target: low = mid + 1\n  else: high = mid\n" \
                   "return low", 7 ],
    [ :solution, "Return `low`: when the loop ends, low == high is the insert point.", 10 ]
  ]
)

challenge!(
  slug: "two-pointer-dedupe-sorted", title: "Squeeze a sorted array in place",
  topic: t.("two-pointer-pairs"), skill_slug: "arrays-strings",
  type: :implement, difficulty: :medium, xp: 45,
  prompt: "Write `compact_sorted(sorted)` returning the unique values of a " \
          "**sorted** array, in order.\n\n" \
          "Use the two-pointer idea: one pointer reads, one writes. " \
          "O(n) time, O(1) extra space beyond the result.",
  starter: "def compact_sorted(sorted)\n  # Your code here\nend\n",
  solution: "def compact_sorted(sorted)\n" \
            "  return [] if sorted.empty?\n" \
            "  result = [sorted.first]\n" \
            "  sorted.each { |value| result << value if value != result.last }\n" \
            "  result\nend\n",
  explanation: "Because the input is sorted, duplicates are adjacent, so you only " \
               "ever compare against the last value kept — no Set needed. " \
               "Sortedness is what buys the O(1) space.",
  metadata: { "target_complexity" => "O(n)" },
  tests: [
    [ "removes adjacent duplicates", "compact_sorted([1, 1, 2, 3, 3])", "[1, 2, 3]" ],
    [ "leaves a unique array unchanged", "compact_sorted([1, 2, 3])", "[1, 2, 3]" ],
    [ "collapses an all-same array", "compact_sorted([7, 7, 7])", "[7]" ],
    [ "handles an empty array", "compact_sorted([])", "[]" ],
    [ "handles a single element", "compact_sorted([4])", "[4]", true ],
    [ "handles negatives", "compact_sorted([-2, -2, 0, 1])", "[-2, 0, 1]", true ]
  ],
  hints: [
    [ :nudge, "In sorted input, where can a duplicate be relative to its twin?", 2 ],
    [ :concept, "Compare each value with the last one you decided to keep.", 4 ],
    [ :solution, "Seed the result with the first element, then append only when the " \
                 "value differs from `result.last`.", 8 ]
  ]
)

challenge!(
  slug: "debug-two-pointer-self-pair", title: "It pairs a number with itself",
  topic: t.("two-pointer-pairs"), skill_slug: "arrays-strings",
  type: :debug, difficulty: :medium, xp: 45,
  prompt: "`pair_with_sum(sorted, target)` should find two **distinct** " \
          "positions whose values sum to the target, or return nil.\n\n" \
          "For `([5], 10)` it wrongly returns `[5, 5]` — it used the single " \
          "element twice. Fix it without breaking the legitimate case where two " \
          "different positions hold equal values.",
  starter: "def pair_with_sum(sorted, target)\n" \
           "  left = 0\n" \
           "  right = sorted.length - 1\n\n" \
           "  while left <= right\n" \
           "    sum = sorted[left] + sorted[right]\n" \
           "    return [sorted[left], sorted[right]] if sum == target\n" \
           "    sum < target ? left += 1 : right -= 1\n" \
           "  end\n" \
           "  nil\n" \
           "end\n",
  solution: "def pair_with_sum(sorted, target)\n" \
            "  left = 0\n" \
            "  right = sorted.length - 1\n\n" \
            "  while left < right\n" \
            "    sum = sorted[left] + sorted[right]\n" \
            "    return [sorted[left], sorted[right]] if sum == target\n" \
            "    sum < target ? left += 1 : right -= 1\n" \
            "  end\n" \
            "  nil\n" \
            "end\n",
  explanation: "`left <= right` allows both pointers to land on the same index, " \
               "pairing an element with itself. `left < right` requires two " \
               "distinct positions — and still allows `[5, 5]` when the array " \
               "genuinely contains two fives.",
  tests: [
    [ "does not pair a single element with itself",
      "pair_with_sum([5], 10)", "nil" ],
    [ "finds a genuine pair", "pair_with_sum([2, 3, 4, 7], 11)", "[4, 7]" ],
    [ "allows two equal values at different positions",
      "pair_with_sum([5, 5], 10)", "[5, 5]" ],
    [ "returns nil when no pair sums to the target",
      "pair_with_sum([1, 2, 3], 100)", "nil" ],
    [ "handles an empty array", "pair_with_sum([], 0)", "nil", true ],
    [ "handles the middle element not being reusable",
      "pair_with_sum([1, 5, 9], 10)", "[1, 9]", true ]
  ],
  hints: [
    [ :nudge, "Trace `([5], 10)`. What are left and right on the first iteration?", 3 ],
    [ :solution, "Change the loop condition to `left < right`.", 6 ]
  ]
)

# ---------------------------------------------------------------- questions
question!(
  body: "A report must list every customer alongside their order count, " \
        "including customers who have never ordered. Which join, and what is the " \
        "trap in counting?",
  skill_slug: "sql-joins", type: "scenario", band: :junior, difficulty: :easy,
  topic: t.("two-tables-meet"),
  model: "A LEFT JOIN from customers to orders. The trap is COUNT: COUNT(*) " \
         "returns 1 for a customer with no orders because the join still " \
         "produced one NULL-filled row, so you must COUNT the order id column, " \
         "which ignores NULLs and gives 0.",
  explanation: "This single question catches both the join-type choice and NULL " \
               "semantics in aggregates.",
  mistakes: "Using INNER JOIN and silently dropping the zero-order customers, " \
            "or using COUNT(*) and reporting that everyone has at least one order.",
  answer_key: { "keywords" => [ "left", "count", "null", "zero" ],
                "required" => [ "left" ] },
  follow_ups: [
    { body: "You used COUNT(o.id). What would COUNT(*) have given for a customer " \
            "with no orders, and why?",
      trigger: "always",
      expects: [ "1", "one", "row", "null" ],
      model: "1, because COUNT(*) counts rows and the LEFT JOIN produced one row " \
             "for that customer with NULLs in the order columns." },
    { body: "Now the report must also exclude cancelled orders but still list " \
            "every customer. Where does that condition go?",
      trigger: "always",
      expects: [ "on", "clause", "not where" ],
      model: "In the ON clause. In WHERE it would discard the NULL rows and turn " \
             "the LEFT JOIN into an INNER JOIN." }
  ]
)

question!(
  body: "What is the difference between an INNER JOIN and a semi-join " \
        "(EXISTS), and when does it matter for correctness?",
  skill_slug: "sql-joins", type: "architecture", band: :mid, difficulty: :medium,
  topic: t.("inner-join"),
  model: "An INNER JOIN returns one row per matching pair, so a one-to-many match " \
         "multiplies rows. EXISTS answers a yes/no question and returns each left " \
         "row at most once. When you only want to filter, EXISTS avoids the " \
         "duplicates that would corrupt any aggregate.",
  answer_key: { "keywords" => [ "exists", "duplicate", "once", "filter", "multipl" ],
                "required" => [ "exists" ] },
  follow_ups: [
    { body: "So when would you still prefer the join?",
      trigger: "always",
      expects: [ "columns", "need data", "select", "right table" ],
      model: "When you actually need columns from the right table. EXISTS can only " \
             "filter; it cannot give you the matched row's values." }
  ]
)

question!(
  body: "Why does `Hash.new([])` behave differently from " \
        "`Hash.new { |h, k| h[k] = [] }`?",
  skill_slug: "ruby-collections", type: "output_prediction", band: :associate,
  difficulty: :medium, topic: t.("hash-default-trap"),
  model: "The value form evaluates `[]` once, so every missing key returns that " \
         "same array and mutations are shared; it also never stores the key. " \
         "The block form runs per access, creating a fresh array and assigning it, " \
         "so each key gets its own.",
  explanation: "This is reference semantics showing up in the standard library.",
  mistakes: "Believing the default is re-evaluated per key, then being surprised " \
            "that the hash is still empty after appending.",
  answer_key: { "keywords" => [ "same", "shared", "once", "block", "assign" ],
                "required" => [ "shared" ] },
  follow_ups: [
    { body: "After `h = Hash.new([]); h[:a] << 1`, what does `h` itself equal?",
      trigger: "always",
      expects: [ "empty", "{}", "no key" ],
      model: "`{}` — still empty. `h[:a]` returned the shared default and `<<` " \
             "mutated it, but nothing was ever assigned into the hash." },
    { body: "Which would you use for a counter, and why?",
      trigger: "always",
      expects: [ "hash.new(0)", "integer", "immutable", "0" ],
      model: "`Hash.new(0)`. Integers are immutable, so sharing the default is " \
             "harmless, and `+=` assigns a new value into the hash anyway." }
  ]
)

question!(
  body: "You have a sorted array of 10 million records and need one lookup. " \
        "Binary search or a hash? Defend your choice.",
  skill_slug: "searching", type: "optimization", band: :mid, difficulty: :medium,
  topic: t.("binary-search"),
  model: "Binary search. The data is already sorted, so a lookup is 24 " \
         "comparisons with no extra memory. Building a hash would cost O(n) time " \
         "and hundreds of megabytes to answer a single question — only worth it " \
         "if there will be many lookups.",
  answer_key: { "keywords" => [ "binary", "sorted", "memory", "one lookup",
                                "log", "build" ],
                "required" => [ "memory" ] },
  follow_ups: [
    { body: "Now it is 10 million lookups instead of one. Does your answer change?",
      trigger: "always",
      expects: [ "hash", "amortis", "o(1)", "worth" ],
      model: "Yes. The one-off O(n) build is amortised across 10 million O(1) " \
             "lookups, which beats 10 million O(log n) searches — provided the " \
             "hash fits in memory." },
    { body: "What if the records are on disk rather than in memory?",
      trigger: "always",
      expects: [ "b-tree", "page", "io", "seek", "index" ],
      model: "Then you care about I/O, not comparisons. That is exactly why " \
             "databases use B-trees: high fan-out means few page reads per lookup." }
  ]
)

question!(
  body: "Two pointers or a hash for two-sum? Give me the trade-off.",
  skill_slug: "arrays-strings", type: "optimization", band: :associate,
  difficulty: :medium, topic: t.("two-pointer-pairs"),
  model: "If the array is sorted, two pointers give O(n) time and O(1) space. " \
         "If it is unsorted, a hash of complements is O(n) time and O(n) space, " \
         "which beats sorting first at O(n log n). So the input's order decides it, " \
         "and the trade is space against the cost of sorting.",
  answer_key: { "keywords" => [ "sorted", "space", "hash", "o(1)", "o(n)" ],
                "required" => [ "sorted" ] },
  follow_ups: [
    { body: "The array is unsorted but memory is tightly constrained. Now what?",
      trigger: "always",
      expects: [ "sort", "in place", "o(n log n)", "trade" ],
      model: "Sort in place and use two pointers: O(n log n) time but O(1) extra " \
             "space. You trade time for memory, which is the right call when " \
             "memory is the binding constraint." }
  ]
)

question!(
  body: "Your colleague used `map` to update every record in a collection. " \
        "What would you say in review?",
  skill_slug: "ruby-blocks", type: "scenario", band: :associate, difficulty: :easy,
  topic: t.("each-vs-map"),
  model: "`map` allocates an array of return values nobody reads, so `each` states " \
         "the intent and avoids the garbage. More importantly, updating records one " \
         "at a time issues one query per record — `update_all` or a batched update " \
         "does it in one statement.",
  answer_key: { "keywords" => [ "each", "allocat", "return value", "update_all",
                                "n+1", "query" ],
                "required" => [ "each" ] },
  follow_ups: [
    { body: "Does the wasted array actually matter?",
      trigger: "always",
      expects: [ "depends", "size", "large", "memory", "gc" ],
      model: "Not for a handful of records. On large collections it is real " \
             "allocation and GC pressure, but the per-record query is the bigger " \
             "problem by far." }
  ]
)
