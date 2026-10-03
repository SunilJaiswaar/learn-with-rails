include SeedDSL
# Completes Phase 2: the Algorithms skills that had no missions, plus Git.
puts "  Phase 2: algorithms depth and Git"

forest = World.find_by!(slug: "programming-forest")
arena  = World.find_by!(slug: "algorithm-arena")

# Git was only a simulator; it becomes a skill in the tree.
git = Skill.find_or_create_by!(slug: "git-fundamentals") do |s|
  s.name = "Git"
  s.world = forest
  s.tier = 1
  s.position = 5
  s.grid_x = 1
  s.grid_y = 2
  s.summary = "Commits, branches, merges and how to undo things safely."
end
SkillDependency.find_or_create_by!(skill: git, prerequisite: Skill.find_by!(slug: "ruby-basics"))

algo_mod = curriculum_module!(
  world_slug: "algorithm-arena", slug: "algorithmic-thinking-module", position: 0,
  name: "Thinking in Steps", summary: "Turning a vague problem into countable work."
)
sort_mod = curriculum_module!(
  world_slug: "algorithm-arena", slug: "sorting-module", position: 4,
  name: "Sorting", summary: "Four algorithms, watched running."
)
hash_mod = curriculum_module!(
  world_slug: "algorithm-arena", slug: "hashing-module", position: 5,
  name: "Hash Maps", summary: "Trading memory for time."
)
debug_mod = curriculum_module!(
  world_slug: "programming-forest", slug: "debugging-module", position: 3,
  name: "Debugging", summary: "Reading the evidence instead of guessing."
)
git_mod = curriculum_module!(
  world_slug: "programming-forest", slug: "git-module", position: 4,
  name: "Git Time Machine", summary: "A graph of snapshots you can move through."
)

# ============================================================ algorithmic thinking
at1 = mission!(
  curriculum_module: algo_mod, slug: "decompose-the-problem", position: 1,
  name: "From a sentence to steps", skill_slug: "algorithmic-thinking",
  minutes: 6, xp: 10,
  hook: "\"Find the most common word.\" You know what that means, but you " \
        "cannot type it. The gap between understanding a problem and being " \
        "able to code it is the skill nobody teaches explicitly.",
  summary: "Restate, find the invariant, pick the data structure, then write code.",
  blocks: [
    [ :prose, "The four questions",
      { "body" => "Before typing, answer: what is the **input**, what is the " \
                  "**output**, what single piece of information do I need to " \
                  "carry as I go, and what happens at the **edges** " \
                  "(empty, one element, ties)?" } ],
    [ :visual, "The same problem, decomposed",
      { "kind" => "growth_table",
        "sizes" => [ "question", "answer" ],
        "rows" => [
          { "label" => "Input", "values" => [ "a string of words", "\"a b a\"" ] },
          { "label" => "Output", "values" => [ "one word", "\"a\"" ] },
          { "label" => "Carry", "values" => [ "count per word", "{a: 2, b: 1}" ] },
          { "label" => "Edges", "values" => [ "empty input, a tie", "nil, pick either" ] }
        ],
        "caption" => "Once the 'carry' column is filled in, the code is almost " \
                     "mechanical: build the counts, then take the maximum." } ],
    [ :prediction, "What is the carry?",
      { "question" => "To find the *second* largest number in one pass, what " \
                      "must you carry as you walk the list?",
        "options" => [ "Just the largest seen so far",
                       "The largest and second largest seen so far",
                       "The whole list, sorted",
                       "A count of each value" ],
        "answer" => 1,
        "explanation" => "Two values. Carrying only the largest loses the " \
                         "runner-up when a new maximum arrives, so you must " \
                         "demote the old maximum rather than discard it. " \
                         "Sorting works but costs O(n log n) for an O(n) job." } ],
    [ :interactive, "Name the structure",
      { "kind" => "risk_spotter",
        "prompt" => "Which structure does each 'carry' want?",
        "cases" => [
          { "sql" => "How many times each value appears", "risk" => false,
            "why" => "A Hash keyed by value." },
          { "sql" => "Have I seen this before?", "risk" => false,
            "why" => "A Set — O(1) membership, no values needed." },
          { "sql" => "The largest few so far", "risk" => true,
            "why" => "A couple of variables, or a heap for large k." },
          { "sql" => "The most recent unmatched opening bracket", "risk" => true,
            "why" => "A Stack — last in, first out." }
        ] } ],
    [ :code_demo, "Carry two values, one pass",
      { "code" => "def second_largest(numbers)\n  largest = second = nil\n\n  numbers.each do |n|\n    if largest.nil? || n > largest\n      second = largest      # demote, do not discard\n      largest = n\n    elsif n != largest && (second.nil? || n > second)\n      second = n\n    end\n  end\n\n  second\nend",
        "language" => "ruby",
        "annotations" => [
          "The `second = largest` line is the whole idea: demote, never discard.",
          "`n != largest` skips duplicates of the maximum, so [5,5] has no second.",
          "One pass, O(1) memory — sorting would be O(n log n)."
        ] } ],
    [ :pitfall, "Edges are where the bugs live",
      { "body" => "Empty input, a single element, every element equal, and " \
                  "negative numbers. Write those four cases down *before* " \
                  "coding, and most off-by-one bugs never happen." } ],
    [ :scenario, "In production",
      { "situation" => "A teammate's \"top 10 products\" endpoint sorts all 4 " \
                       "million rows then takes the first ten. It takes 9 seconds.",
        "question" => "What is the cheaper shape?",
        "answer" => "You do not need a total order to answer a top-k question. " \
                    "Carry the best 10 seen so far in a small heap — one pass, " \
                    "O(n log 10) which is effectively O(n), and constant memory. " \
                    "Better still, let the database do it with ORDER BY + LIMIT " \
                    "against an index." } ],
    [ :interview, "How this is asked",
      { "question" => "Walk me through how you would approach a problem you have " \
                      "not seen before.",
        "good_answer" => "Restate it to confirm the input and output, work a tiny " \
                         "example by hand, name the state I need to carry, then " \
                         "pick the structure that makes that state cheap to " \
                         "maintain. I would state the edge cases before coding " \
                         "and the complexity after." } ],
    [ :revision, "Recall",
      { "prompt" => "What are the four questions to answer before writing code?",
        "answer" => "Input, output, what to carry, and the edge cases." } ]
  ]
)

challenge!(
  slug: "second-largest-one-pass", title: "Second largest, one pass",
  topic: at1, skill_slug: "algorithmic-thinking", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Write `second_largest(numbers)` returning the second largest " \
          "**distinct** value, or `nil` if there is not one.\n\n" \
          "Do it in a single pass with constant extra memory — no sorting.",
  starter: "def second_largest(numbers)\n  # Your code here\nend\n",
  solution: "def second_largest(numbers)\n" \
            "  largest = second = nil\n" \
            "  numbers.each do |n|\n" \
            "    if largest.nil? || n > largest\n" \
            "      second = largest\n" \
            "      largest = n\n" \
            "    elsif n != largest && (second.nil? || n > second)\n" \
            "      second = n\n" \
            "    end\n" \
            "  end\n" \
            "  second\n" \
            "end\n",
  explanation: "The key line demotes the old maximum instead of discarding it. " \
               "Guarding with `n != largest` is what makes it *distinct*, so " \
               "[5, 5] correctly has no second largest.",
  metadata: { "target_complexity" => "O(n) time, O(1) space" },
  tests: [
    [ "finds the second largest", "second_largest([3, 1, 4, 2])", "3" ],
    [ "ignores duplicates of the maximum", "second_largest([5, 5, 2])", "2" ],
    [ "returns nil when all values are equal", "second_largest([5, 5])", "nil" ],
    [ "returns nil for a single element", "second_largest([7])", "nil" ],
    [ "returns nil for an empty list", "second_largest([])", "nil" ],
    [ "handles negatives", "second_largest([-5, -2, -9])", "-5", true ],
    [ "handles a descending list", "second_largest([9, 8, 7])", "8", true ]
  ],
  hints: [
    [ :nudge, "What do you need to remember as you walk the list? There is more " \
              "than one thing.", 2 ],
    [ :concept, "When you find a new maximum, the old maximum becomes the second " \
                "largest — do not throw it away.", 4 ],
    [ :solution, "Carry `largest` and `second`. On a new max: `second = largest; " \
                 "largest = n`. Skip values equal to largest.", 8 ]
  ]
)

challenge!(
  slug: "debug-balanced-brackets", title: "The bracket checker that says yes too often",
  topic: at1, skill_slug: "algorithmic-thinking", type: :debug, difficulty: :medium, xp: 45,
  prompt: "`balanced?(text)` should report whether brackets are correctly " \
          "nested. It only counts them, so it accepts `\")(\"` — the right " \
          "number of brackets in the wrong order.\n\n" \
          "Fix it. Only `()` needs handling.",
  starter: "def balanced?(text)\n" \
           "  opens = text.count(\"(\")\n" \
           "  closes = text.count(\")\")\n" \
           "  opens == closes\n" \
           "end\n",
  solution: "def balanced?(text)\n" \
            "  depth = 0\n" \
            "  text.each_char do |char|\n" \
            "    depth += 1 if char == \"(\"\n" \
            "    depth -= 1 if char == \")\"\n" \
            "    return false if depth.negative?\n" \
            "  end\n" \
            "  depth.zero?\n" \
            "end\n",
  explanation: "Counting loses the ordering. Carrying a running depth and " \
               "failing the moment it goes negative catches a close that has no " \
               "matching open — which is exactly the information a count throws " \
               "away. This is a stack where you only need its size.",
  tests: [
    [ "accepts a balanced pair", "balanced?(\"()\")", "true" ],
    [ "accepts nesting", "balanced?(\"(())\")", "true" ],
    [ "rejects reversed brackets", "balanced?(\")(\")", "false" ],
    [ "rejects an unclosed open", "balanced?(\"(\")", "false" ],
    [ "accepts text around the brackets", "balanced?(\"a(b)c\")", "true" ],
    [ "accepts an empty string", "balanced?(\"\")", "true" ],
    [ "rejects a deeper mismatch", "balanced?(\"(()))(\")", "false", true ]
  ],
  hints: [
    [ :nudge, "Trace `\")(\"` through the current code. Both counts are 1.", 2 ],
    [ :concept, "Order matters, so you have to walk the string and track depth.", 4 ],
    [ :solution, "Increment on `(`, decrement on `)`, return false if depth ever " \
                 "goes negative, and require depth to end at zero.", 8 ]
  ]
)

question!(
  body: "You are given a problem you have never seen. Describe your approach " \
        "before writing any code.",
  skill_slug: "algorithmic-thinking", type: "scenario", band: :junior, difficulty: :easy,
  topic: at1,
  model: "Restate the problem to confirm input and output, work a small example " \
         "by hand, identify what state has to be carried through the data, then " \
         "choose a data structure that makes maintaining that state cheap. " \
         "State the edge cases up front and the complexity at the end.",
  answer_key: { "keywords" => [ "input", "output", "example", "edge", "complexity",
                                "state", "structure" ],
                "required" => [ "edge" ] },
  follow_ups: [
    { body: "You mentioned edge cases. Which ones do you check by habit?",
      trigger: "always",
      expects: [ "empty", "one", "duplicate", "negative", "tie" ],
      model: "Empty input, a single element, duplicates or ties, and negatives " \
             "or zero where the values are numeric." },
    { body: "How do you decide between a Hash and a Set?",
      trigger: "always",
      expects: [ "value", "membership", "count", "key" ],
      model: "A Set when I only need to know whether I have seen something; a " \
             "Hash when I need an associated value such as a count or an index." }
  ]
)

# ======================================================================= sorting
so1 = mission!(
  curriculum_module: sort_mod, slug: "choosing-a-sort", position: 1,
  name: "Four sorts, one decision", skill_slug: "sorting",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "Ruby's `sort` is already fast. So why does every interview ask you to " \
        "implement one? Because the four classic sorts are four different " \
        "answers to \"what are you willing to trade?\"",
  summary: "Stability, memory, worst case — and why production uses a hybrid.",
  blocks: [
    [ :interactive, "Watch them run",
      { "kind" => "algorithm_visualizer", "algorithm_slug" => "merge-sort",
        "prompt" => "Step through merge sort, then compare it with quick sort.",
        "note" => "Merge sort splits to single elements then merges upward. " \
                  "Quick sort partitions around a pivot. Same complexity on " \
                  "average, very different behaviour." } ],
    [ :comparison, "The trade-offs",
      { "rows" => [
          { "aspect" => "Bubble", "worst" => "O(n^2)", "space" => "O(1)",
            "stable" => "Yes", "use" => "Teaching only" },
          { "aspect" => "Insertion", "worst" => "O(n^2)", "space" => "O(1)",
            "stable" => "Yes", "use" => "Small or nearly-sorted input" },
          { "aspect" => "Merge", "worst" => "O(n log n)", "space" => "O(n)",
            "stable" => "Yes", "use" => "Guaranteed bound; external sorts" },
          { "aspect" => "Quick", "worst" => "O(n^2)", "space" => "O(log n)",
            "stable" => "No", "use" => "Fastest in practice, in place" }
        ],
        "columns" => { "worst" => "Worst case", "space" => "Space",
                       "stable" => "Stable", "use" => "Use when" } } ],
    [ :prose, "What stability means",
      { "body" => "A **stable** sort keeps equal elements in their original " \
                  "relative order. It matters whenever you sort by one key " \
                  "after another: sort by name, then stably by department, and " \
                  "names stay alphabetical within each department." } ],
    [ :prediction, "Which one breaks?",
      { "question" => "You sort a list by name, then sort the result by " \
                      "department using an **unstable** sort. What happens?",
        "options" => [ "Names stay alphabetical within each department",
                       "The name ordering is lost within departments",
                       "The sort raises an error",
                       "Departments come out unordered" ],
        "answer" => 1,
        "explanation" => "An unstable sort may reorder equal elements, so the " \
                         "name ordering you established is not preserved within " \
                         "a department. This is the practical reason stability " \
                         "is worth knowing — and why Ruby's `sort_by` on a tuple " \
                         "is usually the better answer." } ],
    [ :visual, "Why quick sort degrades",
      { "kind" => "growth_table",
        "sizes" => [ "pivot choice", "partition", "result" ],
        "rows" => [
          { "label" => "Median-ish", "values" => [ "balanced halves", "log n depth", "O(n log n)" ] },
          { "label" => "Always smallest", "values" => [ "1 and n-1", "n depth", "O(n^2)" ] },
          { "label" => "Already sorted + last pivot",
            "values" => [ "worst case", "n depth", "O(n^2)" ] }
        ],
        "caption" => "Quick sort's worst case is an adversarial or already-sorted " \
                     "input. Production implementations randomise the pivot or " \
                     "switch to heap sort when recursion gets too deep." } ],
    [ :pitfall, "Do not write your own in production",
      { "body" => "Standard library sorts are hybrids — Timsort, introsort — " \
                  "tuned over decades, with insertion sort for small runs and a " \
                  "guaranteed O(n log n) fallback. Implement one to understand " \
                  "it; call the built-in to ship it." } ],
    [ :scenario, "In production",
      { "situation" => "A job sorts a 40GB export file on a box with 8GB of RAM.",
        "question" => "Which algorithm, and why?",
        "answer" => "Merge sort. It is the basis of external sorting: sort chunks " \
                    "that fit in memory, write them out, then merge the sorted " \
                    "runs streaming sequentially from disk. Quick sort needs " \
                    "random access to partition, which is exactly what you " \
                    "cannot afford here." } ],
    [ :interview, "How this is asked",
      { "question" => "Merge sort or quick sort?",
        "good_answer" => "Quick sort is usually faster in memory because it works " \
                         "in place with good cache locality, but its worst case " \
                         "is O(n^2) and it is not stable. Merge sort guarantees " \
                         "O(n log n) and is stable, at the cost of O(n) extra " \
                         "space — which is why it wins for external sorts and " \
                         "when stability matters." } ],
    [ :revision, "Recall",
      { "prompt" => "Which classic sort is stable with a guaranteed O(n log n), " \
                    "and what does it cost?",
        "answer" => "Merge sort; it costs O(n) extra space." } ]
  ]
)

challenge!(
  slug: "merge-two-sorted", title: "Merge two sorted lists",
  topic: so1, skill_slug: "sorting", type: :implement, difficulty: :medium, xp: 40,
  prompt: "Write `merge_sorted(left, right)` that merges two **already sorted** " \
          "arrays into one sorted array.\n\n" \
          "This is the merge step of merge sort. Do it in O(n + m) — walking " \
          "both lists once. Concatenating and re-sorting is not a merge.",
  starter: "def merge_sorted(left, right)\n  # Your code here\nend\n",
  solution: "def merge_sorted(left, right)\n" \
            "  i = j = 0\n" \
            "  merged = []\n" \
            "  while i < left.length && j < right.length\n" \
            "    if left[i] <= right[j]\n" \
            "      merged << left[i]; i += 1\n" \
            "    else\n" \
            "      merged << right[j]; j += 1\n" \
            "    end\n" \
            "  end\n" \
            "  merged.concat(left[i..] || []).concat(right[j..] || [])\n" \
            "end\n",
  explanation: "Two indices, always taking the smaller head. `<=` rather than " \
               "`<` is what makes the merge **stable**: on a tie the left list's " \
               "element goes first, preserving original order. After the loop one " \
               "list still has a tail, which is appended as-is because it is " \
               "already sorted.",
  metadata: { "target_complexity" => "O(n + m)" },
  tests: [
    [ "interleaves two lists", "merge_sorted([1, 3, 5], [2, 4, 6])", "[1, 2, 3, 4, 5, 6]" ],
    [ "handles an empty left list", "merge_sorted([], [1, 2])", "[1, 2]" ],
    [ "handles an empty right list", "merge_sorted([1, 2], [])", "[1, 2]" ],
    [ "handles both empty", "merge_sorted([], [])", "[]" ],
    [ "keeps duplicates", "merge_sorted([1, 1], [1])", "[1, 1, 1]" ],
    [ "handles unequal lengths", "merge_sorted([1], [2, 3, 4])", "[1, 2, 3, 4]" ],
    [ "handles a list entirely below the other",
      "merge_sorted([1, 2], [8, 9])", "[1, 2, 8, 9]", true ]
  ],
  hints: [
    [ :nudge, "Two pointers, one per list. Which head do you take?", 3 ],
    [ :concept, "Take the smaller head and advance only that pointer. When one " \
                "list runs out, the other's remainder is already sorted.", 4 ],
    [ :solution, "Use `<=` on the comparison so equal elements keep the left " \
                 "list's order — that is what makes merge sort stable.", 9 ]
  ]
)

challenge!(
  slug: "debug-insertion-sort", title: "The sort that drops an element",
  topic: so1, skill_slug: "sorting", type: :debug, difficulty: :medium, xp: 50,
  prompt: "This insertion sort returns a list that is sorted but **one element " \
          "short** — the first element is overwritten.\n\n" \
          "Find the off-by-one and fix it.",
  starter: "def insertion_sort(numbers)\n" \
           "  a = numbers.dup\n" \
           "  (1...a.length).each do |i|\n" \
           "    key = a[i]\n" \
           "    j = i - 1\n" \
           "    while j >= 0 && a[j] > key\n" \
           "      a[j + 1] = a[j]\n" \
           "      j -= 1\n" \
           "    end\n" \
           "    a[j] = key\n" \
           "  end\n" \
           "  a\n" \
           "end\n",
  solution: "def insertion_sort(numbers)\n" \
            "  a = numbers.dup\n" \
            "  (1...a.length).each do |i|\n" \
            "    key = a[i]\n" \
            "    j = i - 1\n" \
            "    while j >= 0 && a[j] > key\n" \
            "      a[j + 1] = a[j]\n" \
            "      j -= 1\n" \
            "    end\n" \
            "    a[j + 1] = key\n" \
            "  end\n" \
            "  a\n" \
            "end\n",
  explanation: "The shifting loop exits with `j` pointing one slot *before* the " \
               "gap, because it decrements after the last shift. The key belongs " \
               "at `j + 1`. Writing to `a[j]` overwrites an element that was " \
               "already in place — and when `j` reaches -1, `a[-1]` writes to the " \
               "end of the array, which is why Ruby gives no error.",
  tests: [
    [ "sorts a small list", "insertion_sort([3, 1, 2])", "[1, 2, 3]" ],
    [ "keeps every element", "insertion_sort([5, 4, 3, 2, 1]).length", "5" ],
    [ "sorts descending input", "insertion_sort([5, 4, 3, 2, 1])", "[1, 2, 3, 4, 5]" ],
    [ "leaves sorted input alone", "insertion_sort([1, 2, 3])", "[1, 2, 3]" ],
    [ "does not mutate the input", "input = [2, 1]; insertion_sort(input); input", "[2, 1]" ],
    [ "handles duplicates", "insertion_sort([2, 1, 2])", "[1, 2, 2]" ],
    [ "handles one element", "insertion_sort([9])", "[9]", true ],
    [ "handles an empty list", "insertion_sort([])", "[]", true ]
  ],
  hints: [
    [ :nudge, "Compare the length of the input with the length of the output.", 3 ],
    [ :concept, "After the while loop, is `j` the gap, or one before it?", 4 ],
    [ :clue, "`a[-1]` in Ruby writes to the *last* element, which hides the bug.", 5 ],
    [ :solution, "Insert at `a[j + 1]`, not `a[j]`.", 9 ]
  ]
)

question!(
  body: "What does it mean for a sort to be stable, and when does it matter?",
  skill_slug: "sorting", type: "architecture", band: :associate, difficulty: :medium,
  topic: so1,
  model: "A stable sort preserves the relative order of elements that compare " \
         "equal. It matters when sorting by several keys in sequence, or when " \
         "the existing order carries meaning — for example sorting already " \
         "time-ordered records by category and expecting them to stay " \
         "chronological within each category.",
  mistakes: "Confusing stability with determinism, or assuming the standard " \
            "library sort is stable (Ruby's `sort` is not guaranteed to be).",
  answer_key: { "keywords" => [ "equal", "relative order", "preserve", "multiple keys" ],
                "required" => [ "equal" ] },
  follow_ups: [
    { body: "Is Ruby's `Array#sort` stable?",
      trigger: "always",
      expects: [ "not guaranteed", "no", "sort_by", "tuple" ],
      model: "Not guaranteed. If I need deterministic ordering I sort by a tuple " \
             "that includes a unique tie-break, e.g. `sort_by { |x| [x.dept, x.name, x.id] }`." },
    { body: "Which of the classic sorts are stable?",
      trigger: "always",
      expects: [ "merge", "insertion", "bubble", "quick" ],
      model: "Bubble, insertion and merge sort are stable; quick sort and heap " \
             "sort are not." }
  ]
)

# ===================================================================== hash maps
hm1 = mission!(
  curriculum_module: hash_mod, slug: "memory-for-time", position: 1,
  name: "Buying time with memory", skill_slug: "hash-maps",
  minutes: 7, xp: 20, difficulty: :medium,
  hook: "Nearly every \"make this faster\" answer is the same move: stop " \
        "re-scanning, start remembering. The hash map is how you remember.",
  summary: "O(1) lookup, what it costs, and when it is the wrong tool.",
  blocks: [
    [ :prose, "The trade in one line",
      { "body" => "A hash map turns \"search the collection\" (O(n)) into " \
                  "\"compute where it would be\" (O(1) average), paid for with " \
                  "O(n) memory and the requirement that keys be hashable." } ],
    [ :visual, "The same loop, two costs",
      { "kind" => "growth_table",
        "sizes" => [ "n = 1,000", "n = 100,000" ],
        "rows" => [
          { "label" => "Array#include? in a loop", "values" => [ "1,000,000 ops", "10^10 ops" ] },
          { "label" => "Set#include? in a loop", "values" => [ "1,000 ops", "100,000 ops" ] }
        ],
        "caption" => "Same code shape, one word changed. At 100,000 elements " \
                     "that is the difference between instant and hours." } ],
    [ :prediction, "When is it NOT O(1)?",
      { "question" => "Which of these makes hash lookup degrade toward O(n)?",
        "options" => [ "Too many keys",
                       "Many keys colliding into the same bucket",
                       "Keys that are strings rather than integers",
                       "Reading the same key repeatedly" ],
        "answer" => 1,
        "explanation" => "Collisions. When many keys hash to the same bucket the " \
                         "lookup degenerates to scanning that bucket. A custom " \
                         "`hash` method that distributes poorly causes exactly " \
                         "this — the reason `hash` and `eql?` must be implemented " \
                         "carefully and consistently." } ],
    [ :interactive, "Pick the structure for the job",
      { "kind" => "risk_spotter",
        "prompt" => "Each of these is a real optimisation. Which structure does it want?",
        "cases" => [
          { "sql" => "Reject a request if the API key was already used",
            "risk" => false, "why" => "A Set of used keys — membership only." },
          { "sql" => "Serve the top 10 products without re-sorting 4M rows",
            "risk" => true,
            "why" => "Not a hash: a small heap, or ORDER BY + LIMIT on an index." },
          { "sql" => "Join 200k orders to 50k customers in one pass",
            "risk" => false,
            "why" => "A Hash index keyed by customer id, built once outside the loop." },
          { "sql" => "Count events per user across 80M rows",
            "risk" => true,
            "why" => "A Hash of counters is O(keys) not O(rows) — but if the key " \
                     "space is huge, aggregate in the database instead." }
        ],
        "note" => "The last case is the honest limit of this technique: the hash " \
                  "scales with the number of distinct keys, not the number of records." } ],
    [ :code_demo, "The three shapes you will keep reusing",
      { "code" => "# 1. Membership: have I seen this?\nseen = Set.new\nitems.each { |i| puts \"dup!\" unless seen.add?(i) }\n\n# 2. Counting\ncounts = items.tally\n\n# 3. Index by key, then look up in O(1)\nby_id = records.to_h { |r| [r[:id], r] }\norders.each { |o| customer = by_id[o[:customer_id]] }",
        "language" => "ruby",
        "annotations" => [
          "`Set#add?` returns nil if already present — \"first time only\" in one call.",
          "`to_h` building an index is the hash join a database planner performs.",
          "Build the index once, outside the loop. Inside it, you have gained nothing."
        ] } ],
    [ :pitfall, "A mutable key is a lost entry",
      { "body" => "A hash key's `hash` value must not change while it is a key. " \
                  "Mutate an array used as a key and the entry becomes " \
                  "unreachable — the hash now points at a different bucket. " \
                  "Freeze keys, or use immutable values." } ],
    [ :comparison, "Array, Set, Hash",
      { "rows" => [
          { "aspect" => "Membership", "array" => "O(n)", "set" => "O(1)", "hash" => "O(1)" },
          { "aspect" => "Stores a value", "array" => "By index", "set" => "No", "hash" => "Yes" },
          { "aspect" => "Keeps order", "array" => "Yes", "set" => "Insertion", "hash" => "Insertion" },
          { "aspect" => "Memory", "array" => "Lowest", "set" => "Higher", "hash" => "Highest" }
        ],
        "columns" => { "array" => "Array", "set" => "Set", "hash" => "Hash" } } ],
    [ :scenario, "In production",
      { "situation" => "A deduplication job holds a Set of 80 million record " \
                       "fingerprints and the worker is killed by the OOM reaper.",
        "question" => "The algorithm is right. Now what?",
        "answer" => "O(1) lookup still costs O(n) memory, and at 80 million that " \
                    "does not fit. Options: process in sorted order so duplicates " \
                    "are adjacent and you only carry the previous key; shard the " \
                    "work by a hash of the fingerprint so each worker holds a " \
                    "slice; or use a Bloom filter when a small false-positive " \
                    "rate is acceptable. This is the trade reasserting itself." } ],
    [ :interview, "How this is asked",
      { "question" => "What must be true of an object used as a Hash key?",
        "good_answer" => "It must implement `hash` and `eql?` consistently — " \
                         "equal objects must have equal hashes — and its hash " \
                         "must not change while it is in use as a key. Otherwise " \
                         "the entry becomes unreachable." } ],
    [ :revision, "Recall",
      { "prompt" => "What does a hash map trade, and in which direction?",
        "answer" => "O(n) memory for O(1) average lookup instead of O(n) scanning." } ]
  ]
)

challenge!(
  slug: "first-duplicate", title: "The first repeat",
  topic: hm1, skill_slug: "hash-maps", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Write `first_duplicate(items)` returning the first value that " \
          "appears a second time, scanning left to right, or `nil`.\n\n" \
          "O(n) time. The hidden test has 100,000 elements, so an O(n^2) scan " \
          "will time out.",
  starter: "def first_duplicate(items)\n  # Your code here\nend\n",
  solution: "def first_duplicate(items)\n" \
            "  seen = Set.new\n" \
            "  items.each do |item|\n" \
            "    return item unless seen.add?(item)\n" \
            "  end\n" \
            "  nil\n" \
            "end\n",
  explanation: "`Set#add?` returns nil when the value was already present, so " \
               "\"return the first value I cannot add\" is the whole algorithm. " \
               "One pass, O(n) time, O(n) memory.",
  metadata: { "target_complexity" => "O(n)" },
  time_limit_ms: 3000,
  tests: [
    [ "finds the first repeat", "first_duplicate([1, 2, 3, 2, 1])", "2" ],
    [ "returns nil when all unique", "first_duplicate([1, 2, 3])", "nil" ],
    [ "handles adjacent duplicates", "first_duplicate([4, 4])", "4" ],
    [ "handles an empty list", "first_duplicate([])", "nil" ],
    [ "works with strings", "first_duplicate(%w[a b a])", '"a"' ],
    [ "is fast on 100,000 elements",
      "first_duplicate((1..100_000).to_a + [7])", "7", true ]
  ],
  hints: [
    [ :nudge, "You need to know whether you have seen a value before. What " \
              "answers that in O(1)?", 2 ],
    [ :concept, "A Set. And `add?` tells you whether the value was new in the " \
                "same call that inserts it.", 4 ],
    [ :solution, "`return item unless seen.add?(item)`", 7 ]
  ]
)

challenge!(
  slug: "optimize-index-inside-loop", title: "The index built in the wrong place",
  topic: hm1, skill_slug: "hash-maps", type: :optimize, difficulty: :medium, xp: 50,
  prompt: "`attach_customers(orders, customers)` pairs each order with its " \
          "customer's name. It uses a hash index — but it is still O(n*m) and " \
          "times out on the hidden test.\n\n" \
          "The output is correct. Find why it is slow and fix it.",
  starter: "def attach_customers(orders, customers)\n" \
           "  orders.map do |order|\n" \
           "    by_id = customers.to_h { |c| [c[:id], c[:name]] }\n" \
           "    [order[:id], by_id[order[:customer_id]]]\n" \
           "  end\n" \
           "end\n",
  solution: "def attach_customers(orders, customers)\n" \
            "  by_id = customers.to_h { |c| [c[:id], c[:name]] }\n" \
            "  orders.map { |order| [order[:id], by_id[order[:customer_id]]] }\n" \
            "end\n",
  explanation: "The index was rebuilt on every iteration, so the O(m) build cost " \
               "was paid n times — the hash bought nothing. Hoisting it out of " \
               "the loop makes it O(n + m). Building a lookup *inside* the loop " \
               "it was meant to speed up is one of the most common performance " \
               "bugs there is, and it is invisible in the output.",
  metadata: { "target_complexity" => "O(n + m)" },
  time_limit_ms: 3000,
  tests: [
    [ "pairs orders with names",
      "attach_customers([{id: 1, customer_id: 10}], [{id: 10, name: 'Asha'}])",
      '[[1, "Asha"]]' ],
    [ "gives nil for an unknown customer",
      "attach_customers([{id: 1, customer_id: 99}], [{id: 10, name: 'Asha'}])",
      "[[1, nil]]" ],
    [ "handles no orders", "attach_customers([], [{id: 1, name: 'A'}])", "[]" ],
    [ "is fast on 4,000 orders and 4,000 customers",
      "orders = (1..4000).map { |i| {id: i, customer_id: i} }; " \
      "customers = (1..4000).map { |i| {id: i, name: \"c\#{i}\"} }; " \
      "attach_customers(orders, customers).length", "4000", true ]
  ],
  hints: [
    [ :nudge, "Read the loop body. What work happens on every single iteration?", 3 ],
    [ :concept, "Building the index is O(m). Doing it n times is O(n*m) — the " \
                "same cost as no index at all.", 4 ],
    [ :solution, "Move the `by_id = ...` line above the `map`.", 8 ]
  ]
)

challenge!(
  slug: "debug-mutated-hash-key", title: "The entry that disappeared",
  topic: hm1, skill_slug: "hash-maps", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`tally_pairs(pairs)` should count how many times each `[a, b]` pair " \
          "appears, returning a hash from pair to count.\n\n" \
          "It loses counts: `[[1, 2], [1, 2]]` should give `{[1, 2] => 2}` but " \
          "gives two separate entries of 1. The bug is not in the counting.",
  starter: "def tally_pairs(pairs)\n" \
           "  counts = Hash.new(0)\n" \
           "  buffer = []\n" \
           "  pairs.each do |a, b|\n" \
           "    buffer.clear\n" \
           "    buffer.push(a, b)\n" \
           "    counts[buffer] += 1\n" \
           "  end\n" \
           "  counts\n" \
           "end\n",
  solution: "def tally_pairs(pairs)\n" \
            "  counts = Hash.new(0)\n" \
            "  pairs.each do |a, b|\n" \
            "    counts[[a, b].freeze] += 1\n" \
            "  end\n" \
            "  counts\n" \
            "end\n",
  explanation: "The same `buffer` array was reused as every key. A Hash records " \
               "a key's hash value at insertion time, so mutating that array " \
               "afterwards leaves the entry filed under a hash that no longer " \
               "matches it — the lookup misses and a fresh entry is created, " \
               "while the old one becomes unreachable. Building a new array per " \
               "pair fixes it; freezing it documents that a key must not change.",
  tests: [
    [ "counts a repeated pair", "tally_pairs([[1, 2], [1, 2]])", "{[1, 2] => 2}" ],
    [ "keeps distinct pairs apart",
      "tally_pairs([[1, 2], [3, 4]])", "{[1, 2] => 1, [3, 4] => 1}" ],
    [ "counts a mix",
      "tally_pairs([[1, 2], [3, 4], [1, 2]])", "{[1, 2] => 2, [3, 4] => 1}" ],
    [ "returns an empty hash for no pairs", "tally_pairs([])", "{}" ],
    [ "handles string elements",
      "tally_pairs([%w[a b], %w[a b]])", '{["a", "b"] => 2}', true ]
  ],
  hints: [
    [ :nudge, "Inspect the keys of the returned hash. Are they the pairs you " \
              "expected?", 3 ],
    [ :concept, "A Hash stores a key by its hash value at the moment of " \
                "insertion. What happens if that object changes afterwards?", 5 ],
    [ :solution, "Build a fresh array for each key instead of reusing one " \
                 "buffer, and `freeze` it so the mistake cannot recur.", 9 ]
  ]
)

question!(
  body: "Your code already uses a hash for lookups but is still slow. Where do " \
        "you look?",
  skill_slug: "hash-maps", type: "optimization", band: :mid, difficulty: :medium,
  topic: hm1,
  model: "First, whether the hash is built inside the loop it is meant to " \
         "optimise — rebuilding it per iteration costs the same as no index. " \
         "Then whether the keys collide badly because of a poor custom `hash`. " \
         "Then whether the real cost is elsewhere entirely: I/O, N+1 queries or " \
         "serialisation, which a profile would show.",
  answer_key: { "keywords" => [ "inside the loop", "rebuild", "collision",
                                "profile", "io", "n+1" ],
                "required" => [ "loop" ] },
  follow_ups: [
    { body: "The hash holds 50 million entries and the box has 8GB. What now?",
      trigger: "always",
      expects: [ "memory", "sort", "shard", "bloom", "batch", "stream" ],
      model: "The O(1) lookup is not free — it costs O(n) memory. I would process " \
             "in sorted order so duplicates are adjacent, shard the work by key " \
             "hash, or use a Bloom filter if a small false-positive rate is " \
             "tolerable." }
  ]
)

# ===================================================================== debugging
db1 = mission!(
  curriculum_module: debug_mod, slug: "reading-the-evidence", position: 1,
  name: "Stop guessing, read the stack trace", skill_slug: "debugging-skill",
  minutes: 7, xp: 15, difficulty: :easy,
  hook: "`undefined method 'name' for nil`. Most people start changing lines " \
        "until it goes away. The trace already told you which line, which " \
        "object, and what it expected.",
  summary: "Read bottom-up, form one hypothesis, prove it, then fix.",
  blocks: [
    [ :prose, "The loop",
      { "body" => "Reproduce, read, hypothesise, **prove**, fix, then add the " \
                  "test that would have caught it. The step people skip is " \
                  "proving — changing code and seeing the error vanish is not " \
                  "the same as knowing why." } ],
    [ :visual, "Anatomy of a trace",
      { "kind" => "growth_table",
        "sizes" => [ "what it tells you" ],
        "rows" => [
          { "label" => "NoMethodError", "values" => [ "the kind of failure" ] },
          { "label" => "undefined method 'name'", "values" => [ "what was called" ] },
          { "label" => "for nil", "values" => [ "what the receiver actually was" ] },
          { "label" => "app/services/report.rb:42", "values" => [ "where to look first" ] },
          { "label" => "frames below", "values" => [ "how execution got there" ] }
        ],
        "caption" => "\"for nil\" is the most valuable part: the bug is wherever " \
                     "that nil came from, which is usually *not* line 42." } ],
    [ :prediction, "Where is the bug?",
      { "question" => "`undefined method 'name' for nil` on line 42, which reads " \
                      "`customer.name`. Where is the bug most likely to be?",
        "options" => [ "On line 42 — it needs a nil check",
                       "Wherever `customer` was assigned, because the lookup failed",
                       "In the `name` method",
                       "In Ruby's method dispatch" ],
        "answer" => 1,
        "explanation" => "Line 42 is where the symptom surfaced. The bug is " \
                         "upstream: a lookup returned nothing and nobody noticed. " \
                         "Adding `&.` on line 42 hides it and ships a report with " \
                         "silently blank names — a worse bug, harder to find." } ],
    [ :interactive, "Symptom or cause?",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these is treating the cause?",
        "cases" => [
          { "sql" => "Add `&.` so the nil stops raising", "risk" => true,
            "why" => "Symptom. The missing record is still missing, now silently." },
          { "sql" => "Find why the lookup returned nil", "risk" => false,
            "why" => "Cause. Perhaps the id is wrong, or the record was deleted." },
          { "sql" => "Wrap the block in rescue nil", "risk" => true,
            "why" => "Worse than a symptom fix — it hides every future error too." },
          { "sql" => "Add a test that reproduces the nil", "risk" => false,
            "why" => "This is what stops it coming back." }
        ] } ],
    [ :code_demo, "Proving a hypothesis cheaply",
      { "code" => "# Hypothesis: by_id is missing some customer_ids.\n# Prove it before changing any logic.\n\nmissing = orders.map { |o| o[:customer_id] } - customers.map { |c| c[:id] }\nwarn \"orphan customer_ids: \#{missing.uniq.inspect}\"\n\n# Now you know whether the bug is the lookup, the data, or the join.",
        "language" => "ruby",
        "annotations" => [
          "One line of evidence beats ten minutes of guessing.",
          "`warn` goes to stderr, so it will not corrupt piped output.",
          "If `missing` is empty the hypothesis was wrong — that is useful too."
        ] } ],
    [ :pitfall, "`rescue nil` and bare `rescue`",
      { "body" => "`rescue nil` swallows every error, including the typo you " \
                  "introduced five minutes ago. A bare `rescue` without a class " \
                  "catches StandardError — broad enough to hide real bugs. " \
                  "Rescue the specific class you expect, and nothing else." } ],
    [ :scenario, "In production",
      { "situation" => "An endpoint fails for 0.3% of requests with a nil error. " \
                       "You cannot reproduce it locally. The trace points at a " \
                       "line that looks fine.",
        "question" => "How do you proceed without guessing?",
        "answer" => "Make the failure give you more evidence: log the inputs that " \
                    "led to it — the ids, not the whole payload — and look for " \
                    "what the failing 0.3% have in common. A nil that appears " \
                    "only sometimes is usually a data condition (deleted record, " \
                    "null column, race) rather than a logic error, and the shared " \
                    "property of the failures is the fastest route to it." } ],
    [ :interview, "How this is asked",
      { "question" => "Walk me through debugging something you cannot reproduce.",
        "good_answer" => "Narrow it with evidence rather than intuition: find what " \
                         "the failing cases share, add targeted logging or metrics " \
                         "to confirm a hypothesis, and only then change code. " \
                         "I would also resist the nil-guard reflex — making the " \
                         "error stop is not the same as fixing the cause." } ],
    [ :revision, "Recall",
      { "prompt" => "In `undefined method 'x' for nil`, which part points at the " \
                    "real bug?",
        "answer" => "\"for nil\" — the bug is wherever that nil was produced, not " \
                    "where it was used." } ]
  ]
)

challenge!(
  slug: "debug-silent-nil-guard", title: "The nil guard that hid a bug",
  topic: db1, skill_slug: "debugging-skill", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`report_lines(orders, customers)` should return `\"name: total\"` for " \
          "each order, and **raise** `KeyError` if an order references a " \
          "customer that does not exist — a missing customer means bad data, " \
          "and the report must not quietly omit it.\n\n" \
          "Someone silenced the error with `&.`, so the report now emits " \
          "`\": 250\"` for orphans. Restore the loud failure.",
  starter: "def report_lines(orders, customers)\n" \
           "  by_id = customers.to_h { |c| [c[:id], c] }\n" \
           "  orders.map do |order|\n" \
           "    customer = by_id[order[:customer_id]]\n" \
           "    \"\#{customer&.fetch(:name, nil)}: \#{order[:total]}\"\n" \
           "  end\n" \
           "end\n",
  solution: "def report_lines(orders, customers)\n" \
            "  by_id = customers.to_h { |c| [c[:id], c] }\n" \
            "  orders.map do |order|\n" \
            "    customer = by_id.fetch(order[:customer_id])\n" \
            "    \"\#{customer[:name]}: \#{order[:total]}\"\n" \
            "  end\n" \
            "end\n",
  explanation: "`Hash#fetch` raises KeyError on a missing key, which is exactly " \
               "the behaviour wanted: bad data should stop the report, not " \
               "produce a blank line that someone reads as a real customer. " \
               "`&.` converted a loud failure into a silent wrong answer — the " \
               "trade almost always goes the wrong way.",
  tests: [
    [ "formats a matched order",
      "report_lines([{id: 1, customer_id: 10, total: 250}], [{id: 10, name: 'Asha'}])",
      '["Asha: 250"]' ],
    [ "raises for an orphan order",
      "begin; report_lines([{id: 1, customer_id: 99, total: 250}], " \
      "[{id: 10, name: 'Asha'}]); rescue KeyError; 'raised'; end", '"raised"' ],
    [ "handles several orders",
      "report_lines([{id: 1, customer_id: 10, total: 5}, {id: 2, customer_id: 10, total: 6}], " \
      "[{id: 10, name: 'A'}])", '["A: 5", "A: 6"]' ],
    [ "handles no orders", "report_lines([], [{id: 1, name: 'A'}])", "[]", true ]
  ],
  hints: [
    [ :nudge, "Which Hash method raises when a key is absent, instead of " \
              "returning nil?", 3 ],
    [ :concept, "`by_id[key]` returns nil; `by_id.fetch(key)` raises KeyError.", 4 ],
    [ :solution, "Use `by_id.fetch(order[:customer_id])` and drop the `&.`.", 8 ]
  ]
)

challenge!(
  slug: "find-the-off-by-one", title: "The loop that misses the last item",
  topic: db1, skill_slug: "debugging-skill", type: :implement, difficulty: :easy, xp: 35,
  prompt: "`window_sums(numbers, size)` should return the sum of every " \
          "contiguous window of the given size.\n\n" \
          "For `[1, 2, 3]` with size 2 that is `[3, 5]` — two windows. " \
          "Write it so the last window is never missed, and return `[]` when " \
          "the list is shorter than the window.",
  starter: "def window_sums(numbers, size)\n  # Your code here\nend\n",
  solution: "def window_sums(numbers, size)\n" \
            "  return [] if size <= 0 || numbers.length < size\n" \
            "  (0..(numbers.length - size)).map { |i| numbers[i, size].sum }\n" \
            "end\n",
  explanation: "The number of windows is `length - size + 1`, so the last start " \
               "index is `length - size` — which is why the range is inclusive " \
               "(`..`, not `...`). Getting that boundary wrong by one is the " \
               "single most common loop bug, and the guard clause handles the " \
               "degenerate cases before the arithmetic can go negative.",
  metadata: { "target_complexity" => "O(n * size)" },
  tests: [
    [ "returns both windows", "window_sums([1, 2, 3], 2)", "[3, 5]" ],
    [ "returns one window when size equals length", "window_sums([1, 2], 2)", "[3]" ],
    [ "returns empty when the list is too short", "window_sums([1], 2)", "[]" ],
    [ "handles size 1", "window_sums([1, 2, 3], 1)", "[1, 2, 3]" ],
    [ "returns empty for an empty list", "window_sums([], 2)", "[]" ],
    [ "counts windows correctly on a longer list",
      "window_sums((1..10).to_a, 3).length", "8" ],
    [ "returns empty for a non-positive size", "window_sums([1, 2], 0)", "[]", true ]
  ],
  hints: [
    [ :nudge, "For a list of 3 and a window of 2, how many windows are there? " \
              "What is the last valid start index?", 2 ],
    [ :concept, "Windows = length - size + 1. The last start index is " \
                "length - size, so the range must be inclusive.", 4 ],
    [ :solution, "`(0..(numbers.length - size)).map { |i| numbers[i, size].sum }`, " \
                 "guarded for short lists.", 8 ]
  ]
)

question!(
  body: "A bug appears for 0.3% of requests and you cannot reproduce it locally. " \
        "How do you find it?",
  skill_slug: "debugging-skill", type: "debugging", band: :mid, difficulty: :hard,
  topic: db1, company_type: "product",
  model: "Find what the failing cases have in common rather than guessing at " \
         "code. Add targeted logging of the identifying inputs, or capture the " \
         "failures with error tracking, and look for a shared property — a null " \
         "column, a deleted record, a particular locale, a race between two " \
         "requests. Confirm the hypothesis with evidence before changing " \
         "anything, then add a test that reproduces it.",
  mistakes: "Adding nil guards until the error stops, which converts a visible " \
            "failure into silently wrong data.",
  answer_key: { "keywords" => [ "common", "logging", "hypothesis", "evidence",
                                "reproduce", "test", "data" ],
                "required" => [ "hypothesis" ] },
  follow_ups: [
    { body: "Why not just add a nil check and move on?",
      trigger: "always",
      expects: [ "hide", "silent", "wrong", "cause", "symptom" ],
      model: "Because it treats the symptom. The missing value is still missing; " \
             "now it produces wrong output instead of an error, which is harder " \
             "to detect and may corrupt downstream data." },
    { body: "You suspect a race condition. How would you confirm it?",
      trigger: "keyword", keywords: [ "race", "concurren", "thread", "lock" ],
      expects: [ "timestamp", "log", "order", "lock", "reproduce", "load" ],
      model: "Log request ids with timestamps around the critical section and " \
             "look for interleaving in the failures, or try to reproduce under " \
             "concurrent load. Then fix it with a lock, a unique constraint, or " \
             "an idempotency key rather than by retrying." }
  ]
)

# =========================================================================== Git
g1 = mission!(
  curriculum_module: git_mod, slug: "git-is-a-graph", position: 1,
  name: "Git is a graph, not a timeline", skill_slug: "git-fundamentals",
  minutes: 7, xp: 15,
  hook: "You ran `git reset --hard` and your work vanished. It almost certainly " \
        "still exists. Git only really deletes things weeks later — but you have " \
        "to understand what a commit *is* to get it back.",
  summary: "Commits, branches as pointers, and the three places your work lives.",
  blocks: [
    [ :visual, "The three places a change can be",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "working tree", "points_to" => "edited but unrecorded" },
                     { "label" => "staging area", "points_to" => "chosen for the next commit" },
                     { "label" => "commit", "points_to" => "permanent snapshot" } ],
        "objects" => [ { "id" => "edited but unrecorded", "value" => "git diff shows this" },
                       { "id" => "chosen for the next commit", "value" => "git diff --staged shows this" },
                       { "id" => "permanent snapshot", "value" => "git log shows this" } ],
        "caption" => "Most Git confusion is not knowing which of the three a " \
                     "command operates on." } ],
    [ :prose, "A branch is just a pointer",
      { "body" => "A commit is a snapshot plus a parent. A branch is a movable " \
                  "label pointing at one commit, and HEAD points at the branch " \
                  "you are on. \"Switching branches\" moves a label — it does " \
                  "not copy files around." } ],
    [ :prediction, "What does reset --hard destroy?",
      { "question" => "You commit work, then run `git reset --hard HEAD~1`. " \
                      "What is actually gone?",
        "options" => [ "The commit, permanently",
                       "Nothing — the commit is unreferenced but still in the repo",
                       "Only the staging area",
                       "The whole branch" ],
        "answer" => 1,
        "explanation" => "The commit still exists; you only moved the branch " \
                         "label off it. `git reflog` shows where the branch " \
                         "pointed, and `git reset --hard <that sha>` puts it " \
                         "back. What `--hard` *does* destroy irrecoverably is " \
                         "uncommitted working-tree changes — those were never " \
                         "snapshotted." } ],
    [ :code_demo, "Undo, by what you actually want",
      { "code" => "# Keep the changes, undo the commit\ngit reset --soft HEAD~1    # changes back in staging\ngit reset HEAD~1           # changes back in working tree\n\n# Throw the changes away too (the dangerous one)\ngit reset --hard HEAD~1\n\n# Undo a commit that is already pushed: add an inverse commit\ngit revert <sha>\n\n# Find where a branch used to point\ngit reflog",
        "language" => "bash",
        "annotations" => [
          "--soft keeps staging, default keeps the working tree, --hard discards both.",
          "Use revert for shared history: reset rewrites it and breaks collaborators.",
          "reflog is the undo history for branch movements — it is how you recover."
        ] } ],
    [ :interactive, "Step through the graph",
      { "kind" => "risk_spotter",
        "prompt" => "Which command fits each intention?",
        "cases" => [
          { "sql" => "Undo my last commit but keep the code", "risk" => false,
            "why" => "git reset --soft HEAD~1" },
          { "sql" => "Undo a commit other people have already pulled", "risk" => true,
            "why" => "git revert — never reset shared history." },
          { "sql" => "Put aside half-finished work to switch branches", "risk" => false,
            "why" => "git stash" },
          { "sql" => "Recover a branch I just reset away", "risk" => true,
            "why" => "git reflog, then reset to the old sha." }
        ] } ],
    [ :pitfall, "Rewriting shared history",
      { "body" => "`reset`, `rebase` and `commit --amend` create *new* commits " \
                  "and move labels. On a branch nobody else has, that is tidy. " \
                  "On a shared branch it means everyone else's history disagrees " \
                  "with yours, and the next person to push will either be blocked " \
                  "or will reintroduce what you removed." } ],
    [ :scenario, "In production",
      { "situation" => "A colleague force-pushed to `main`, and three commits " \
                       "from other people are no longer in the history.",
                "question" => "How would you recover them?",
        "answer" => "The commits still exist in any clone that has them. " \
                    "`git reflog` on a machine that fetched before the force-push " \
                    "shows the previous `main` sha; from there you can cherry-pick " \
                    "or reset a recovery branch and push that. Then protect the " \
                    "branch so force-pushes are rejected — the fix is the " \
                    "guardrail, not just the recovery." } ],
    [ :interview, "How this is asked",
      { "question" => "What is the difference between `git revert` and " \
                      "`git reset`?",
        "good_answer" => "`reset` moves the branch pointer, rewriting what the " \
                         "branch's history looks like; `revert` leaves history " \
                         "alone and adds a new commit that undoes a previous " \
                         "one. Reset is for local work that has not been shared, " \
                         "revert is for anything already pushed." } ],
    [ :revision, "Recall",
      { "prompt" => "Which command undoes a pushed commit safely, and why?",
        "answer" => "`git revert` — it adds an inverse commit instead of " \
                    "rewriting shared history." } ]
  ]
)

challenge!(
  slug: "git-replay-history", title: "Replay the commit graph",
  topic: g1, skill_slug: "git-fundamentals", type: :implement, difficulty: :medium, xp: 40,
  prompt: "A commit is a snapshot plus a parent, so history is a linked list. " \
          "Model it.\n\n" \
          "Write `history(commits, head)` where `commits` is a hash of " \
          "`sha => parent_sha` (the first commit's parent is `nil`). Return the " \
          "shas from `head` back to the root, newest first.\n\n" \
          "Return `[]` if `head` is not in the hash. Guard against a cycle: " \
          "never visit the same sha twice.",
  starter: "def history(commits, head)\n  # Your code here\nend\n",
  solution: "def history(commits, head)\n" \
            "  return [] unless commits.key?(head)\n" \
            "  seen = Set.new\n" \
            "  shas = []\n" \
            "  current = head\n" \
            "  while current && commits.key?(current) && seen.add?(current)\n" \
            "    shas << current\n" \
            "    current = commits[current]\n" \
            "  end\n" \
            "  shas\n" \
            "end\n",
  explanation: "This is what `git log` does: start at HEAD and follow parent " \
               "pointers. The `seen` set is not paranoia — a corrupted or " \
               "hand-built graph with a cycle would otherwise loop forever, and " \
               "`Set#add?` makes the guard a single condition.",
  metadata: { "target_complexity" => "O(n)" },
  tests: [
    [ "walks a three-commit history",
      "history({'c' => 'b', 'b' => 'a', 'a' => nil}, 'c')", '["c", "b", "a"]' ],
    [ "returns one sha for the root", "history({'a' => nil}, 'a')", '["a"]' ],
    [ "returns empty for an unknown head",
      "history({'a' => nil}, 'zz')", "[]" ],
    [ "stops at a missing parent",
      "history({'c' => 'b'}, 'c')", '["c"]' ],
    [ "does not loop on a cycle",
      "history({'a' => 'b', 'b' => 'a'}, 'a')", '["a", "b"]' ],
    [ "handles an empty repository", "history({}, 'a')", "[]", true ]
  ],
  hints: [
    [ :nudge, "Follow the parent pointer from head until there is no parent.", 3 ],
    [ :concept, "Track visited shas so a cycle cannot spin forever — `Set#add?` " \
                "returns nil the second time.", 4 ],
    [ :solution, "`while current && commits.key?(current) && seen.add?(current)`", 8 ]
  ]
)

challenge!(
  slug: "debug-git-merge-base", title: "The merge base that finds the wrong commit",
  topic: g1, skill_slug: "git-fundamentals", type: :debug, difficulty: :hard, xp: 55,
  prompt: "`merge_base(commits, a, b)` should find the most recent common " \
          "ancestor of two commits — what Git uses to decide what a merge " \
          "actually has to combine.\n\n" \
          "It returns the *root* commit instead of the nearest shared one, " \
          "because it compares the two histories in the wrong direction.\n\n" \
          "Fix it.",
  starter: "def merge_base(commits, a, b)\n" \
           "  walk = lambda do |sha|\n" \
           "    path = []\n" \
           "    while sha && commits.key?(sha)\n" \
           "      path << sha\n" \
           "      sha = commits[sha]\n" \
           "    end\n" \
           "    path\n" \
           "  end\n\n" \
           "  (walk.call(a) & walk.call(b)).last\n" \
           "end\n",
  solution: "def merge_base(commits, a, b)\n" \
            "  walk = lambda do |sha|\n" \
            "    path = []\n" \
            "    while sha && commits.key?(sha)\n" \
            "      path << sha\n" \
            "      sha = commits[sha]\n" \
            "    end\n" \
            "    path\n" \
            "  end\n\n" \
            "  (walk.call(a) & walk.call(b)).first\n" \
            "end\n",
  explanation: "Each walk returns commits newest-first, so their intersection is " \
               "also newest-first. `.last` therefore picks the *oldest* common " \
               "ancestor — the root — when the question asks for the most recent " \
               "one. `.first` is the merge base. A one-word fix, but only " \
               "findable by knowing which end of the list is 'recent'.",
  tests: [
    [ "finds the nearest common ancestor",
      "merge_base({'f' => 'b', 'e' => 'd', 'd' => 'b', 'b' => 'a', 'a' => nil}, 'f', 'e')",
      '"b"' ],
    [ "returns the shared commit itself when one is an ancestor",
      "merge_base({'c' => 'b', 'b' => 'a', 'a' => nil}, 'c', 'b')", '"b"' ],
    [ "returns the root when branches diverge immediately",
      "merge_base({'c' => 'a', 'b' => 'a', 'a' => nil}, 'c', 'b')", '"a"' ],
    [ "is the same commit when both are equal",
      "merge_base({'b' => 'a', 'a' => nil}, 'b', 'b')", '"b"' ],
    [ "returns nil when there is no common ancestor",
      "merge_base({'b' => nil, 'a' => nil}, 'a', 'b')", "nil", true ]
  ],
  hints: [
    [ :nudge, "Print both walks. Which end of each list is the most recent " \
              "commit?", 3 ],
    [ :concept, "The walk appends newest first, so the intersection is ordered " \
                "newest to oldest.", 5 ],
    [ :solution, "Take `.first` of the intersection, not `.last`.", 10 ]
  ]
)

question!(
  body: "What is the difference between `git revert` and `git reset`, and when " \
        "would you use each?",
  skill_slug: "git-fundamentals", type: "scenario", band: :associate, difficulty: :medium,
  topic: g1,
  model: "`reset` moves the branch pointer, which rewrites what the branch's " \
         "history looks like and can discard commits or working-tree changes. " \
         "`revert` leaves history intact and creates a new commit that undoes a " \
         "previous one. Reset is for local, unshared work; revert is for " \
         "anything already pushed, because rewriting shared history breaks " \
         "everyone who has pulled it.",
  mistakes: "Using `reset --hard` on a shared branch, or believing reset " \
            "permanently deletes commits (reflog usually still has them).",
  answer_key: { "keywords" => [ "pointer", "history", "new commit", "shared",
                                "rewrite", "pushed" ],
                "required" => [ "shared" ] },
  follow_ups: [
    { body: "You ran `git reset --hard` and lost a commit. Is it recoverable?",
      trigger: "always",
      expects: [ "reflog", "yes", "sha", "garbage" ],
      model: "Usually yes: the commit is unreferenced but still in the object " \
             "store until garbage collection. `git reflog` shows where the " \
             "branch pointed, and you can reset back to that sha. Uncommitted " \
             "working-tree changes, though, are genuinely gone." },
    { body: "What is the difference between --soft, mixed and --hard?",
      trigger: "always",
      expects: [ "staging", "working tree", "discard", "index" ],
      model: "`--soft` moves the pointer and leaves changes staged; the default " \
             "(mixed) unstages them but keeps the working tree; `--hard` " \
             "discards both — it is the only one that loses work." }
  ]
)
