include SeedDSL
# Phase 5: computer science foundations — number systems, memory, processes
# and the security consequences of each. Fills the last two empty skills.
puts "  Phase 5: computer science, memory, concurrency and security"

city = World.find_by!(slug: "computer-city")

fortress = World.find_or_create_by!(slug: "security-fortress") do |w|
  w.name = "Security Fortress"
  w.position = 7
  w.accent_color = "#f87171"
  w.icon = "🛡"
  w.tagline = "Every input is hostile until proven otherwise."
  w.summary = "Injection, authorisation and the defaults that save you."
end

skills = [
  { slug: "concurrency", name: "Processes & Concurrency", world: city, tier: 2,
    position: 5, grid_x: 9, grid_y: 2,
    summary: "Threads, races, locks — and why Rails thread count matters.",
    prerequisites: %w[memory-model] },
  { slug: "web-security", name: "Web Security", world: fortress, tier: 3,
    position: 1, grid_x: 13, grid_y: 3,
    summary: "Injection, IDOR, mass assignment and secure defaults.",
    prerequisites: %w[sql-basics ruby-collections] }
]

skills.each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

num_mod = curriculum_module!(
  world_slug: "computer-city", slug: "number-systems-module", position: 1,
  name: "Binary & Hex", summary: "Why computers count in twos."
)
mem_mod = curriculum_module!(
  world_slug: "computer-city", slug: "memory-module", position: 2,
  name: "Memory & References", summary: "Stack, heap, and who can see your object."
)
conc_mod = curriculum_module!(
  world_slug: "computer-city", slug: "concurrency-module", position: 3,
  name: "Concurrency", summary: "Two things at once, and the bugs that follow."
)
sec_mod = curriculum_module!(
  world_slug: "security-fortress", slug: "security-module", position: 1,
  name: "Web Security", summary: "The vulnerabilities you will actually meet."
)

# =============================================================== number systems
n1 = mission!(
  curriculum_module: num_mod, slug: "binary-and-hex", position: 1,
  name: "Why 0.1 + 0.2 is not 0.3", skill_slug: "number-systems",
  minutes: 6, xp: 10,
  hook: "`0.1 + 0.2 == 0.3` is false in Ruby, JavaScript, Python and C. It is " \
        "not a bug in any of them. It is what base 2 does to a number that is " \
        "tidy in base 10.",
  summary: "Base 2, hex as shorthand, and floating point in money code.",
  blocks: [
    [ :prose, "Base 2, and what it cannot represent",
      { "body" => "A binary fraction can only represent sums of halves, " \
                  "quarters, eighths and so on. One tenth is not such a sum, so " \
                  "0.1 is stored as the nearest available value — slightly off. " \
                  "Add two slightly-off numbers and the error is visible." } ],
    [ :visual, "The same value, three bases",
      { "kind" => "growth_table",
        "sizes" => [ "binary", "hex" ],
        "rows" => [
          { "label" => "10", "values" => [ "1010", "a" ] },
          { "label" => "16", "values" => [ "10000", "10" ] },
          { "label" => "255", "values" => [ "11111111", "ff" ] },
          { "label" => "4096", "values" => [ "1000000000000", "1000" ] }
        ],
        "caption" => "One hex digit is exactly four binary digits, which is the " \
                     "only reason hex exists: it is a readable shorthand for " \
                     "bit patterns." } ],
    [ :prediction, "What does it actually equal?",
      { "question" => "In Ruby, what does `0.1 + 0.2` evaluate to?",
        "options" => [ "0.3", "0.30000000000000004", "0.29999999999999999", "An error" ],
        "answer" => 1,
        "explanation" => "0.30000000000000004. Neither 0.1 nor 0.2 is exactly " \
                         "representable in base 2, so the sum carries their " \
                         "rounding error. This is why money is never stored as " \
                         "a float — use integer cents, or BigDecimal." } ],
    [ :code_demo, "Money, done correctly",
      { "code" => "# Wrong: floats accumulate error\ntotal = 0.1 + 0.2\ntotal == 0.3            # => false\n\n# Right: integer cents, no fractions at all\ncents = 10 + 20         # => 30\n\n# Right: BigDecimal keeps decimal semantics\nrequire \"bigdecimal\"\nBigDecimal(\"0.1\") + BigDecimal(\"0.2\") == BigDecimal(\"0.3\")   # => true\n\n# Comparing floats: never ==, always a tolerance\n(0.1 + 0.2 - 0.3).abs < Float::EPSILON   # => true",
        "language" => "ruby",
        "annotations" => [
          "BigDecimal must be built from a String — BigDecimal(0.1) inherits the " \
          "float's error.",
          "Rails money columns are `decimal`, which maps to BigDecimal, for " \
          "exactly this reason.",
          "Integer cents is the simplest correct answer when you control the schema."
        ] } ],
    [ :interactive, "Which representation?",
      { "kind" => "risk_spotter",
        "prompt" => "Pick the storage for each value.",
        "cases" => [
          { "sql" => "A product price", "risk" => true,
            "why" => "Integer cents or decimal — never a float." },
          { "sql" => "A physics simulation coordinate", "risk" => false,
            "why" => "Float is correct; the tolerance is acceptable and speed matters." },
          { "sql" => "A permission bitmask", "risk" => false,
            "why" => "Integer, read in hex or binary. One bit per permission." },
          { "sql" => "A percentage shown to two places", "risk" => true,
            "why" => "Decimal, or an integer of basis points." }
        ] } ],
    [ :pitfall, "Rounding half-up is not what you get",
      { "body" => "`2.675.round(2)` gives 2.67, not 2.68 — because 2.675 is " \
                  "actually stored as slightly less than 2.675. Financial " \
                  "rounding rules need decimal arithmetic, not a float and a " \
                  "hope." } ],
    [ :scenario, "In production",
      { "situation" => "An invoicing system sums line items as floats. " \
                       "Occasionally a total is off by one cent, and the " \
                       "accounting reconciliation fails.",
        "question" => "Why is it only occasional, and what is the fix?",
        "answer" => "The error depends on which values happen to combine, so most " \
                    "invoices are fine and a few are not — which is why it " \
                    "survived testing. Store amounts as integer cents or " \
                    "decimals and sum in that type. Converting at the boundary " \
                    "is not enough: the error is introduced by the arithmetic, " \
                    "so the arithmetic has to change." } ],
    [ :interview, "How this is asked",
      { "question" => "Why should you never store money as a float?",
        "good_answer" => "Because decimal fractions like 0.1 have no exact " \
                         "binary representation, so arithmetic accumulates " \
                         "rounding error and totals drift. Integer cents or a " \
                         "decimal type keeps the arithmetic exact, which is what " \
                         "accounting requires." } ],
    [ :revision, "Recall",
      { "prompt" => "How many binary digits does one hex digit represent?",
        "answer" => "Exactly four." } ]
  ]
)

challenge!(
  slug: "money-in-cents", title: "Sum money without drift",
  topic: n1, skill_slug: "number-systems", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Write `total_cents(amounts)` summing an array of decimal strings " \
          "like `\"0.10\"` and returning the total in **integer cents**.\n\n" \
          "Parse each string to cents without going through a Float — that is " \
          "the whole point. `\"0.1\"`, `\"0.10\"` and `\"1\"` must all work.",
  starter: "def total_cents(amounts)\n  # Your code here\nend\n",
  solution: "def total_cents(amounts)\n" \
            "  amounts.sum do |amount|\n" \
            "    whole, fraction = amount.to_s.split(\".\")\n" \
            "    cents = fraction.to_s.ljust(2, \"0\")[0, 2]\n" \
            "    (whole.to_i * 100) + cents.to_i\n" \
            "  end\n" \
            "end\n",
  explanation: "Splitting the string and using integer arithmetic means no " \
               "binary fraction is ever created, so there is no error to " \
               "accumulate. `ljust(2, \"0\")` handles \"0.1\" meaning ten cents " \
               "rather than one. Going via `to_f` would reintroduce exactly the " \
               "drift this avoids.",
  tests: [
    [ "sums two values exactly", "total_cents(['0.10', '0.20'])", "30" ],
    [ "handles a single-digit fraction", "total_cents(['0.1'])", "10" ],
    [ "handles a whole number", "total_cents(['1'])", "100" ],
    [ "handles mixed formats", "total_cents(['1', '0.5', '0.05'])", "155" ],
    [ "returns zero for no amounts", "total_cents([])", "0" ],
    [ "does not drift over many additions",
      "total_cents(Array.new(100, '0.01'))", "100" ],
    [ "handles larger values", "total_cents(['19.99', '0.01'])", "2000", true ]
  ],
  hints: [
    [ :nudge, "If you call `to_f` anywhere, you have reintroduced the problem.", 3 ],
    [ :concept, "Split on the decimal point and work with the two halves as " \
                "integers. Pad the fraction to two digits.", 4 ],
    [ :solution, "`(whole.to_i * 100) + fraction.ljust(2, '0')[0, 2].to_i`", 8 ]
  ]
)

challenge!(
  slug: "debug-float-equality", title: "The comparison that is never true",
  topic: n1, skill_slug: "number-systems", type: :debug, difficulty: :easy, xp: 40,
  prompt: "`balanced?(debits, credits)` should report whether two lists of " \
          "float amounts sum to the same value.\n\n" \
          "It compares the sums with `==`, so accumulated floating-point error " \
          "makes it return false for lists that genuinely balance. Fix it with " \
          "a tolerance.",
  starter: "def balanced?(debits, credits)\n" \
           "  debits.sum == credits.sum\n" \
           "end\n",
  solution: "def balanced?(debits, credits)\n" \
            "  (debits.sum - credits.sum).abs < 1e-9\n" \
            "end\n",
  explanation: "Two different additions of the same mathematical value can land " \
               "on different floats, so `==` is the wrong test. Comparing the " \
               "absolute difference against a small tolerance asks the question " \
               "you actually meant. For money the better answer is not to use " \
               "floats at all — but when you are handed them, this is how you " \
               "compare them.",
  tests: [
    [ "accepts sums that balance despite float error",
      "balanced?([0.1, 0.2], [0.3])", "true" ],
    [ "rejects genuinely different sums", "balanced?([0.1], [0.2])", "false" ],
    [ "handles empty lists", "balanced?([], [])", "true" ],
    [ "handles many small values",
      "balanced?(Array.new(10, 0.1), [1.0])", "true" ],
    [ "rejects a one-cent difference", "balanced?([1.00], [1.01])", "false" ],
    [ "handles negatives", "balanced?([-0.1, -0.2], [-0.3])", "true", true ]
  ],
  hints: [
    [ :nudge, "Print both sums. Are they equal, or just nearly?", 2 ],
    [ :concept, "Floats that should be equal often differ in the last bits. " \
                "Compare the difference against a tolerance.", 4 ],
    [ :solution, "`(debits.sum - credits.sum).abs < 1e-9`", 8 ]
  ]
)

question!(
  body: "Why should money never be stored as a float?",
  skill_slug: "number-systems", type: "scenario", band: :junior, difficulty: :easy,
  topic: n1,
  model: "Decimal fractions such as 0.1 have no exact representation in base 2, " \
         "so each value carries a small rounding error and arithmetic " \
         "accumulates it. Totals then drift by fractions of a cent, which " \
         "breaks reconciliation. Integer cents or a decimal type keeps the " \
         "arithmetic exact.",
  answer_key: { "keywords" => [ "binary", "exact", "rounding", "cents",
                                "decimal", "bigdecimal" ],
                "required" => [ "exact" ] },
  follow_ups: [
    { body: "You said BigDecimal. What is the trap in constructing one?",
      trigger: "keyword", keywords: [ "bigdecimal", "decimal" ],
      expects: [ "string", "float", "literal" ],
      model: "It must be built from a String. `BigDecimal(0.1)` takes a Float " \
             "argument that already carries the error, so the exactness is lost " \
             "before BigDecimal sees it." },
    { body: "How would you compare two floats that should be equal?",
      trigger: "always",
      expects: [ "tolerance", "epsilon", "abs", "difference" ],
      model: "Compare the absolute difference against a small tolerance rather " \
             "than using `==`." }
  ]
)

# ================================================================ memory model
m1 = mission!(
  curriculum_module: mem_mod, slug: "stack-and-heap", position: 1,
  name: "Where your objects actually live", skill_slug: "memory-model",
  minutes: 7, xp: 15, difficulty: :easy,
  hook: "Two variables, one array, and a method that \"does not modify its " \
        "argument\" — except it does, and the caller sees it.",
  summary: "Stack frames, heap objects, and what a reference really passes.",
  blocks: [
    [ :prose, "Two places, two lifetimes",
      { "body" => "A **stack frame** holds a method's local variables and dies " \
                  "when the method returns. The **heap** holds objects, which " \
                  "live as long as something references them. A local variable " \
                  "on the stack holds a *reference* to a heap object — so " \
                  "passing it to a method passes the reference, not a copy." } ],
    [ :visual, "What gets copied",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "caller's list", "points_to" => "heap array" },
                     { "label" => "method's parameter", "points_to" => "heap array" } ],
        "objects" => [ { "id" => "heap array", "value" => "[1, 2, 3] — one object, two references" } ],
        "caption" => "The reference is copied; the array is not. Mutating through " \
                     "either name is visible through both." } ],
    [ :prediction, "Does the caller see it?",
      { "question" => "def add!(list) = list << 4\\n\\nnums = [1,2,3]; add!(nums); " \
                      "what is nums?",
        "options" => [ "[1, 2, 3]", "[1, 2, 3, 4]", "nil", "An error" ],
        "answer" => 1,
        "explanation" => "[1, 2, 3, 4]. The method received a reference to the " \
                         "same heap array and mutated it in place. Reassigning " \
                         "the parameter (`list = [9]`) would *not* be visible, " \
                         "because that only changes the method's own local." } ],
    [ :code_demo, "Mutation versus rebinding, across a call",
      { "code" => "def mutate(list)\n  list << 4          # visible to the caller\nend\n\ndef rebind(list)\n  list = [9]         # only changes this method's local\n  list\nend\n\nnums = [1, 2, 3]\nmutate(nums); p nums   # => [1, 2, 3, 4]\nrebind(nums); p nums   # => [1, 2, 3, 4]  (unchanged by rebind)\n\n# Defend by copying at the boundary\ndef safe(list)\n  local = list.dup   # shallow: nested objects are still shared\n  local << 4\n  local\nend",
        "language" => "ruby",
        "annotations" => [
          "A trailing `!` is only a naming convention — it does not make Ruby copy.",
          "`dup` is shallow. `[[1]].dup` shares the inner array.",
          "`freeze` turns accidental mutation into an immediate error."
        ] } ],
    [ :pitfall, "Memory leaks in a garbage-collected language",
      { "body" => "GC frees what is unreachable, so a \"leak\" in Ruby means " \
                  "something is still holding a reference: a growing class-level " \
                  "cache, a constant array you keep appending to, or a closure " \
                  "captured in a long-lived object. The memory is not lost — it " \
                  "is retained, which is harder to spot." } ],
    [ :interactive, "Shared or independent?",
      { "kind" => "risk_spotter",
        "prompt" => "After each operation, do the two names share state?",
        "cases" => [
          { "sql" => "b = a (a is an Array)", "risk" => true,
            "why" => "Shared — one object, two references." },
          { "sql" => "b = a.dup (flat array of integers)", "risk" => false,
            "why" => "Independent — integers are immutable values." },
          { "sql" => "b = a.dup (array of arrays)", "risk" => true,
            "why" => "The outer is copied; the inner arrays are shared." },
          { "sql" => "b = a + [] ", "risk" => false,
            "why" => "A new outer array — same caveat about nested objects." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A long-running worker's memory grows by 40MB an hour " \
                       "and never falls. Restarting fixes it for a while.",
        "question" => "What is the likely shape of the bug?",
        "answer" => "Retention, not a leak: something reachable keeps growing. " \
                    "The usual suspects are a class-level hash used as a cache " \
                    "with no eviction, a constant collection being appended to, " \
                    "or memoisation keyed by something unbounded like a user id. " \
                    "A heap dump comparing two points in time shows which class " \
                    "is accumulating, which is far faster than reading code." } ],
    [ :interview, "How this is asked",
      { "question" => "Is Ruby pass-by-value or pass-by-reference?",
        "good_answer" => "It passes references by value: the method gets a copy " \
                         "of the reference, so mutating the object is visible to " \
                         "the caller but reassigning the parameter is not. That " \
                         "single distinction explains most surprises about " \
                         "argument mutation." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is mutation visible to the caller but reassignment not?",
        "answer" => "The reference is copied, so both names point at one object; " \
                    "reassigning only changes the local copy of the reference." } ]
  ]
)

challenge!(
  slug: "deep-copy-nested", title: "A copy that is actually independent",
  topic: m1, skill_slug: "memory-model", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Write `deep_copy(value)` returning a copy of arbitrarily nested " \
          "arrays and hashes such that mutating any part of the copy leaves " \
          "the original untouched.\n\n" \
          "Leaf values are integers, strings, symbols, `nil`, `true`/`false`. " \
          "Strings must be copied too; the immutable leaves can be shared.",
  starter: "def deep_copy(value)\n  # Your code here\nend\n",
  solution: "def deep_copy(value)\n" \
            "  case value\n" \
            "  when Array then value.map { |v| deep_copy(v) }\n" \
            "  when Hash then value.to_h { |k, v| [deep_copy(k), deep_copy(v)] }\n" \
            "  when String then value.dup\n" \
            "  else value\n" \
            "  end\n" \
            "end\n",
  explanation: "Recursion is what makes it deep: `dup` copies one level, so " \
               "nested containers stay shared. Integers, symbols and booleans " \
               "are immutable, so sharing them is safe and copying them is " \
               "pointless — which is why the `else` branch returns the value " \
               "itself rather than duplicating it.",
  tests: [
    [ "copies a flat array", "deep_copy([1, 2])", "[1, 2]" ],
    [ "nested mutation does not reach the original",
      "a = [[1]]; b = deep_copy(a); b[0] << 2; a", "[[1]]" ],
    [ "copies hash values deeply",
      "a = {x: [1]}; b = deep_copy(a); b[:x] << 2; a", "{x: [1]}" ],
    [ "copies strings",
      "a = ['hi']; b = deep_copy(a); b[0] << '!'; a", '["hi"]' ],
    [ "handles deep nesting",
      "a = [[[1]]]; b = deep_copy(a); b[0][0] << 2; a", "[[[1]]]" ],
    [ "preserves equality", "deep_copy({a: [1, {b: 2}]})", "{a: [1, {b: 2}]}" ],
    [ "handles nil and booleans", "deep_copy([nil, true, :sym])", "[nil, true, :sym]", true ],
    [ "handles an empty structure", "deep_copy({})", "{}", true ]
  ],
  hints: [
    [ :nudge, "`dup` only copies one level. What do you do with the elements?", 3 ],
    [ :concept, "Recurse into arrays and hashes; return immutable leaves as they " \
                "are.", 4 ],
    [ :solution, "A `case` on the type, mapping arrays and hashes through " \
                 "`deep_copy` recursively.", 9 ]
  ]
)

challenge!(
  slug: "debug-retained-cache", title: "The cache that never forgets",
  topic: m1, skill_slug: "memory-model", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`Lookup.for(id)` memoises results in a class-level hash. In a " \
          "long-running worker that hash grows forever — a retention bug, not " \
          "a leak.\n\n" \
          "Bound it: keep at most `Lookup::LIMIT` entries, evicting the " \
          "**oldest inserted** when full. Keep the memoisation working.",
  starter: "class Lookup\n" \
           "  LIMIT = 3\n" \
           "  @@cache = {}\n\n" \
           "  def self.for(id)\n" \
           "    @@cache[id] ||= compute(id)\n" \
           "  end\n\n" \
           "  def self.compute(id)\n" \
           "    id * 10\n" \
           "  end\n\n" \
           "  def self.size\n" \
           "    @@cache.size\n" \
           "  end\n\n" \
           "  def self.reset!\n" \
           "    @@cache = {}\n" \
           "  end\n" \
           "end\n",
  solution: "class Lookup\n" \
            "  LIMIT = 3\n" \
            "  @@cache = {}\n\n" \
            "  def self.for(id)\n" \
            "    return @@cache[id] if @@cache.key?(id)\n\n" \
            "    @@cache.delete(@@cache.keys.first) while @@cache.size >= LIMIT\n" \
            "    @@cache[id] = compute(id)\n" \
            "  end\n\n" \
            "  def self.compute(id)\n" \
            "    id * 10\n" \
            "  end\n\n" \
            "  def self.size\n" \
            "    @@cache.size\n" \
            "  end\n\n" \
            "  def self.reset!\n" \
            "    @@cache = {}\n" \
            "  end\n" \
            "end\n",
  explanation: "Ruby hashes preserve insertion order, so the first key is the " \
               "oldest — which makes a bounded FIFO cache a two-line change. " \
               "This is the shape of most Ruby \"memory leaks\": nothing is " \
               "lost, something unbounded is retained. Note `key?` rather than " \
               "`||=`, so a cached `nil` or `false` would still count as a hit.",
  tests: [
    [ "memoises a value", "Lookup.reset!; Lookup.for(1); Lookup.for(1)", "10" ],
    [ "computes correctly", "Lookup.reset!; Lookup.for(5)", "50" ],
    [ "never exceeds the limit",
      "Lookup.reset!; (1..10).each { |i| Lookup.for(i) }; Lookup.size <= Lookup::LIMIT",
      "true" ],
    [ "evicts the oldest first",
      "Lookup.reset!; Lookup.for(1); Lookup.for(2); Lookup.for(3); Lookup.for(4); " \
      "Lookup.send(:class_variable_get, :@@cache).keys", "[2, 3, 4]" ],
    [ "still returns the right value after eviction",
      "Lookup.reset!; (1..10).each { |i| Lookup.for(i) }; Lookup.for(10)", "100" ],
    [ "does not recompute a cached entry",
      "Lookup.reset!; $n = 0; def Lookup.compute(id); $n += 1; id; end; " \
      "Lookup.for(1); Lookup.for(1); $n", "1", true ]
  ],
  hints: [
    [ :nudge, "What stops the hash growing? Nothing yet. Where would you put " \
              "the check?", 3 ],
    [ :concept, "Ruby hashes keep insertion order, so `keys.first` is the oldest " \
                "entry.", 5 ],
    [ :solution, "Before inserting, delete `@@cache.keys.first` while the size " \
                 "is at the limit.", 10 ]
  ]
)

question!(
  body: "A long-running Ruby worker's memory grows and never falls. How do you " \
        "investigate?",
  skill_slug: "memory-model", type: "debugging", band: :senior, difficulty: :hard,
  topic: m1, company_type: "product",
  model: "In a garbage-collected language this is retention, not a leak: " \
         "something reachable keeps growing. I would compare heap dumps between " \
         "two points in time to see which class is accumulating, rather than " \
         "reading code. The usual causes are an unbounded class-level cache or " \
         "memoisation, a constant collection being appended to, or a closure " \
         "held by a long-lived object.",
  mistakes: "Calling GC.start and hoping, or assuming Ruby leaks memory on its " \
            "own.",
  answer_key: { "keywords" => [ "retain", "reachable", "heap dump", "cache",
                                "memoi", "unbounded", "reference" ],
                "required" => [ "reference" ] },
  related: [ "garbage collection", "memoisation", "heap profiling" ],
  follow_ups: [
    { body: "Why is 'leak' the wrong word here?",
      trigger: "always",
      expects: [ "unreachable", "gc", "retain", "still referenced" ],
      model: "A leak means memory that can never be freed. GC frees anything " \
             "unreachable, so if memory is growing then something is still " \
             "holding a reference — the object is retained deliberately, just " \
             "not intentionally." },
    { body: "You find an unbounded memoisation hash. What is the fix?",
      trigger: "always",
      expects: [ "bound", "lru", "limit", "evict", "ttl" ],
      model: "Bound it: a size limit with LRU or FIFO eviction, or a TTL. If the " \
             "key space is genuinely unbounded, memoisation is the wrong tool " \
             "and the value should be recomputed or cached externally." }
  ]
)

# ================================================================= concurrency
c1 = mission!(
  curriculum_module: conc_mod, slug: "the-lost-update", position: 1,
  name: "Two requests, one counter, one lost update", skill_slug: "concurrency",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "Two users claim the last ticket at the same millisecond. Your code " \
        "checks availability, sees one left, and sells it. Twice.",
  summary: "Races, check-then-act, and the four ways to make it safe.",
  blocks: [
    [ :prose, "Check-then-act is the bug",
      { "body" => "`if available? then sell!` is two operations with a gap " \
                  "between them. Another process can change the world inside " \
                  "that gap, and nothing in the code can tell. Every race " \
                  "condition has this shape." } ],
    [ :visual, "The interleaving",
      { "kind" => "growth_table",
        "sizes" => [ "request A", "request B" ],
        "rows" => [
          { "label" => "t1", "values" => [ "read stock = 1", "" ] },
          { "label" => "t2", "values" => [ "", "read stock = 1" ] },
          { "label" => "t3", "values" => [ "write stock = 0, sell", "" ] },
          { "label" => "t4", "values" => [ "", "write stock = 0, sell" ] }
        ],
        "caption" => "Both reads happened before either write. Two tickets sold, " \
                     "stock shows 0, and no line of code is individually wrong." } ],
    [ :prediction, "Which fix actually works?",
      { "question" => "Which of these reliably prevents overselling?",
        "options" => [ "Re-check availability immediately before selling",
                       "A unique database constraint, or an atomic conditional update",
                       "Wrapping the read and write in a transaction",
                       "Sleeping briefly before the write" ],
        "answer" => 1,
        "explanation" => "Only a constraint or an atomic update closes the gap. " \
                         "Re-checking just makes the window smaller. A plain " \
                         "transaction does not help either: at the default " \
                         "isolation level both transactions can still read the " \
                         "old value — you need `SELECT ... FOR UPDATE`, a higher " \
                         "isolation level, or a single atomic statement." } ],
    [ :code_demo, "Four ways to close the gap",
      { "code" => "# 1. Atomic conditional update: the database decides the winner\nupdated = Ticket.where(id: id, sold: false).update_all(sold: true)\nsold = updated == 1          # exactly one request gets 1\n\n# 2. Row lock: serialise the readers\nTicket.transaction do\n  ticket = Ticket.lock.find(id)   # SELECT ... FOR UPDATE\n  ticket.update!(sold: true) unless ticket.sold?\nend\n\n# 3. A unique constraint: let the database refuse the duplicate\n# add_index :claims, [:ticket_id], unique: true\nClaim.create!(ticket_id: id)    # second one raises RecordNotUnique\n\n# 4. Optimistic locking: detect the conflict and retry\n# a `lock_version` column makes a stale write raise StaleObjectError",
        "language" => "ruby",
        "annotations" => [
          "Option 1 is usually the simplest correct answer and needs no lock.",
          "A unique constraint is the only one that cannot be bypassed by a code path.",
          "Locks serialise, which costs throughput — use the narrowest one."
        ] } ],
    [ :pitfall, "Threads in Rails, and why the pool size matters",
      { "body" => "Puma runs several threads per process, so your code is " \
                  "concurrent whether you planned for it or not. Each thread " \
                  "needs a database connection, so the connection pool must be " \
                  "at least as large as the thread count — otherwise threads " \
                  "queue for connections and you get `ConnectionTimeoutError` " \
                  "under load, which looks like a database problem and is not." } ],
    [ :interactive, "Safe under concurrency?",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these can two requests corrupt?",
        "cases" => [
          { "sql" => "UPDATE counters SET value = value + 1", "risk" => false,
            "why" => "Safe — the database performs the read and write atomically." },
          { "sql" => "value = read(); write(value + 1)", "risk" => true,
            "why" => "Classic lost update — the gap between read and write." },
          { "sql" => "INSERT with a unique index on the natural key", "risk" => false,
            "why" => "Safe — the second insert is rejected by the constraint." },
          { "sql" => "find_or_create_by without a unique index", "risk" => true,
            "why" => "Both can find nothing and both create. The index is what " \
                     "makes it safe." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A promo code limited to 100 uses was redeemed 118 times " \
                       "during a traffic spike. The code checks a count before " \
                       "creating a redemption.",
        "question" => "Why 118, and what is the fix?",
        "answer" => "Eighteen requests read the count before any of their writes " \
                    "landed, so they all saw fewer than 100 and all proceeded. " \
                    "The reliable fix is to make the database enforce the limit: " \
                    "an atomic `UPDATE promos SET used = used + 1 WHERE id = ? " \
                    "AND used < 100` and treat zero affected rows as a refusal. " \
                    "A unique constraint on (promo, user) additionally prevents " \
                    "one user double-redeeming." } ],
    [ :interview, "How this is asked",
      { "question" => "How would you stop the same ticket being sold twice?",
        "good_answer" => "Make the check and the write one atomic operation " \
                         "rather than two steps. An `UPDATE ... WHERE sold = " \
                         "false` and checking the affected row count is usually " \
                         "enough; a unique constraint is the strongest guarantee " \
                         "because no code path can bypass it. A row lock works " \
                         "but serialises requests, so I would reach for it only " \
                         "when the work genuinely needs the lock held." } ],
    [ :revision, "Recall",
      { "prompt" => "What shape does every race condition have?",
        "answer" => "Check-then-act: a gap between reading state and acting on " \
                    "it, during which the state can change." } ]
  ]
)

challenge!(
  slug: "atomic-claim", title: "Sell each ticket once",
  topic: c1, skill_slug: "concurrency", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Implement `Inventory#claim(id)`, which sells a ticket at most once " \
          "and returns `true` only for the call that succeeded.\n\n" \
          "Model the atomic conditional update: the check and the write must be " \
          "one indivisible step, so interleaved calls cannot both succeed. " \
          "Unknown ids return `false`.",
  starter: "class Inventory\n" \
           "  def initialize(ids)\n" \
           "    @sold = ids.to_h { |id| [id, false] }\n" \
           "  end\n\n" \
           "  def claim(id)\n" \
           "    # Your code here\n" \
           "  end\n" \
           "end\n",
  solution: "class Inventory\n" \
            "  def initialize(ids)\n" \
            "    @sold = ids.to_h { |id| [id, false] }\n" \
            "  end\n\n" \
            "  def claim(id)\n" \
            "    return false unless @sold.key?(id)\n" \
            "    return false if @sold[id]\n\n" \
            "    @sold[id] = true\n" \
            "  end\n" \
            "end\n",
  explanation: "The guard and the write sit together with nothing between them, " \
               "which is what `UPDATE ... WHERE sold = false` achieves in the " \
               "database: one statement, so no other request can observe the " \
               "intermediate state. Returning the result of the assignment makes " \
               "`true` mean \"this call is the one that sold it\".",
  tests: [
    [ "the first claim succeeds", "Inventory.new([1]).claim(1)", "true" ],
    [ "the second claim fails",
      "i = Inventory.new([1]); i.claim(1); i.claim(1)", "false" ],
    [ "an unknown id fails", "Inventory.new([1]).claim(99)", "false" ],
    [ "exactly one of many claims succeeds",
      "i = Inventory.new([1]); Array.new(10) { i.claim(1) }.count(true)", "1" ],
    [ "different tickets are independent",
      "i = Inventory.new([1, 2]); [i.claim(1), i.claim(2)]", "[true, true]" ],
    [ "handles an empty inventory", "Inventory.new([]).claim(1)", "false", true ]
  ],
  hints: [
    [ :nudge, "Two reasons to refuse: the id does not exist, or it is already " \
              "sold.", 2 ],
    [ :concept, "Guard, then write, with nothing in between — that is what makes " \
                "it atomic.", 4 ],
    [ :solution, "Return false unless the key exists, false if already sold, then " \
                 "`@sold[id] = true`.", 9 ]
  ]
)

challenge!(
  slug: "debug-lost-update", title: "The counter that loses increments",
  topic: c1, skill_slug: "concurrency", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`apply_all(counter, deltas)` should apply every delta to a counter.\n\n" \
          "It reads the value, computes a new one, then writes it back — " \
          "check-then-act. The provided counter interleaves a *stale read* " \
          "between your read and write, so increments are lost.\n\n" \
          "Use the counter's atomic `add(n)` instead. Return the final value.",
  starter: "def apply_all(counter, deltas)\n" \
           "  deltas.each do |delta|\n" \
           "    current = counter.value\n" \
           "    counter.value = current + delta\n" \
           "  end\n" \
           "  counter.value\n" \
           "end\n",
  solution: "def apply_all(counter, deltas)\n" \
            "  deltas.each { |delta| counter.add(delta) }\n" \
            "  counter.value\n" \
            "end\n",
  explanation: "Read-modify-write is three steps and only the middle one is " \
               "yours; anything can happen around it. `add` is a single atomic " \
               "operation, which is what `UPDATE ... SET value = value + 1` is " \
               "in SQL and what `INCR` is in Redis. The fix is never a smaller " \
               "gap — it is no gap.",
  tests: [
    [ "sums the deltas",
      "C = Struct.new(:value) do; def add(n); self[:value] += n; end; end; " \
      "apply_all(C.new(0), [1, 2, 3])", "6" ],
    [ "handles negative deltas",
      "E = Struct.new(:value) do; def add(n); self[:value] += n; end; end; " \
      "apply_all(E.new(10), [-3, -2])", "5" ],
    [ "handles no deltas",
      "F = Struct.new(:value) do; def add(n); self[:value] += n; end; end; " \
      "apply_all(F.new(7), [])", "7" ],
    [ "loses nothing across many deltas",
      "H = Struct.new(:value) do; def add(n); self[:value] += n; end; end; " \
      "apply_all(H.new(0), Array.new(100, 1))", "100" ],
    # The setter raises, so the only way to pass is the atomic `add`.
    [ "never uses the read-then-write pair",
      "G = Struct.new(:value) do; def add(n); self[:value] += n; end; " \
      "def value=(v); raise 'used non-atomic write'; end; end; " \
      "apply_all(G.new(0), [1, 2])", "3", true ]
  ],
  hints: [
    [ :nudge, "The counter offers a method that does the whole thing in one " \
              "step. Find it.", 3 ],
    [ :concept, "Read-modify-write has a gap. An atomic add has none.", 4 ],
    [ :solution, "`deltas.each { |delta| counter.add(delta) }`", 8 ]
  ]
)

question!(
  body: "A promo code limited to 100 uses was redeemed 118 times during a " \
        "traffic spike. Why, and how do you fix it?",
  skill_slug: "concurrency", type: "scenario", band: :senior, difficulty: :hard,
  topic: c1, company_type: "fintech",
  model: "A check-then-act race: many requests read the usage count before any " \
         "of their writes committed, so they all saw room and all proceeded. " \
         "The fix is to let the database enforce the limit atomically — " \
         "`UPDATE promos SET used = used + 1 WHERE id = ? AND used < 100`, " \
         "treating zero affected rows as a refusal — and a unique constraint on " \
         "(promo, user) to stop one user redeeming twice.",
  mistakes: "Adding a re-check before the write, which only narrows the window, " \
            "or assuming a transaction alone prevents it.",
  answer_key: { "keywords" => [ "race", "atomic", "constraint", "lock",
                                "update", "check" ],
                "required" => [ "atomic" ] },
  related: [ "isolation levels", "unique constraints", "optimistic locking" ],
  follow_ups: [
    { body: "Why doesn't wrapping it in a transaction fix it?",
      trigger: "always",
      expects: [ "isolation", "read", "still", "for update", "serializable" ],
      model: "At the default isolation level both transactions can read the same " \
             "old value and neither blocks the other. You need `SELECT ... FOR " \
             "UPDATE`, SERIALIZABLE isolation, or a single atomic statement." },
    { body: "How does Rails' connection pool relate to this under load?",
      trigger: "keyword", keywords: [ "thread", "puma", "pool", "concurren" ],
      expects: [ "pool", "threads", "timeout", "size" ],
      model: "Puma runs multiple threads, each needing a connection, so the pool " \
             "must be at least the thread count. Otherwise threads queue for " \
             "connections and raise ConnectionTimeoutError, which looks like a " \
             "database fault but is a configuration one." }
  ]
)

# ==================================================================== security
s1 = mission!(
  curriculum_module: sec_mod, slug: "every-input-is-hostile", position: 1,
  name: "The parameter that became a permission", skill_slug: "web-security",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "A user changes one number in a URL and reads someone else's invoice. " \
        "Nothing was hacked. The code simply never asked whether they were " \
        "allowed.",
  summary: "IDOR, mass assignment, injection — and the defaults that stop them.",
  blocks: [
    [ :prose, "Authentication is not authorisation",
      { "body" => "Knowing *who* someone is tells you nothing about *what* they " \
                  "may see. `Invoice.find(params[:id])` authenticates the user " \
                  "and then hands them any invoice they can name. Scoping the " \
                  "lookup to what they own — " \
                  "`current_user.invoices.find(params[:id])` — makes the " \
                  "authorisation structural rather than remembered." } ],
    [ :visual, "The three that account for most real breaches",
      { "kind" => "join_result",
        "result" => { "columns" => [ "vulnerability", "the mistake", "the default that prevents it" ],
                      "rows" => [
                        [ "IDOR", "Finding a record by id alone", "Scope every lookup to the owner" ],
                        [ "Mass assignment", "Passing raw params to update", "Permit an explicit list of attributes" ],
                        [ "SQL injection", "String-interpolating a query", "Bind parameters, always" ],
                        [ "XSS", "Rendering user HTML unescaped", "Escape by default; sanitise deliberately" ]
                      ] },
        "caption" => "None of these needs a clever attacker. Each is a missing " \
                     "default." } ],
    [ :prediction, "Which line is the vulnerability?",
      { "question" => "`@invoice = Invoice.find(params[:id])` followed by an " \
                      "authenticated-user check. What is wrong?",
        "options" => [ "Nothing — the user is authenticated",
                       "The lookup is not scoped to the current user",
                       "find should be find_by",
                       "params[:id] needs to be cast to an integer" ],
        "answer" => 1,
        "explanation" => "Authentication proves identity, not entitlement. Any " \
                         "logged-in user can substitute any id. Scoping the " \
                         "query to `current_user.invoices` means an " \
                         "unauthorised id raises RecordNotFound instead of " \
                         "leaking data — the safe outcome is the default." } ],
    [ :code_demo, "Scope, permit, bind",
      { "code" => "# IDOR: scope the lookup, do not check afterwards\n@invoice = current_user.invoices.find(params[:id])\n\n# Mass assignment: permit a list, never the whole hash\nparams.expect(user: [:name, :email])      # role is not permitted\n\n# SQL injection: bind, never interpolate\nUser.where(\"name = ?\", params[:name])     # safe\nUser.where(name: params[:name])           # safer still\n\n# Ordering is a common injection hole, because it cannot be bound\nALLOWED_SORTS = { \"name\" => :name, \"created\" => :created_at }.freeze\nUser.order(ALLOWED_SORTS.fetch(params[:sort], :id))",
        "language" => "ruby",
        "annotations" => [
          "A scoped lookup turns an authorisation bug into a 404 by construction.",
          "Column and table names cannot be bind parameters — use an allow-list.",
          "`params.expect` raises on unexpected shapes, which is the behaviour " \
          "you want for an attack."
        ] } ],
    [ :pitfall, "The sort parameter nobody checks",
      { "body" => "`order(params[:sort])` is injectable even though it looks " \
                  "harmless, because an identifier cannot be a bind parameter. " \
                  "The same applies to table names and to `pluck`. Where you " \
                  "cannot bind, you must allow-list." } ],
    [ :interactive, "Spot the hole",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these is exploitable?",
        "cases" => [
          { "sql" => "User.where(\"email = ?\", params[:email])", "risk" => false,
            "why" => "Bound — safe." },
          { "sql" => "User.where(\"email = '#{'#'}{params[:email]}'\")", "risk" => true,
            "why" => "Interpolated — injectable." },
          { "sql" => "Order.find(params[:id]) for a logged-in user", "risk" => true,
            "why" => "IDOR — not scoped to the owner." },
          { "sql" => "current_user.orders.find(params[:id])", "risk" => false,
            "why" => "Scoped — an unauthorised id simply is not found." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A penetration test reports that a support agent can read " \
                       "any customer's documents by changing the id, and that " \
                       "the profile form lets a user set their own `role`.",
        "question" => "What do you change, and in what order?",
        "answer" => "The mass-assignment hole first: it allows privilege " \
                    "escalation, which is strictly worse than reading data. " \
                    "Permit an explicit attribute list and keep `role` out of " \
                    "it entirely. Then scope every document lookup to what the " \
                    "requester is entitled to, rather than adding a check after " \
                    "the find — and add a policy object so the rule has one " \
                    "home. Finally, audit for the same two patterns elsewhere, " \
                    "because both are habits rather than one-off slips." } ],
    [ :interview, "How this is asked",
      { "question" => "What is IDOR and how do you prevent it systematically?",
        "good_answer" => "Insecure direct object reference: exposing a record by " \
                         "an id the user can change, without checking " \
                         "entitlement. Preventing it one controller at a time " \
                         "relies on memory, so I scope lookups through the " \
                         "owner association and use policy objects, so the " \
                         "unauthorised case fails by default rather than when " \
                         "someone remembers to check." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is a scoped lookup better than an authorisation check " \
                    "after the find?",
        "answer" => "It fails safe by construction — there is no path where the " \
                    "check can be forgotten." } ]
  ]
)

challenge!(
  slug: "permit-attributes", title: "Permit a list, not the hash",
  topic: s1, skill_slug: "web-security", type: :implement, difficulty: :easy, xp: 40,
  prompt: "Write `permit(params, allowed)` returning a new hash containing " \
          "only the keys in `allowed`.\n\n" \
          "This is strong parameters. Keys may arrive as strings or symbols and " \
          "must be compared by name, so `\"role\"` cannot sneak past a symbol " \
          "allow-list. Return symbol keys.",
  starter: "def permit(params, allowed)\n  # Your code here\nend\n",
  solution: "def permit(params, allowed)\n" \
            "  names = allowed.map(&:to_sym)\n" \
            "  params.each_with_object({}) do |(key, value), result|\n" \
            "    sym = key.to_sym\n" \
            "    result[sym] = value if names.include?(sym)\n" \
            "  end\n" \
            "end\n",
  explanation: "Normalising both sides to symbols before comparing is the whole " \
               "point: an allow-list that misses `\"role\"` because it only " \
               "checked for `:role` is not an allow-list. Building a new hash " \
               "rather than deleting from the input means anything you forgot to " \
               "consider is excluded by default.",
  tests: [
    [ "keeps permitted keys",
      "permit({name: 'A', role: 'admin'}, [:name])", "{name: \"A\"}" ],
    [ "drops unpermitted keys",
      "permit({name: 'A', role: 'admin'}, [:name]).key?(:role)", "false" ],
    [ "matches string keys against symbol rules",
      "permit({'role' => 'admin'}, [:name])", "{}" ],
    [ "permits string keys when allowed",
      "permit({'name' => 'A'}, [:name])", "{name: \"A\"}" ],
    [ "returns symbol keys",
      "permit({'name' => 'A'}, ['name']).keys", "[:name]" ],
    [ "returns empty for an empty allow-list",
      "permit({name: 'A'}, [])", "{}" ],
    [ "handles empty params", "permit({}, [:name])", "{}", true ]
  ],
  hints: [
    [ :nudge, "What if the param key is a String and the rule is a Symbol?", 3 ],
    [ :concept, "Normalise both to symbols, then build a new hash of what is " \
                "allowed.", 4 ],
    [ :solution, "Map `allowed` to symbols, then `each_with_object({})` keeping " \
                 "only matching keys.", 8 ]
  ]
)

challenge!(
  slug: "debug-idor-lookup", title: "Anyone can read anyone's invoice",
  topic: s1, skill_slug: "web-security", type: :debug, difficulty: :medium, xp: 55,
  prompt: "`find_invoice(user, invoices, id)` must return the invoice only if " \
          "it belongs to `user`, and `nil` otherwise.\n\n" \
          "It looks the invoice up by id across **all** invoices and returns it " \
          "regardless of owner — an IDOR. Fix it by scoping the lookup rather " \
          "than checking afterwards.",
  starter: "def find_invoice(user, invoices, id)\n" \
           "  invoices.find { |i| i[:id] == id }\n" \
           "end\n",
  solution: "def find_invoice(user, invoices, id)\n" \
            "  invoices.find { |i| i[:user_id] == user[:id] && i[:id] == id }\n" \
            "end\n",
  explanation: "Scoping the search by owner means an id belonging to someone " \
               "else simply is not found — the safe outcome is the default, with " \
               "no separate check to forget. In Rails this is the difference " \
               "between `Invoice.find(id)` and " \
               "`current_user.invoices.find(id)`, and it is why the association " \
               "form is worth making a habit.",
  tests: [
    [ "finds the user's own invoice",
      "find_invoice({id: 1}, [{id: 10, user_id: 1}], 10)", "{id: 10, user_id: 1}" ],
    [ "refuses another user's invoice",
      "find_invoice({id: 2}, [{id: 10, user_id: 1}], 10)", "nil" ],
    [ "returns nil for an unknown id",
      "find_invoice({id: 1}, [{id: 10, user_id: 1}], 99)", "nil" ],
    [ "picks the right invoice among several",
      "find_invoice({id: 1}, [{id: 10, user_id: 2}, {id: 11, user_id: 1}], 11)",
      "{id: 11, user_id: 1}" ],
    [ "does not leak when ids collide across users",
      "find_invoice({id: 2}, [{id: 10, user_id: 1}, {id: 11, user_id: 2}], 10)", "nil" ],
    [ "handles no invoices", "find_invoice({id: 1}, [], 1)", "nil", true ]
  ],
  hints: [
    [ :nudge, "The lookup never mentions the user. Should it?", 3 ],
    [ :concept, "Filter by owner *and* id in the same search, so an " \
                "unauthorised record is simply not found.", 4 ],
    [ :solution, "`invoices.find { |i| i[:user_id] == user[:id] && i[:id] == id }`", 9 ]
  ]
)

question!(
  body: "A penetration test finds that users can read other users' records by " \
        "changing an id, and can set their own role through the profile form. " \
        "Which do you fix first and why?",
  skill_slug: "web-security", type: "security", band: :senior, difficulty: :hard,
  topic: s1, company_type: "fintech",
  model: "The mass-assignment hole first, because it allows privilege " \
         "escalation — an attacker who can make themselves an admin gets " \
         "everything else for free, so it strictly dominates the read. Permit an " \
         "explicit attribute list with role excluded. Then fix the IDOR by " \
         "scoping lookups through the owner association rather than checking " \
         "after the find, and add policy objects so the rule has one home. " \
         "Finally audit for both patterns elsewhere, since each is a habit " \
         "rather than a single slip.",
  explanation: "The ranking matters: privilege escalation is worse than " \
               "unauthorised read.",
  mistakes: "Treating them as equal severity, or fixing the IDOR with an " \
            "after-the-fact check that the next controller will forget.",
  answer_key: { "keywords" => [ "privilege", "escalat", "permit", "scope",
                                "policy", "role", "idor" ],
                "required" => [ "escalat" ] },
  related: [ "strong parameters", "authorisation policies", "IDOR" ],
  follow_ups: [
    { body: "Why scope the lookup instead of checking ownership after finding it?",
      trigger: "always",
      expects: [ "default", "forget", "construction", "404", "fail safe" ],
      model: "Because a scoped query fails safe by construction: there is no code " \
             "path where the check can be omitted. An after-the-fact check relies " \
             "on every author remembering it in every action." },
    { body: "The sort column comes from a query parameter. Is that injectable?",
      trigger: "always",
      expects: [ "yes", "identifier", "allow-list", "cannot bind" ],
      model: "Yes — an identifier cannot be a bind parameter, so " \
             "`order(params[:sort])` is injectable. Map the parameter through an " \
             "allow-list of permitted columns." },
    { body: "How would you stop these classes of bug recurring?",
      trigger: "always",
      expects: [ "brakeman", "ci", "policy", "review", "test", "default" ],
      model: "Make the safe path the default and the unsafe one loud: policy " \
             "objects for authorisation, strong parameters everywhere, and a " \
             "static scanner such as Brakeman in CI so an interpolated query or " \
             "an unscoped find fails the build rather than review." }
  ]
)
