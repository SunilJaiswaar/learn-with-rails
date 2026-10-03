include SeedDSL
puts "  Programming Forest / Ruby Kingdom"

ruby34 = version!("ruby", "3.4")

basics_mod = curriculum_module!(
  world_slug: "programming-forest", slug: "ruby-foundations", position: 1,
  name: "Ruby Foundations", summary: "Values, names and the first errors you will meet."
)
blocks_mod = curriculum_module!(
  world_slug: "ruby-kingdom", slug: "blocks-and-enumerable", position: 1,
  name: "Blocks & Enumerable", summary: "The feature that makes Ruby feel like Ruby."
)

# ---------------------------------------------------------------- variables
r1 = mission!(
  curriculum_module: basics_mod, slug: "variables-are-labels", position: 1,
  name: "Variables are labels, not boxes", skill_slug: "ruby-basics",
  minutes: 5, xp: 10, technology: ruby34,
  hook: "You copy an array, change the copy, and the original changes too. " \
        "Nothing you wrote touched the original. What happened?",
  summary: "Assignment binds a name to an object. It does not copy the object.",
  blocks: [
    [ :visual, "Two labels, one object",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "a", "points_to" => "obj1" },
                     { "label" => "b", "points_to" => "obj1" } ],
        "objects" => [ { "id" => "obj1", "value" => "[1, 2, 3]" } ],
        "caption" => "`b = a` created a second label for the same array, " \
                     "not a second array." } ],
    [ :prose, "The rule",
      { "body" => "In Ruby a variable holds a reference to an object. " \
                  "Assignment copies the reference, never the object behind it." } ],
    [ :prediction, "What is printed?",
      { "question" => "a = [1, 2, 3]\nb = a\nb << 4\nputs a.inspect",
        "options" => [ "[1, 2, 3]", "[1, 2, 3, 4]", "nil", "an error" ],
        "answer" => 1,
        "explanation" => "`b << 4` mutates the array both names point at, so `a` " \
                         "shows the change. `<<` modifies in place; it does not " \
                         "build a new array." } ],
    [ :code_demo, "Mutation versus rebinding",
      { "code" => "a = [1, 2, 3]\nb = a\n\nb << 4          # mutates the shared array\np a              # => [1, 2, 3, 4]\n\nb = b + [5]     # rebinds b to a NEW array\np a              # => [1, 2, 3, 4]  (unchanged)\np b              # => [1, 2, 3, 4, 5]",
        "language" => "ruby",
        "annotations" => [
          "`<<` and `push` mutate the object in place — everyone sharing it sees it.",
          "`+` returns a new array, so `b` now points somewhere else.",
          "The bang/non-bang distinction (`map!` vs `map`) is this same idea."
        ] } ],
    [ :interactive, "Predict then run",
      { "kind" => "trace_table",
        "prompt" => "Track what each name points to after every line.",
        "steps" => [
          { "line" => "a = [1, 2]", "a" => "[1, 2]", "b" => "—" },
          { "line" => "b = a", "a" => "[1, 2]", "b" => "same object as a" },
          { "line" => "b << 3", "a" => "[1, 2, 3]", "b" => "[1, 2, 3]" },
          { "line" => "b = [9]", "a" => "[1, 2, 3]", "b" => "[9] (new object)" }
        ] } ],
    [ :pitfall, "Where this bites",
      { "body" => "Default arguments and constants are the classic traps: " \
                  "`def add(item, list = [])` makes a fresh array per call, but a " \
                  "frozen constant array shared across the app does not. " \
                  "Mutating a shared default is a bug that appears only on the " \
                  "second call." } ],
    [ :scenario, "In production",
      { "situation" => "A Rails service builds a response hash from a constant " \
                       "template, then merges request-specific keys with " \
                       "`template.merge!(extra)`. After a few requests, users " \
                       "start seeing each other's values.",
        "question" => "What is the bug?",
        "answer" => "`merge!` mutates the shared constant, so every request " \
                    "accumulates the previous ones' keys. Use `merge` (no bang) to " \
                    "return a new hash, and freeze the template so the mistake " \
                    "raises instead of leaking data." } ],
    [ :interview, "How this is asked",
      { "question" => "What does `b = a` do when `a` is an array?",
        "good_answer" => "It binds `b` to the same array object. Mutating through " \
                         "either name is visible through both; reassigning one " \
                         "name does not affect the other. A real copy needs " \
                         "`dup`, and a deep copy needs more than `dup`." } ],
    [ :revision, "Recall",
      { "prompt" => "Which of `<<`, `+`, `map`, `map!` mutate the receiver?",
        "answer" => "`<<` and `map!` mutate. `+` and `map` return new objects." } ]
  ]
)

# -------------------------------------------------------------- collections
r2 = mission!(
  curriculum_module: basics_mod, slug: "hash-default-trap", position: 2,
  name: "Counting things without a bug", skill_slug: "ruby-collections",
  minutes: 6, xp: 15, difficulty: :easy, technology: ruby34,
  hook: "You count word frequencies and get `nil can't be coerced into Integer`. " \
        "Your logic is right; the empty hash is the problem.",
  summary: "Hash defaults, and the three idiomatic ways to count.",
  blocks: [
    [ :prose, "Why it fails",
      { "body" => "`{}[:missing]` is `nil`, and `nil + 1` raises. " \
                  "A counter needs a starting value for keys it has not seen." } ],
    [ :prediction, "Which line raises?",
      { "question" => "counts = {}\ncounts[:a] += 1",
        "options" => [ "Neither — it works",
                       "The second line raises NoMethodError on nil",
                       "The second line sets counts[:a] to 1",
                       "The first line raises" ],
        "answer" => 1,
        "explanation" => "`counts[:a] += 1` expands to " \
                         "`counts[:a] = counts[:a] + 1`, and `counts[:a]` is nil. " \
                         "`nil + 1` raises NoMethodError." } ],
    [ :code_demo, "Three correct ways",
      { "code" => "words = %w[a b a c a]\n\n# 1. default value\ncounts = Hash.new(0)\nwords.each { |w| counts[w] += 1 }\n\n# 2. tally — says exactly what it means\ncounts = words.tally\n\n# 3. group then size, when you need the groups too\ncounts = words.group_by { |w| w }.transform_values(&:size)",
        "language" => "ruby",
        "annotations" => [
          "`Hash.new(0)` returns 0 for any missing key.",
          "`tally` is the clearest when you only want counts.",
          "Careful: `Hash.new([])` shares ONE array between all keys."
        ] } ],
    [ :pitfall, "The shared-default trap",
      { "body" => "`Hash.new([])` gives every missing key the *same* array, so " \
                  "`h[:a] << 1` is visible at `h[:b]`. Use the block form, " \
                  "`Hash.new { |h, k| h[k] = [] }`, which builds a fresh array per " \
                  "key and stores it." } ],
    [ :visual, "Default value vs default block",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "h[:a]", "points_to" => "shared" },
                     { "label" => "h[:b]", "points_to" => "shared" } ],
        "objects" => [ { "id" => "shared", "value" => "[] ← one array for every key" } ],
        "caption" => "Hash.new([]) — every missing key returns this same array." } ],
    [ :interactive, "Pick the right tool",
      { "kind" => "risk_spotter",
        "prompt" => "Which construct fits each job?",
        "cases" => [
          { "sql" => "Count occurrences of each value", "risk" => false,
            "why" => "`tally` — one call, obvious intent." },
          { "sql" => "Collect the items belonging to each key", "risk" => true,
            "why" => "`group_by`, or `Hash.new { |h,k| h[k] = [] }`. " \
                     "Never `Hash.new([])`." },
          { "sql" => "Sum amounts per key", "risk" => false,
            "why" => "`each_with_object(Hash.new(0))` or `sum` inside `group_by`." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A background job groups 2 million events by user with " \
                       "`events.group_by { |e| e[:user_id] }` and the worker is " \
                       "killed by the OOM reaper.",
        "question" => "Why, and what would you change?",
        "answer" => "`group_by` builds the entire result in memory, holding every " \
                    "event object at once. If you only need counts or sums, " \
                    "accumulate into a Hash while streaming the records in " \
                    "batches, so memory stays proportional to the number of keys " \
                    "rather than the number of events." } ],
    [ :interview, "How this is asked",
      { "question" => "What is the difference between `Hash.new(0)` and " \
                      "`Hash.new { |h, k| h[k] = 0 }`?",
        "good_answer" => "The first returns 0 for a missing key without storing " \
                         "anything, so the key stays absent until assigned. " \
                         "The second stores the key on first access. With a " \
                         "mutable default like an array, the value form shares one " \
                         "object across all keys while the block form creates one " \
                         "per key." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is `Hash.new([])` dangerous?",
        "answer" => "Every missing key returns the same array, so mutating one " \
                    "key's value changes them all." } ]
  ]
)

# ------------------------------------------------------------------- blocks
r3 = mission!(
  curriculum_module: blocks_mod, slug: "each-vs-map", position: 1,
  name: "each returns the wrong thing", skill_slug: "ruby-blocks",
  minutes: 6, xp: 15, difficulty: :easy, technology: ruby34,
  hook: "Your method returns the original array instead of the transformed one. " \
        "The block ran — you can see the output — but the return value is wrong.",
  summary: "What each and map return, and why that difference is everything.",
  blocks: [
    [ :prose, "The distinction",
      { "body" => "`each` exists for side effects and returns the receiver. " \
                  "`map` exists to build a new collection from the block's return " \
                  "values. Choosing the wrong one is the most common Ruby " \
                  "beginner bug." } ],
    [ :prediction, "What is returned?",
      { "question" => "result = [1, 2, 3].each { |n| n * 2 }\np result",
        "options" => [ "[2, 4, 6]", "[1, 2, 3]", "6", "nil" ],
        "answer" => 1,
        "explanation" => "`each` ignores the block's value and returns the array " \
                         "it was called on. The doubling happened and was thrown " \
                         "away. `map` is what keeps it." } ],
    [ :visual, "Side by side",
      { "kind" => "join_result",
        "result" => { "columns" => [ "call", "block value", "returns" ],
                      "rows" => [
                        [ "[1,2,3].each { |n| n*2 }", "2, 4, 6 (discarded)", "[1, 2, 3]" ],
                        [ "[1,2,3].map { |n| n*2 }", "2, 4, 6 (collected)", "[2, 4, 6]" ],
                        [ "[1,2,3].select { |n| n>1 }", "false, true, true", "[2, 3]" ],
                        [ "[1,2,3].sum", "—", "6" ]
                      ] },
        "caption" => "Every Enumerable method is defined by what it does with the " \
                     "block's return value." } ],
    [ :code_demo, "Building an array the long way",
      { "code" => "# What beginners write:\nresult = []\n[1, 2, 3].each { |n| result << n * 2 }\n\n# What it is:\nresult = [1, 2, 3].map { |n| n * 2 }\n\n# Chaining reads as a pipeline:\n[1, 2, 3, 4]\n  .select { |n| n.even? }   # => [2, 4]\n  .map    { |n| n * 10 }    # => [20, 40]\n  .sum                      # => 60",
        "language" => "ruby",
        "annotations" => [
          "`each` + `<<` is `map` written out by hand.",
          "Each step in a chain returns a new collection.",
          "If a chain gets long, name the intermediate value."
        ] } ],
    [ :interactive, "Choose the method",
      { "kind" => "risk_spotter",
        "prompt" => "Which Enumerable method does each job?",
        "cases" => [
          { "sql" => "Transform every element", "risk" => false, "why" => "`map`" },
          { "sql" => "Keep the elements that match", "risk" => false, "why" => "`select` (or `filter`)" },
          { "sql" => "Transform and drop the nils", "risk" => true, "why" => "`filter_map` — one pass" },
          { "sql" => "Find the first match", "risk" => false, "why" => "`find` — stops early" },
          { "sql" => "Reduce to a single value", "risk" => false, "why" => "`sum`, `reduce`, `inject`" }
        ] } ],
    [ :pitfall, "map when you meant each",
      { "body" => "The reverse mistake wastes memory: calling `map` purely for side " \
                  "effects builds an array of return values nobody reads. " \
                  "Over a million records that is a million objects of garbage." } ],
    [ :scenario, "In production",
      { "situation" => "A serializer calls " \
                       "`records.map { |r| r.update(synced: true) }` to flag rows, " \
                       "and the endpoint's memory use scales with the result size.",
        "question" => "What is wrong, beyond the memory?",
        "answer" => "`map` is being used for a side effect, so it allocates an " \
                    "array of update return values for nothing — `each` would do. " \
                    "The deeper problem is one UPDATE per record; " \
                    "`update_all` issues a single statement." } ],
    [ :interview, "How this is asked",
      { "question" => "When would you use `each_with_object` over `reduce`?",
        "good_answer" => "When the accumulator is mutable and you want to keep " \
                         "mutating it: `each_with_object` yields " \
                         "`(element, memo)` and always returns the memo, so you " \
                         "cannot lose it by forgetting to return it from the " \
                         "block, which is the classic `reduce` bug." } ],
    [ :revision, "Recall",
      { "prompt" => "`each` returns ___ and `map` returns ___.",
        "answer" => "`each` returns the original receiver; `map` returns a new " \
                    "array of the block's return values." } ]
  ]
)

# --------------------------------------------------------------- challenges
challenge!(
  slug: "word-frequency", title: "Count the words",
  topic: r2, skill_slug: "ruby-collections", type: :implement, difficulty: :easy, xp: 30,
  prompt: "Write `word_frequency(text)` that returns a Hash mapping each " \
          "lowercase word to how many times it appears.\n\n" \
          "Split on whitespace, downcase everything, and ignore empty strings. " \
          "Punctuation stays attached to the word — do not strip it.",
  starter: "def word_frequency(text)\n  # Your code here\nend\n",
  solution: "def word_frequency(text)\n  text.downcase.split.tally\nend\n",
  explanation: "`split` with no argument already splits on runs of whitespace and " \
               "discards empties, and `tally` is exactly \"count the occurrences\". " \
               "The hand-rolled `Hash.new(0)` version is correct too, but `tally` " \
               "states the intent in one word.",
  tests: [
    [ "counts repeats", "word_frequency('a b a')", '{"a" => 2, "b" => 1}' ],
    [ "is case insensitive", "word_frequency('The the THE')", '{"the" => 3}' ],
    [ "handles extra whitespace", "word_frequency('  a   b  ')", '{"a" => 1, "b" => 1}' ],
    [ "returns an empty hash for empty input", "word_frequency('')", "{}" ],
    [ "keeps punctuation attached", "word_frequency('hi! hi')", '{"hi!" => 1, "hi" => 1}', true ]
  ],
  hints: [
    [ :nudge, "`split` with no arguments handles runs of whitespace for you. " \
              "What is left is counting.", 2 ],
    [ :concept, "`{}[:missing]` is nil, so `+= 1` raises. Either seed the hash with " \
                "`Hash.new(0)` or use a method that counts for you.", 3 ],
    [ :solution, "`text.downcase.split.tally` — three transformations, no " \
                 "intermediate state.", 6 ]
  ]
)

challenge!(
  slug: "debug-shared-default", title: "Every key has everyone's items",
  topic: r2, skill_slug: "ruby-collections", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`group_items(pairs)` should turn `[[:fruit, 'apple'], [:veg, 'leek']]` " \
          "into `{fruit: ['apple'], veg: ['leek']}`.\n\n" \
          "Instead every key ends up holding every item. Find the cause and fix it.",
  starter: "def group_items(pairs)\n" \
           "  grouped = Hash.new([])\n" \
           "  pairs.each do |key, value|\n" \
           "    grouped[key] << value\n" \
           "  end\n" \
           "  grouped\n" \
           "end\n",
  solution: "def group_items(pairs)\n" \
            "  grouped = Hash.new { |hash, key| hash[key] = [] }\n" \
            "  pairs.each { |key, value| grouped[key] << value }\n" \
            "  grouped\n" \
            "end\n",
  explanation: "`Hash.new([])` evaluates its argument once, so every missing key " \
               "returns the *same* array object. `<<` mutates that shared array, " \
               "and because the key is never assigned, the hash also stays empty. " \
               "The block form runs per key and assigns the new array.",
  tests: [
    [ "groups two keys", "group_items([[:fruit, 'apple'], [:veg, 'leek']])",
      '{fruit: ["apple"], veg: ["leek"]}' ],
    [ "groups repeats under one key",
      "group_items([[:fruit, 'apple'], [:fruit, 'pear']])", '{fruit: ["apple", "pear"]}' ],
    [ "returns an empty hash for no pairs", "group_items([])", "{}" ],
    [ "keeps keys independent",
      "group_items([[:a, 1], [:b, 2], [:a, 3]])", "{a: [1, 3], b: [2]}", true ]
  ],
  hints: [
    [ :nudge, "Inspect `grouped` after the loop. Is the hash even storing keys?", 2 ],
    [ :concept, "`Hash.new([])` builds one array, once. Compare that with the " \
                "block form `Hash.new { |h, k| h[k] = [] }`.", 4 ],
    [ :solution, "Use the block form so each key gets its own array and the key is " \
                 "assigned on first touch.", 8 ]
  ]
)

challenge!(
  slug: "pipeline-refactor", title: "Replace each with a pipeline",
  topic: r3, skill_slug: "ruby-blocks", type: :optimize, difficulty: :medium, xp: 40,
  prompt: "`active_emails(users)` takes an array of hashes like " \
          "`{name:, email:, active:}` and should return the downcased emails of " \
          "active users who actually have an email, sorted alphabetically.\n\n" \
          "Rewrite it as an Enumerable pipeline. The behaviour must not change.",
  starter: "def active_emails(users)\n" \
           "  result = []\n" \
           "  users.each do |user|\n" \
           "    if user[:active]\n" \
           "      unless user[:email].nil? || user[:email].empty?\n" \
           "        result << user[:email].downcase\n" \
           "      end\n" \
           "    end\n" \
           "  end\n" \
           "  result.sort\n" \
           "end\n",
  solution: "def active_emails(users)\n" \
            "  users.filter_map do |user|\n" \
            "    user[:email].downcase if user[:active] && !user[:email].to_s.empty?\n" \
            "  end.sort\n" \
            "end\n",
  explanation: "`filter_map` selects and transforms in a single pass, which is " \
               "exactly this loop's job. `to_s` collapses the nil and empty cases " \
               "into one check.",
  metadata: { "target_complexity" => "O(n log n) — the sort dominates" },
  tests: [
    [ "keeps only active users with emails",
      "active_emails([{name: 'A', email: 'A@x.com', active: true}, " \
      "{name: 'B', email: 'b@x.com', active: false}])", '["a@x.com"]' ],
    [ "sorts the result",
      "active_emails([{name: 'A', email: 'z@x.com', active: true}, " \
      "{name: 'B', email: 'a@x.com', active: true}])", '["a@x.com", "z@x.com"]' ],
    [ "skips nil emails",
      "active_emails([{name: 'A', email: nil, active: true}])", "[]" ],
    [ "skips empty emails",
      "active_emails([{name: 'A', email: '', active: true}])", "[]" ],
    [ "handles an empty list", "active_emails([])", "[]", true ]
  ],
  hints: [
    [ :nudge, "You are selecting and transforming at the same time. " \
              "Is there one method for that?", 2 ],
    [ :concept, "`filter_map` keeps every truthy block result and drops nil/false.", 3 ],
    [ :solution, "`users.filter_map { |u| u[:email].downcase if ... }.sort`", 6 ]
  ]
)

# ---------------------------------------------------------------- questions
question!(
  body: "In Ruby, what is the difference between `dup` and a deep copy?",
  skill_slug: "ruby-basics", type: "scenario", band: :associate, difficulty: :medium,
  topic: r1,
  model: "`dup` makes a new object but copies references to the same nested " \
         "objects, so mutating a nested array is visible through both copies. " \
         "A deep copy duplicates the whole object graph.",
  explanation: "This is the reference-semantics lesson applied one level down.",
  mistakes: "Assuming `dup` is recursive, or using Marshal round-trips on objects " \
            "that are not marshallable.",
  answer_key: { "keywords" => [ "shallow", "reference", "nested", "deep" ],
                "required" => [ "shallow" ] },
  follow_ups: [
    { body: "Show me a case where `dup` is not enough.",
      trigger: "always",
      expects: [ "nested", "array", "hash", "mutate" ],
      model: "`a = [[1,2]]; b = a.dup; b[0] << 3` — `a[0]` now shows the 3, " \
             "because the inner array was shared." },
    { body: "How would you actually deep-copy it, and what is the catch?",
      trigger: "always",
      expects: [ "marshal", "recursive", "catch", "proc", "io" ],
      model: "`Marshal.load(Marshal.dump(obj))` works for plain data but raises on " \
             "procs, IO objects and singletons, and is slow. A purpose-written " \
             "recursive copy is usually better." }
  ]
)

question!(
  body: "You need to transform a collection and drop the entries that produce no " \
        "value. Which Enumerable method, and why not `map` followed by `compact`?",
  skill_slug: "ruby-blocks", type: "optimization", band: :mid, difficulty: :medium,
  topic: r3,
  model: "`filter_map`. It does both in a single pass, whereas `map.compact` " \
         "allocates an intermediate array containing the nils and then walks it " \
         "again.",
  answer_key: { "keywords" => [ "filter_map", "one pass", "intermediate", "allocat" ],
                "required" => [ "filter_map" ] },
  follow_ups: [
    { body: "Does that difference actually matter?",
      trigger: "always",
      expects: [ "depends", "size", "large", "memory", "hot path" ],
      model: "Not for a handful of elements. It matters on large collections or " \
             "hot paths, where the extra array is real allocation and GC pressure. " \
             "Below that, pick whichever reads more clearly." }
  ]
)
