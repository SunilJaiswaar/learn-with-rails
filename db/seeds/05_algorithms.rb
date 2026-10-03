include SeedDSL
puts "  Algorithm Arena"

mod = curriculum_module!(
  world_slug: "algorithm-arena", slug: "complexity-and-search", position: 1,
  name: "Complexity & Search",
  summary: "Counting the work, then halving it."
)

# ------------------------------------------------------------- complexity
a1 = mission!(
  curriculum_module: mod, slug: "why-big-o", position: 1,
  name: "Why 1,000,000 changes the answer", skill_slug: "complexity",
  minutes: 7, xp: 15, difficulty: :easy,
  hook: "Your function is instant on 100 records and times out on a million. " \
        "You did not write a bug. You wrote the wrong complexity.",
  summary: "Big-O as a growth rate, measured against input size you can feel.",
  blocks: [
    [ :prose, "What Big-O measures",
      { "body" => "Big-O describes how the work grows as the input grows. " \
                  "It deliberately ignores constants, because at scale the shape " \
                  "of the curve dominates everything else." } ],
    [ :interactive, "Move the slider",
      { "kind" => "complexity_slider",
        "prompt" => "Watch the operation count for each growth class as n grows.",
        "link" => "/big-o",
        "note" => "At n = 1,000,000 an O(n^2) algorithm needs 10^12 operations. " \
                  "At 100 million operations per second that is over three hours." } ],
    [ :prediction, "Which one survives a million?",
      { "question" => "Your API must respond in under a second over 1,000,000 " \
                      "records. Which complexities are acceptable?",
        "options" => [ "Only O(1)",
                       "O(1), O(log n), O(n) and O(n log n)",
                       "Anything except O(2^n)",
                       "O(n^2) is fine if the server is fast" ],
        "answer" => 1,
        "explanation" => "O(n log n) on a million items is about 20 million " \
                         "operations — comfortably under a second. O(n^2) is a " \
                         "trillion, which is hours. Faster hardware shifts the " \
                         "constant, not the curve." } ],
    [ :visual, "The curves",
      { "kind" => "growth_table",
        "sizes" => [ 10, 1_000, 1_000_000 ],
        "rows" => [
          { "label" => "O(1)", "values" => [ "1", "1", "1" ] },
          { "label" => "O(log n)", "values" => [ "4", "10", "20" ] },
          { "label" => "O(n)", "values" => [ "10", "1,000", "1,000,000" ] },
          { "label" => "O(n log n)", "values" => [ "34", "9,966", "19,931,569" ] },
          { "label" => "O(n^2)", "values" => [ "100", "1,000,000", "10^12" ] }
        ],
        "caption" => "The O(n^2) row is the one that ends careers in code review." } ],
    [ :pitfall, "What Big-O hides",
      { "body" => "Big-O drops constants, so an O(n) pass that makes a network " \
                  "call per element can be far slower than an O(n^2) loop over " \
                  "integers in memory. Complexity tells you how something scales, " \
                  "not how fast it is at your current size. Measure as well." } ],
    [ :code_demo, "Same answer, different curve",
      { "code" => "# O(n^2): for each item, scan the rest\ndef has_pair_slow?(nums, target)\n  nums.each_with_index do |a, i|\n    nums.each_with_index do |b, j|\n      return true if i != j && a + b == target\n    end\n  end\n  false\nend\n\n# O(n): remember what you have seen\ndef has_pair_fast?(nums, target)\n  seen = {}\n  nums.each do |n|\n    return true if seen[target - n]\n    seen[n] = true\n  end\n  false\nend",
        "language" => "ruby",
        "annotations" => [
          "The slow version re-derives information it already had.",
          "The fast version trades O(n) memory for O(n) time.",
          "This memory-for-time trade is the most common optimisation there is."
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A nightly reconciliation job compares two lists of " \
                       "transactions with `list_a.select { |a| list_b.include?(a) }`. " \
                       "It ran in 20 seconds last year and now takes six hours.",
        "question" => "What happened and what is the fix?",
        "answer" => "`include?` on an Array is O(n), inside a `select` over n " \
                    "items — so the job is O(n^2). The data grew ~30x, which is " \
                    "900x the work. Converting list_b to a Set makes membership " \
                    "O(1) and the job O(n)." } ],
    [ :interview, "How this is asked",
      { "question" => "What is the time complexity of `array.include?` versus " \
                      "`set.include?`, and when does it matter?",
        "good_answer" => "Array is O(n) because it scans; Set is O(1) average " \
                         "because it hashes. It matters as soon as the lookup is " \
                         "inside a loop, which turns O(n) into O(n^2)." } ],
    [ :revision, "Recall",
      { "prompt" => "An O(n^2) loop is too slow. What is the first thing to reach for?",
        "answer" => "A hash or set to replace a repeated linear scan with O(1) " \
                    "lookups." } ]
  ]
)

# ----------------------------------------------------------- binary search
a2 = mission!(
  curriculum_module: mod, slug: "binary-search", position: 2,
  name: "Halving the haystack", skill_slug: "searching",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "A million sorted records. Linear search checks up to a million. " \
        "Binary search checks twenty. The catch is in the word \"sorted\".",
  summary: "Binary search, its precondition, and the off-by-one that breaks it.",
  blocks: [
    [ :interactive, "Watch it run",
      { "kind" => "algorithm_visualizer",
        "algorithm_slug" => "binary-search",
        "prompt" => "Step through it. Watch the window halve each time.",
        "note" => "Every step discards half of what remains. That is why the cost " \
                  "is log2(n): the number of times you can halve a million is 20." } ],
    [ :prose, "The precondition",
      { "body" => "Binary search requires sorted input. On unsorted data it does " \
                  "not run slowly — it returns the wrong answer, confidently." } ],
    [ :prediction, "How many comparisons?",
      { "question" => "How many comparisons does binary search need, worst case, " \
                      "over 1,000,000 sorted items?",
        "options" => [ "about 20", "about 1,000", "about 500,000", "1,000,000" ],
        "answer" => 0,
        "explanation" => "log2(1,000,000) ≈ 20. Each comparison eliminates half " \
                         "the remaining range, so twenty halvings cover a million." } ],
    [ :code_demo, "The implementation, and the bug",
      { "code" => "def binary_search(sorted, target)\n  low = 0\n  high = sorted.length - 1   # inclusive upper bound\n\n  while low <= high          # <= because high is inclusive\n    mid = (low + high) / 2\n    case sorted[mid] <=> target\n    when 0  then return mid\n    when -1 then low  = mid + 1   # discard mid too\n    when 1  then high = mid - 1\n    end\n  end\n  nil\nend",
        "language" => "ruby",
        "annotations" => [
          "`while low < high` loops forever or misses the last element.",
          "`mid + 1` / `mid - 1` matter: without them the window never shrinks.",
          "Returning nil (not -1) is the Ruby convention for 'not found'."
        ] } ],
    [ :pitfall, "The three classic bugs",
      { "body" => "1. `low < high` instead of `<=`, which skips the final " \
                  "candidate. 2. Forgetting the ±1, so the window stops shrinking " \
                  "and the loop hangs. 3. Running it on unsorted input, which " \
                  "returns a wrong answer rather than an error." } ],
    [ :comparison, "Linear vs binary",
      { "rows" => [
          { "aspect" => "Precondition", "linear" => "None", "binary" => "Must be sorted" },
          { "aspect" => "Worst case", "linear" => "O(n)", "binary" => "O(log n)" },
          { "aspect" => "One lookup in unsorted data", "linear" => "Correct choice",
            "binary" => "Sorting first costs O(n log n)" },
          { "aspect" => "Many lookups", "linear" => "O(n) each",
            "binary" => "Sort once, then O(log n) each" }
        ],
        "columns" => { "linear" => "Linear search", "binary" => "Binary search" } } ],
    [ :scenario, "In production",
      { "situation" => "A service sorts a 50,000-element array and binary searches " \
                       "it — on every request, for a single lookup.",
        "question" => "Is binary search the right call here?",
        "answer" => "No. Sorting costs O(n log n), which dwarfs the O(n) linear " \
                    "scan it replaced. Either keep the collection sorted across " \
                    "requests and search it many times, or build a hash once and " \
                    "get O(1) lookups." } ],
    [ :interview, "How this is asked",
      { "question" => "When is binary search the wrong choice even though the data " \
                      "is sorted?",
        "good_answer" => "When you only need one lookup and the sort is not already " \
                         "paid for; when the data is a linked list, so you cannot " \
                         "index in O(1); or when a hash gives O(1) and you do not " \
                         "need ordering or range queries." } ],
    [ :revision, "Recall",
      { "prompt" => "What does binary search require, and what does it cost?",
        "answer" => "Sorted, randomly-indexable input; O(log n) comparisons." } ]
  ]
)

# ------------------------------------------------------------- two pointer
a3 = mission!(
  curriculum_module: mod, slug: "two-pointer-pairs", position: 3,
  name: "Two pointers beat two loops", skill_slug: "arrays-strings",
  minutes: 7, xp: 20, difficulty: :medium,
  hook: "Find two numbers that sum to a target. The obvious answer is two nested " \
        "loops. On sorted input you can do it in one pass.",
  summary: "The two-pointer pattern, and when sorting first pays for itself.",
  blocks: [
    [ :interactive, "Watch the pointers move",
      { "kind" => "algorithm_visualizer",
        "algorithm_slug" => "two-pointer",
        "prompt" => "Each step moves exactly one pointer. Why is that enough?",
        "note" => "Because the array is sorted, a sum that is too small can only be " \
                  "increased by moving `left` right, and vice versa. " \
                  "No pair is ever skipped." } ],
    [ :prose, "Why it is correct",
      { "body" => "The pointers only ever move inward, so each element is visited " \
                  "at most once: O(n) after sorting. Sortedness is what makes the " \
                  "decision to move one pointer safe." } ],
    [ :prediction, "Which pointer moves?",
      { "question" => "Sorted array [2, 3, 4, 7, 8], target 10. " \
                      "left=0 (2), right=4 (8), sum=10. What happens?",
        "options" => [ "Move left right", "Move right left",
                       "Found it — return the pair", "Move both" ],
        "answer" => 2,
        "explanation" => "The sum already equals the target, so the pair is found. " \
                         "You move left when the sum is too small, and right when " \
                         "it is too big." } ],
    [ :code_demo, "The pattern",
      { "code" => "def pair_with_sum(sorted, target)\n  left = 0\n  right = sorted.length - 1\n\n  while left < right        # < : a number cannot pair with itself\n    sum = sorted[left] + sorted[right]\n    return [sorted[left], sorted[right]] if sum == target\n\n    if sum < target\n      left += 1             # need a bigger sum\n    else\n      right -= 1            # need a smaller sum\n    end\n  end\n  nil\nend",
        "language" => "ruby",
        "annotations" => [
          "`left < right`, not `<=`: the same element must not be used twice.",
          "Each iteration moves exactly one pointer, so this terminates in n steps.",
          "On unsorted input you must sort first, or use a hash instead."
        ] } ],
    [ :comparison, "Three approaches to pair-sum",
      { "rows" => [
          { "aspect" => "Nested loops", "time" => "O(n^2)", "space" => "O(1)",
            "needs" => "Nothing" },
          { "aspect" => "Hash of seen values", "time" => "O(n)", "space" => "O(n)",
            "needs" => "Nothing — works unsorted" },
          { "aspect" => "Two pointers", "time" => "O(n) after sort", "space" => "O(1)",
            "needs" => "Sorted input" }
        ],
        "columns" => { "time" => "Time", "space" => "Space", "needs" => "Requires" } } ],
    [ :pitfall, "The trap in the trade-off",
      { "body" => "If the input is unsorted and you only do one query, the hash " \
                  "approach is better: it is O(n) with no sort. Two pointers win " \
                  "when the data is already sorted, or when O(1) extra space is a " \
                  "hard requirement." } ],
    [ :scenario, "In production",
      { "situation" => "A matching service must find pairs of trades that net to " \
                       "zero across 10 million records held in a sorted file.",
        "question" => "Which approach, and why?",
        "answer" => "Two pointers. The data is already sorted, so there is no sort " \
                    "cost, and the O(1) space matters at 10 million records where " \
                    "a hash of every seen value would not fit comfortably in " \
                    "memory." } ],
    [ :interview, "How this is asked",
      { "question" => "Solve two-sum. Then: what changes if the array is not sorted?",
        "good_answer" => "Sorted: two pointers, O(n) time and O(1) space. " \
                         "Unsorted: a hash of complements, O(n) time and O(n) " \
                         "space — sorting purely to enable two pointers would cost " \
                         "O(n log n), which is worse." } ],
    [ :revision, "Recall",
      { "prompt" => "What property of the input makes two pointers valid?",
        "answer" => "It must be sorted, so moving a pointer changes the sum in a " \
                    "known direction." } ]
  ]
)

# --------------------------------------------------------------- challenges
challenge!(
  slug: "two-sum-optimised", title: "Two-sum in one pass",
  topic: a1, skill_slug: "hash-maps", type: :optimize, difficulty: :medium, xp: 50,
  prompt: "`two_sum(nums, target)` returns the **indices** of the two numbers " \
          "that add up to `target`, as a sorted two-element array, or `nil`.\n\n" \
          "The given solution is O(n^2). Rewrite it to run in O(n).\n\n" \
          "The input is **not** sorted. Assume exactly one valid answer when one " \
          "exists, and never pair an index with itself.",
  starter: "def two_sum(nums, target)\n" \
           "  nums.each_with_index do |a, i|\n" \
           "    nums.each_with_index do |b, j|\n" \
           "      next if i == j\n" \
           "      return [i, j].sort if a + b == target\n" \
           "    end\n" \
           "  end\n" \
           "  nil\n" \
           "end\n",
  solution: "def two_sum(nums, target)\n" \
            "  seen = {}\n" \
            "  nums.each_with_index do |value, index|\n" \
            "    complement = target - value\n" \
            "    return [seen[complement], index].sort if seen.key?(complement)\n" \
            "    seen[value] = index\n" \
            "  end\n" \
            "  nil\n" \
            "end\n",
  explanation: "Store each value's index as you pass it, then ask whether the " \
               "complement has already been seen. One pass, O(n) time, O(n) space. " \
               "Checking `seen` *before* inserting is what prevents pairing an " \
               "element with itself.",
  metadata: { "target_complexity" => "O(n)" },
  tests: [
    [ "finds the pair", "two_sum([2, 7, 11, 15], 9)", "[0, 1]" ],
    [ "finds a pair later in the array", "two_sum([3, 2, 4], 6)", "[1, 2]" ],
    [ "handles duplicate values", "two_sum([3, 3], 6)", "[0, 1]" ],
    [ "returns nil when there is no pair", "two_sum([1, 2, 3], 100)", "nil" ],
    [ "does not pair an element with itself", "two_sum([5, 1], 10)", "nil" ],
    [ "works with negatives", "two_sum([-3, 4, 1], -2)", "[0, 2]", true ],
    [ "handles an empty array", "two_sum([], 5)", "nil", true ]
  ],
  hints: [
    [ :nudge, "The slow version keeps rediscovering values it has already walked " \
              "past. What if it remembered them?", 3 ],
    [ :concept, "For each value you need `target - value`. A Hash answers " \
                "\"have I seen this number, and where?\" in O(1).", 4 ],
    [ :pseudocode, "seen = {}\nfor each (value, index):\n" \
                   "  if seen has (target - value): return those two indices\n" \
                   "  seen[value] = index", 6 ],
    [ :solution, "Check the hash before inserting the current value — that is what " \
                 "stops an element pairing with itself.", 10 ]
  ]
)

challenge!(
  slug: "debug-binary-search", title: "The search that hangs",
  topic: a2, skill_slug: "searching", type: :debug, difficulty: :medium, xp: 50,
  prompt: "This binary search never returns for some inputs, and misses the last " \
          "element for others.\n\n" \
          "There are **two** bugs in the loop. Find and fix both.",
  starter: "def binary_search(sorted, target)\n" \
           "  low = 0\n" \
           "  high = sorted.length - 1\n\n" \
           "  while low < high\n" \
           "    mid = (low + high) / 2\n" \
           "    return mid if sorted[mid] == target\n\n" \
           "    if sorted[mid] < target\n" \
           "      low = mid\n" \
           "    else\n" \
           "      high = mid\n" \
           "    end\n" \
           "  end\n" \
           "  nil\n" \
           "end\n",
  solution: "def binary_search(sorted, target)\n" \
            "  low = 0\n" \
            "  high = sorted.length - 1\n\n" \
            "  while low <= high\n" \
            "    mid = (low + high) / 2\n" \
            "    return mid if sorted[mid] == target\n\n" \
            "    if sorted[mid] < target\n" \
            "      low = mid + 1\n" \
            "    else\n" \
            "      high = mid - 1\n" \
            "    end\n" \
            "  end\n" \
            "  nil\n" \
            "end\n",
  explanation: "Bug 1: `low < high` exits while one candidate is still unchecked, " \
               "so a target at the boundary is missed. Bug 2: assigning `mid` " \
               "without ±1 means the window can stop shrinking — with two elements " \
               "left, `mid` equals `low` and the loop spins forever. " \
               "`high` is an inclusive bound, so the test must be `<=` and the " \
               "bounds must step past `mid`.",
  time_limit_ms: 2000,
  tests: [
    [ "finds a middle element", "binary_search([1, 3, 5, 7, 9], 5)", "2" ],
    [ "finds the first element", "binary_search([1, 3, 5, 7, 9], 1)", "0" ],
    [ "finds the last element", "binary_search([1, 3, 5, 7, 9], 9)", "4" ],
    [ "returns nil when absent", "binary_search([1, 3, 5], 4)", "nil" ],
    [ "handles a single element", "binary_search([42], 42)", "0" ],
    [ "handles an empty array", "binary_search([], 1)", "nil" ],
    [ "finds both elements of a two-element array",
      "[binary_search([1, 2], 1), binary_search([1, 2], 2)]", "[0, 1]", true ]
  ],
  hints: [
    [ :nudge, "Trace `[1, 2]` searching for 2 by hand. Write down low, high and " \
              "mid each iteration.", 3 ],
    [ :concept, "`high` is an inclusive index. If `low == high` there is still one " \
                "element to check — does the loop condition allow that?", 4 ],
    [ :clue, "When two elements remain, `mid` equals `low`. If you then set " \
             "`low = mid`, what changed?", 5 ],
    [ :solution, "Use `low <= high`, and move the bounds past mid: `low = mid + 1` " \
                 "and `high = mid - 1`.", 10 ]
  ]
)

# ---------------------------------------------------------------- questions
question!(
  body: "Your endpoint processes 100 million records and currently runs an " \
        "O(n^2) algorithm. Walk me through how you would approach it.",
  skill_slug: "complexity", type: "optimization", band: :senior, difficulty: :hard,
  topic: a1, company_type: "product",
  model: "First confirm where the time actually goes by measuring, rather than " \
         "assuming the nested loop is the bottleneck. Then look for the repeated " \
         "work: an O(n^2) algorithm usually rescans data it already has, so a hash " \
         "or set, sorting once, or a single pass with running state typically " \
         "removes a level. At 100 million I would also question whether all of it " \
         "must be in memory at once, and whether the work can be batched, " \
         "streamed, or pushed into the database.",
  explanation: "The strongest answers measure first and consider the data pipeline, " \
               "not only the inner loop.",
  mistakes: "Jumping straight to micro-optimisations, or rewriting in another " \
            "language instead of changing the complexity.",
  answer_key: { "keywords" => [ "measure", "profile", "hash", "set", "sort",
                                "stream", "batch", "memory", "index" ],
                "required" => [ "measure" ] },
  related: [ "hash maps", "streaming", "database indexes" ],
  follow_ups: [
    { body: "You said you would use a hash. What is the memory cost at 100 million " \
            "entries?",
      trigger: "keyword", keywords: [ "hash", "set", "map", "dictionary" ],
      expects: [ "memory", "gigabyte", "does not fit", "batch", "disk" ],
      model: "Many gigabytes — likely more than the box has. That pushes you " \
             "toward chunking, an external sort, a bloom filter for membership, " \
             "or doing the work in the database where the data already lives." },
    { body: "How would you confirm the fix worked, beyond the code looking faster?",
      trigger: "always",
      expects: [ "benchmark", "measure", "production", "monitor", "p95" ],
      model: "Benchmark with production-sized data, not sample data, and compare " \
             "p95 latency and memory before and after. Then watch the real metric " \
             "after deploy." },
    { body: "What if the O(n^2) step turns out not to be the bottleneck at all?",
      trigger: "always",
      expects: [ "profile", "io", "network", "database", "n+1" ],
      model: "Then optimising it is wasted effort. At that scale the time is often " \
             "I/O: N+1 queries, serialisation or network round-trips. The profile " \
             "decides what to fix." }
  ]
)

question!(
  body: "What is the time and space complexity of looking up a key in a Ruby Hash, " \
        "and when is it not O(1)?",
  skill_slug: "hash-maps", type: "architecture", band: :mid, difficulty: :medium,
  topic: a1,
  model: "Average O(1) time, O(n) space. It degrades toward O(n) when many keys " \
         "collide into the same bucket — either by bad luck or because a custom " \
         "`hash` method distributes poorly. Resizing also makes individual " \
         "insertions cost more, though it is amortised O(1).",
  answer_key: { "keywords" => [ "o(1)", "collision", "bucket", "amortis", "hash" ],
                "required" => [ "collision" ] },
  follow_ups: [
    { body: "What must be true of an object used as a Hash key?",
      trigger: "always",
      expects: [ "hash", "eql", "immutable", "consistent" ],
      model: "It must implement `hash` and `eql?` consistently, and its hash must " \
             "not change while it is a key — mutating a key makes the entry " \
             "unreachable until the hash is rehashed." }
  ]
)
