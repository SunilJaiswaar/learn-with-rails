include SeedDSL
# Phase 4: the frontend universe. JavaScript semantics are taught through Ruby
# models of the same mechanics (the sandbox runs Ruby), which keeps every
# challenge executable and graded rather than multiple-choice.
puts "  Phase 4: frontend — JS semantics, the DOM and the event loop"

frontend = World.find_or_create_by!(slug: "frontend-universe") do |w|
  w.name = "Frontend Universe"
  w.position = 6
  w.accent_color = "#38bdf8"
  w.icon = "🖥"
  w.tagline = "The browser is a runtime with its own rules."
  w.summary = "Semantics, the event loop, the DOM and rendering cost."
end

skills = [
  { slug: "js-semantics", name: "JavaScript Semantics", world: frontend, tier: 2,
    position: 1, grid_x: 11, grid_y: 2,
    summary: "Scope, closures, this, and equality that surprises you.",
    prerequisites: %w[ruby-basics] },
  { slug: "event-loop", name: "The Event Loop", world: frontend, tier: 3,
    position: 1, grid_x: 11, grid_y: 3,
    summary: "Why async code runs in an order you did not write.",
    prerequisites: %w[js-semantics] },
  { slug: "dom-rendering", name: "DOM & Rendering", world: frontend, tier: 3,
    position: 2, grid_x: 12, grid_y: 3,
    summary: "Reflow, repaint, and the cost of touching the DOM in a loop.",
    prerequisites: %w[js-semantics] }
]

skills.each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

js_mod = curriculum_module!(
  world_slug: "frontend-universe", slug: "js-semantics-module", position: 1,
  name: "JavaScript Semantics", summary: "The rules that bite everyone once."
)
loop_mod = curriculum_module!(
  world_slug: "frontend-universe", slug: "event-loop-module", position: 2,
  name: "The Event Loop", summary: "One thread, a queue, and an order you must learn."
)
dom_mod = curriculum_module!(
  world_slug: "frontend-universe", slug: "dom-module", position: 3,
  name: "DOM & Rendering", summary: "Why the page janks."
)

# ============================================================== JS semantics
js1 = mission!(
  curriculum_module: js_mod, slug: "closures-capture-variables", position: 1,
  name: "The loop that logs 3, three times", skill_slug: "js-semantics",
  minutes: 7, xp: 15, difficulty: :easy,
  hook: "`for (var i = 0; i < 3; i++) setTimeout(() => console.log(i))` logs " \
        "3, 3, 3. Every beginner expects 0, 1, 2. The reason is the single " \
        "most-asked JavaScript interview question.",
  summary: "Closures capture variables, not values — and var is function-scoped.",
  blocks: [
    [ :prose, "Capture the variable, not the value",
      { "body" => "A closure keeps a reference to the **variable**, not a copy " \
                  "of what it held when the closure was created. With `var` " \
                  "there is one `i` for the whole function, so all three " \
                  "callbacks see the same one — and by the time they run, the " \
                  "loop has finished and it holds 3." } ],
    [ :visual, "var versus let",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "var i", "points_to" => "one binding" },
                     { "label" => "let i", "points_to" => "one binding per iteration" } ],
        "objects" => [ { "id" => "one binding", "value" => "all 3 closures share it → 3, 3, 3" },
                       { "id" => "one binding per iteration", "value" => "each closure has its own → 0, 1, 2" } ],
        "caption" => "`let` is block-scoped, and a `for` loop creates a fresh " \
                     "binding each iteration. That single difference fixes it." } ],
    [ :prediction, "What is logged?",
      { "question" => "for (let i = 0; i < 3; i++) setTimeout(() => console.log(i))",
        "options" => [ "3, 3, 3", "0, 1, 2", "undefined three times", "Nothing" ],
        "answer" => 1,
        "explanation" => "0, 1, 2. `let` gives each iteration its own binding, " \
                         "so each callback closes over a different `i`. Swap in " \
                         "`var` and you get 3, 3, 3 — one shared binding, read " \
                         "after the loop ended." } ],
    [ :code_demo, "Three ways to fix it",
      { "code" => "// Broken: one shared binding\nfor (var i = 0; i < 3; i++) setTimeout(() => console.log(i));  // 3 3 3\n\n// 1. Block scope — the modern answer\nfor (let i = 0; i < 3; i++) setTimeout(() => console.log(i));  // 0 1 2\n\n// 2. Capture by argument\nfor (var i = 0; i < 3; i++) setTimeout((n) => console.log(n), 0, i);\n\n// 3. An IIFE — how this was done before let existed\nfor (var i = 0; i < 3; i++) (function (n) {\n  setTimeout(() => console.log(n));\n})(i);",
        "language" => "javascript",
        "annotations" => [
          "All three work by giving each callback its own binding.",
          "The IIFE version is worth recognising in older code, not writing.",
          "The same rule explains stale values in React effects: the closure " \
          "captured the variable from that render."
        ] } ],
    [ :interactive, "Which capture is shared?",
      { "kind" => "risk_spotter",
        "prompt" => "Which of these closures share state?",
        "cases" => [
          { "sql" => "Two closures over the same `let` in one scope", "risk" => true,
            "why" => "Shared — same binding, so a write by one is seen by the other." },
          { "sql" => "Closures created in separate calls to a factory function",
            "risk" => false, "why" => "Independent — each call makes a new binding." },
          { "sql" => "Callbacks created in a `var` loop", "risk" => true,
            "why" => "Shared — one function-scoped binding for all of them." },
          { "sql" => "Callbacks created in a `let` loop", "risk" => false,
            "why" => "Independent — a fresh binding per iteration." }
        ] } ],
    [ :pitfall, "A counter that is accidentally shared",
      { "body" => "Closures sharing a binding is usually what you want — it is " \
                  "how a counter or a private variable works. It becomes a bug " \
                  "when you *expected* copies. The question to ask is always: " \
                  "how many bindings exist, and who can see each one?" } ],
    [ :scenario, "In production",
      { "situation" => "A dashboard builds one click handler per row in a loop. " \
                       "Every handler opens the detail view for the *last* row.",
        "question" => "What is the bug and what is the fix?",
        "answer" => "The handlers all closed over one shared loop variable, so " \
                    "they read its final value when clicked. Give each iteration " \
                    "its own binding with `let`, or attach the row id to the " \
                    "element as a data attribute and read it from the event " \
                    "target — which also means one delegated listener instead of " \
                    "hundreds." } ],
    [ :interview, "How this is asked",
      { "question" => "Why does a `var` loop with setTimeout log the final value?",
        "good_answer" => "Because the closures capture the variable, not its " \
                         "value, and `var` is function-scoped so there is only " \
                         "one of it. The callbacks run after the loop completes, " \
                         "so they all read the same finished value. `let` is " \
                         "block-scoped with a per-iteration binding, which is " \
                         "why it behaves as expected." } ],
    [ :revision, "Recall",
      { "prompt" => "Does a closure capture the value or the variable?",
        "answer" => "The variable — so later writes are visible to it." } ]
  ]
)

challenge!(
  slug: "closure-counter", title: "A counter that keeps its own state",
  topic: js1, skill_slug: "js-semantics", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Closures are how private state works. Model it.\n\n" \
          "Write `make_counter(start)` returning a lambda that increments by 1 " \
          "and returns the new value each time it is called.\n\n" \
          "Two counters must be completely independent — this is the " \
          "per-iteration binding from the mission, made explicit.",
  starter: "def make_counter(start)\n  # Your code here\nend\n",
  solution: "def make_counter(start)\n" \
            "  count = start\n" \
            "  -> { count += 1 }\n" \
            "end\n",
  explanation: "The lambda closes over `count`, which lives on after " \
               "`make_counter` returns — that is a closure. Each call to " \
               "`make_counter` creates a *new* `count`, which is why the two " \
               "counters do not interfere. In JavaScript this is exactly what " \
               "`let` in a loop gives you, and what `var` does not.",
  tests: [
    [ "increments from the start", "c = make_counter(0); [c.call, c.call, c.call]", "[1, 2, 3]" ],
    [ "respects a non-zero start", "c = make_counter(10); c.call", "11" ],
    [ "keeps two counters independent",
      "a = make_counter(0); b = make_counter(0); a.call; a.call; [a.call, b.call]", "[3, 1]" ],
    [ "handles a negative start", "c = make_counter(-2); [c.call, c.call]", "[-1, 0]" ],
    [ "returns a callable", "make_counter(0).respond_to?(:call)", "true", true ]
  ],
  hints: [
    [ :nudge, "The variable has to live outside the lambda but inside the method.", 2 ],
    [ :concept, "A lambda defined in a method can read and write that method's " \
                "local variables, and they survive the method returning.", 4 ],
    [ :solution, "Assign `count = start`, then return `-> { count += 1 }`.", 8 ]
  ]
)

challenge!(
  slug: "debug-shared-closure-binding", title: "Every handler opens the last row",
  topic: js1, skill_slug: "js-semantics", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`build_handlers(ids)` should return one lambda per id, each " \
          "returning **its own** id — the Ruby equivalent of per-row click " \
          "handlers.\n\n" \
          "Every lambda returns the last id instead, because they all close " \
          "over one shared variable. Fix it.",
  starter: "def build_handlers(ids)\n" \
           "  handlers = []\n" \
           "  current = nil\n" \
           "  ids.each do |id|\n" \
           "    current = id\n" \
           "    handlers << -> { current }\n" \
           "  end\n" \
           "  handlers\n" \
           "end\n",
  solution: "def build_handlers(ids)\n" \
            "  ids.map { |id| -> { id } }\n" \
            "end\n",
  explanation: "`current` is one variable in the method's scope, so all the " \
               "lambdas see the same binding and read whatever it holds when " \
               "called — the last id. A block parameter is a fresh binding per " \
               "iteration, so closing over `id` gives each lambda its own. " \
               "This is precisely the `var` versus `let` distinction.",
  tests: [
    [ "each handler returns its own id",
      "build_handlers([1, 2, 3]).map(&:call)", "[1, 2, 3]" ],
    [ "works with strings", "build_handlers(%w[a b]).map(&:call)", '["a", "b"]' ],
    [ "returns one handler per id", "build_handlers([1, 2, 3]).length", "3" ],
    [ "handles a single id", "build_handlers([7]).map(&:call)", "[7]" ],
    [ "returns empty for no ids", "build_handlers([]).map(&:call)", "[]" ],
    [ "handlers stay correct when called out of order",
      "h = build_handlers([1, 2, 3]); [h[2].call, h[0].call]", "[3, 1]", true ]
  ],
  hints: [
    [ :nudge, "How many variables named `current` exist? How many lambdas read it?", 3 ],
    [ :concept, "A block parameter creates a new binding each iteration; a " \
                "method-scoped local does not.", 5 ],
    [ :solution, "Close over the block parameter directly: " \
                 "`ids.map { |id| -> { id } }`.", 9 ]
  ]
)

question!(
  body: "Why does a `var` loop with setTimeout log the final value, and how do " \
        "you fix it?",
  skill_slug: "js-semantics", type: "output_prediction", band: :junior, difficulty: :easy,
  topic: js1,
  model: "Closures capture the variable rather than its value, and `var` is " \
         "function-scoped so there is a single binding shared by every callback. " \
         "The callbacks run after the loop finishes, so they all read the final " \
         "value. `let` is block-scoped with a fresh binding per iteration, which " \
         "gives each callback its own.",
  mistakes: "Saying setTimeout is 'too slow' or that the loop runs after the " \
            "timeouts, rather than identifying the shared binding.",
  answer_key: { "keywords" => [ "closure", "variable", "binding", "let", "var",
                                "scope" ],
                "required" => [ "binding" ] },
  follow_ups: [
    { body: "Does the closure capture the value or the variable?",
      trigger: "always",
      expects: [ "variable", "reference", "not a copy" ],
      model: "The variable. That is why a later write is visible inside the " \
             "closure, and why sharing a binding is sometimes exactly what you " \
             "want — a private counter, for example." },
    { body: "Where does this same rule bite in React?",
      trigger: "keyword", keywords: [ "react", "hook", "effect", "state" ],
      expects: [ "stale", "render", "dependency", "effect" ],
      model: "Stale closures in effects and callbacks: the function captured the " \
             "variables from the render it was created in, so without the right " \
             "dependencies it keeps reading old state." }
  ]
)

# ================================================================ event loop
el1 = mission!(
  curriculum_module: loop_mod, slug: "microtasks-first", position: 1,
  name: "Why your promise runs before your timeout", skill_slug: "event-loop",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "`setTimeout(f, 0)` and `Promise.resolve().then(g)` are both \"as soon " \
        "as possible\". `g` always runs first. There are two queues, not one.",
  summary: "Call stack, microtasks, macrotasks — and the order they drain in.",
  blocks: [
    [ :prose, "One thread, two queues",
      { "body" => "JavaScript runs on a single thread. Synchronous code runs to " \
                  "completion on the call stack. Then the **microtask** queue " \
                  "drains *entirely* — promise callbacks live here. Only then " \
                  "does one **macrotask** run: a timer, an I/O callback, an " \
                  "event handler. Then microtasks drain again, and so on." } ],
    [ :visual, "The order, for one tick",
      { "kind" => "growth_table",
        "sizes" => [ "when", "what runs" ],
        "rows" => [
          { "label" => "1", "values" => [ "now", "all synchronous code" ] },
          { "label" => "2", "values" => [ "before any timer", "every microtask, including ones queued by microtasks" ] },
          { "label" => "3", "values" => [ "next tick", "exactly one macrotask (e.g. a setTimeout)" ] },
          { "label" => "4", "values" => [ "immediately after", "microtasks again" ] }
        ],
        "caption" => "Step 2 is why a promise beats a zero-delay timer, and why " \
                     "an endless chain of microtasks can starve timers entirely." } ],
    [ :prediction, "Put them in order",
      { "question" => "console.log('A'); setTimeout(() => console.log('B'), 0); " \
                      "Promise.resolve().then(() => console.log('C')); " \
                      "console.log('D');",
        "options" => [ "A B C D", "A D C B", "A D B C", "A C D B" ],
        "answer" => 1,
        "explanation" => "A D C B. 'A' and 'D' are synchronous. Then the " \
                         "microtask queue drains, giving 'C'. Only then does the " \
                         "timer macrotask run, giving 'B' — even with a 0ms delay." } ],
    [ :code_demo, "Starving the event loop",
      { "code" => "// A microtask that queues another microtask never yields.\nfunction spin() { Promise.resolve().then(spin); }\nspin();\nsetTimeout(() => console.log(\"never runs\"), 0);\n\n// Blocking the thread is just as fatal — no queue gets a turn.\nconst end = Date.now() + 5000;\nwhile (Date.now() < end) {}   // the page is frozen for 5s\n\n// Yield between chunks so rendering and input can happen.\nasync function processInChunks(items) {\n  for (let i = 0; i < items.length; i += 500) {\n    handle(items.slice(i, i + 500));\n    await new Promise((r) => setTimeout(r, 0));   // yields a macrotask turn\n  }\n}",
        "language" => "javascript",
        "annotations" => [
          "`await` on a promise yields to microtasks; awaiting a timer yields a " \
          "full macrotask turn, which lets the browser render.",
          "A synchronous loop blocks everything — no clicks, no paint.",
          "This is why heavy work belongs in a Web Worker."
        ] } ],
    [ :pitfall, "async does not mean parallel",
      { "body" => "`async`/`await` is scheduling, not threading. An `await` " \
                  "yields the thread so other work can run, but your CPU-bound " \
                  "loop still occupies the one thread while it executes. " \
                  "Making a function `async` does not make it concurrent." } ],
    [ :interactive, "Which queue?",
      { "kind" => "risk_spotter",
        "prompt" => "Microtask or macrotask?",
        "cases" => [
          { "sql" => "Promise.then callback", "risk" => false, "why" => "Microtask — drains before any timer." },
          { "sql" => "setTimeout(fn, 0)", "risk" => true, "why" => "Macrotask — one per tick." },
          { "sql" => "queueMicrotask(fn)", "risk" => false, "why" => "Microtask, explicitly." },
          { "sql" => "A click event handler", "risk" => true, "why" => "Macrotask." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A page freezes for three seconds when a user uploads a " \
                       "CSV. The parsing function is `async` and every call is " \
                       "awaited, so the developer assumed it could not block.",
        "question" => "Why does it still freeze?",
        "answer" => "Because `async` only changes when the function returns, not " \
                    "which thread it runs on. The parsing loop is CPU-bound and " \
                    "holds the single thread from start to finish; `await` only " \
                    "yields at an actual suspension point. The fix is to process " \
                    "in chunks and yield a macrotask turn between them so the " \
                    "browser can paint and respond, or to move the work into a " \
                    "Web Worker where it genuinely runs off the main thread." } ],
    [ :interview, "How this is asked",
      { "question" => "What logs first: a resolved promise's then, or " \
                      "setTimeout with 0?",
        "good_answer" => "The promise. Microtasks drain completely after the " \
                         "current synchronous execution and before the next " \
                         "macrotask, and a timer is a macrotask. A consequence " \
                         "worth mentioning is that a microtask which keeps " \
                         "queueing microtasks can starve timers indefinitely." } ],
    [ :revision, "Recall",
      { "prompt" => "In one tick, what drains fully before a single timer runs?",
        "answer" => "The entire microtask queue." } ]
  ]
)

challenge!(
  slug: "event-loop-order", title: "Drain the queues in order",
  topic: el1, skill_slug: "event-loop", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Model the event loop.\n\n" \
          "Write `drain(tasks)` where each task is `[:sync, label]`, " \
          "`[:micro, label]` or `[:macro, label]`. Return the labels in the " \
          "order they would run:\n\n" \
          "1. all sync, in order\n" \
          "2. all microtasks, in order\n" \
          "3. all macrotasks, in order\n\n" \
          "Relative order within each class must be preserved.",
  starter: "def drain(tasks)\n  # Your code here\nend\n",
  solution: "def drain(tasks)\n" \
            "  order = { sync: 0, micro: 1, macro: 2 }\n" \
            "  tasks.each_with_index\n" \
            "       .sort_by { |(kind, _label), index| [order.fetch(kind), index] }\n" \
            "       .map { |(_kind, label), _index| label }\n" \
            "end\n",
  explanation: "Sorting by `[class, original index]` is a stable sort by " \
               "priority: the index tie-break preserves the order tasks were " \
               "queued in, which is exactly how each real queue behaves (FIFO " \
               "within a class, strict priority between classes).",
  tests: [
    [ "microtasks beat macrotasks",
      "drain([[:macro, 'B'], [:micro, 'C']])", '["C", "B"]' ],
    [ "sync runs first",
      "drain([[:micro, 'C'], [:sync, 'A']])", '["A", "C"]' ],
    [ "the classic ordering",
      "drain([[:sync, 'A'], [:macro, 'B'], [:micro, 'C'], [:sync, 'D']])",
      '["A", "D", "C", "B"]' ],
    [ "preserves order within a class",
      "drain([[:micro, 'C1'], [:micro, 'C2']])", '["C1", "C2"]' ],
    [ "handles no tasks", "drain([])", "[]" ],
    [ "handles only macrotasks",
      "drain([[:macro, 'B1'], [:macro, 'B2']])", '["B1", "B2"]', true ]
  ],
  hints: [
    [ :nudge, "Three priority classes, and order preserved inside each. What " \
              "kind of sort is that?", 3 ],
    [ :concept, "Sort by a tuple of [priority, original position] so the sort is " \
                "stable within a class.", 5 ],
    [ :solution, "`each_with_index.sort_by { |(kind, _), i| [order[kind], i] }`", 9 ]
  ]
)

challenge!(
  slug: "debug-await-in-loop", title: "The requests that run one at a time",
  topic: el1, skill_slug: "event-loop", type: :optimize, difficulty: :medium, xp: 50,
  prompt: "`fetch_all(ids)` should issue all requests concurrently and return " \
          "the results in id order — the Ruby model of " \
          "`await Promise.all(...)` rather than awaiting inside a loop.\n\n" \
          "The given version calls `request(id)` sequentially. Rewrite it to " \
          "start every request before waiting on any, using the provided " \
          "`start_request(id)` (returns a handle) and `await_handle(h)`.",
  starter: "def fetch_all(ids)\n" \
           "  ids.map { |id| await_handle(start_request(id)) }\n" \
           "end\n",
  solution: "def fetch_all(ids)\n" \
            "  handles = ids.map { |id| start_request(id) }\n" \
            "  handles.map { |h| await_handle(h) }\n" \
            "end\n",
  explanation: "Awaiting inside the loop serialises the work: each request does " \
               "not begin until the previous one finished. Starting them all " \
               "first and then collecting is `Promise.all` — total time becomes " \
               "the slowest request rather than the sum of all of them.",
  metadata: { "target_complexity" => "concurrent: one round of waiting" },
  tests: [
    [ "returns results in order",
      "$started = []; def start_request(id); $started << id; {id: id}; end; " \
      "def await_handle(h); h[:id] * 10; end; fetch_all([1, 2, 3])", "[10, 20, 30]" ],
    [ "starts every request before awaiting any",
      "$log = []; def start_request(id); $log << [:start, id]; {id: id}; end; " \
      "def await_handle(h); $log << [:await, h[:id]]; h[:id]; end; " \
      "fetch_all([1, 2]); $log",
      "[[:start, 1], [:start, 2], [:await, 1], [:await, 2]]" ],
    [ "handles a single id",
      "def start_request(id); {id: id}; end; def await_handle(h); h[:id]; end; " \
      "fetch_all([5])", "[5]" ],
    [ "handles no ids",
      "def start_request(id); {id: id}; end; def await_handle(h); h[:id]; end; " \
      "fetch_all([])", "[]", true ]
  ],
  hints: [
    [ :nudge, "In the current version, when does the second request begin?", 3 ],
    [ :concept, "Start everything first, then wait. Two passes, not one " \
                "interleaved pass.", 4 ],
    [ :solution, "`handles = ids.map { start_request }` then " \
                 "`handles.map { await_handle }`.", 9 ]
  ]
)

challenge!(
  slug: "debug-microtask-starvation", title: "The timer that never runs",
  topic: el1, skill_slug: "event-loop", type: :debug, difficulty: :hard, xp: 55,
  prompt: "`run_loop(microtasks, macrotasks, budget)` models one event-loop " \
          "tick. It should drain the microtask queue, then run **one** " \
          "macrotask, and return the labels it executed.\n\n" \
          "A microtask may queue another microtask — the array is consumed as " \
          "it grows — so the drain must honour that. But the current version " \
          "never stops: a self-queueing microtask starves the macrotask " \
          "forever.\n\n" \
          "Cap the drain at `budget` microtasks, then run one macrotask.",
  starter: "def run_loop(microtasks, macrotasks, budget)\n" \
           "  executed = []\n" \
           "  until microtasks.empty?\n" \
           "    executed << microtasks.shift\n" \
           "  end\n" \
           "  executed << macrotasks.shift unless macrotasks.empty?\n" \
           "  executed\n" \
           "end\n",
  solution: "def run_loop(microtasks, macrotasks, budget)\n" \
            "  executed = []\n" \
            "  drained = 0\n" \
            "  while !microtasks.empty? && drained < budget\n" \
            "    executed << microtasks.shift\n" \
            "    drained += 1\n" \
            "  end\n" \
            "  executed << macrotasks.shift unless macrotasks.empty?\n" \
            "  executed\n" \
            "end\n",
  explanation: "The real event loop has no budget, which is exactly why " \
               "microtask starvation is possible: a promise callback that " \
               "queues another promise callback can prevent any timer from ever " \
               "running. Modelling it with a budget makes the failure mode " \
               "visible and testable — and in real code the fix is not a budget " \
               "but not writing a self-queueing microtask chain.",
  time_limit_ms: 2000,
  tests: [
    [ "drains microtasks then runs one macrotask",
      "run_loop(['C1', 'C2'], ['B1', 'B2'], 10)", '["C1", "C2", "B1"]' ],
    [ "runs the macrotask when there are no microtasks",
      "run_loop([], ['B1'], 10)", '["B1"]' ],
    [ "stops at the budget so the macrotask still runs",
      "micro = Array.new(50) { |i| \"C\#{i}\" }; run_loop(micro, ['B1'], 3)",
      '["C0", "C1", "C2", "B1"]' ],
    [ "does not hang on a self-queueing microtask",
      "q = ['C']; def q.shift; push('C'); super; end; run_loop(q, ['B1'], 5).last",
      '"B1"' ],
    [ "returns empty when both queues are empty",
      "run_loop([], [], 10)", "[]" ],
    [ "runs only one macrotask per tick",
      "run_loop([], ['B1', 'B2', 'B3'], 10).length", "1", true ]
  ],
  hints: [
    [ :nudge, "What happens if the microtask queue refills faster than it " \
              "drains?", 3 ],
    [ :concept, "The `until empty?` loop has no exit when the queue grows. " \
                "Count how many you have drained.", 5 ],
    [ :solution, "`while !microtasks.empty? && drained < budget`, incrementing " \
                 "`drained` each iteration.", 11 ]
  ]
)

question!(
  body: "A page freezes for three seconds during an upload. The parsing " \
        "function is async and awaited. Why does it still block?",
  skill_slug: "event-loop", type: "debugging", band: :mid, difficulty: :hard,
  topic: el1, company_type: "product",
  model: "`async` changes when a function returns, not which thread it runs on. " \
         "JavaScript has one main thread, and a CPU-bound parsing loop holds it " \
         "from start to finish — `await` only yields at a real suspension point. " \
         "The fixes are to process in chunks and yield a macrotask turn between " \
         "them so the browser can paint, or to move the work to a Web Worker " \
         "where it genuinely runs off the main thread.",
  mistakes: "Believing `async` implies parallelism, or adding more `await`s in " \
            "the hope of yielding.",
  answer_key: { "keywords" => [ "single thread", "cpu", "block", "worker",
                                "chunk", "yield", "paint" ],
                "required" => [ "thread" ] },
  related: [ "Web Workers", "microtasks", "rendering" ],
  follow_ups: [
    { body: "How exactly would you yield between chunks?",
      trigger: "always",
      expects: [ "settimeout", "macrotask", "await", "requestidlecallback", "0" ],
      model: "`await new Promise(r => setTimeout(r, 0))` gives up a full macrotask " \
             "turn, which lets the browser render and handle input. Awaiting an " \
             "already-resolved promise only yields to microtasks, which does not " \
             "allow a paint." },
    { body: "When is a Web Worker the better answer?",
      trigger: "always",
      expects: [ "cpu", "long", "off main thread", "transfer" ],
      model: "When the work is genuinely CPU-bound and long enough that chunking " \
             "still degrades interaction. The cost is that communication is by " \
             "message passing, so the data has to be serialisable or transferable." }
  ]
)

# ============================================================== DOM rendering
d1 = mission!(
  curriculum_module: dom_mod, slug: "reflow-in-a-loop", position: 1,
  name: "The loop that lays out the page 1,000 times", skill_slug: "dom-rendering",
  minutes: 7, xp: 20, difficulty: :medium,
  hook: "Appending 1,000 rows one at a time takes 900ms. Appending them in one " \
        "go takes 9ms. The DOM calls are identical; the layout work is not.",
  summary: "Reflow, repaint, layout thrashing and batching.",
  blocks: [
    [ :prose, "Read, write, and the flush in between",
      { "body" => "Writes to the DOM are batched by the browser. But *reading* " \
                  "a layout property — `offsetHeight`, `getBoundingClientRect` " \
                  "— forces it to flush those pending writes and recompute " \
                  "layout immediately, so it can give you an accurate answer. " \
                  "Alternating writes and reads in a loop forces one full " \
                  "layout per iteration. That is **layout thrashing**." } ],
    [ :visual, "Cost of the same work, three ways",
      { "kind" => "growth_table",
        "sizes" => [ "layout passes", "rough cost" ],
        "rows" => [
          { "label" => "append in a loop, read height each time",
            "values" => [ "1,000", "~900ms" ] },
          { "label" => "append in a loop, no reads", "values" => [ "1", "~40ms" ] },
          { "label" => "build a fragment, append once", "values" => [ "1", "~9ms" ] }
        ],
        "caption" => "The middle row is the browser batching for you. The last " \
                     "row is you batching as well — one insertion into the live " \
                     "document instead of a thousand." } ],
    [ :prediction, "What forces the reflow?",
      { "question" => "Which line in this loop forces a layout recalculation " \
                      "every iteration?\n\nel.style.width = w + 'px';\nconst h = el.offsetHeight;",
        "options" => [ "The style assignment",
                       "Reading offsetHeight",
                       "Both equally",
                       "Neither — writes are batched" ],
        "answer" => 1,
        "explanation" => "The read. Writes are queued, but `offsetHeight` needs " \
                         "an accurate number, so the browser must apply every " \
                         "pending write and recompute layout before answering. " \
                         "Move all reads before all writes and you get one " \
                         "layout instead of n." } ],
    [ :code_demo, "Batch the writes, hoist the reads",
      { "code" => "// Layout thrashing: write, read, write, read...\nrows.forEach((row) => {\n  row.style.width = container.offsetWidth + \"px\";   // read forces a flush\n});\n\n// One read, then all writes\nconst width = container.offsetWidth;                 // read once\nrows.forEach((row) => { row.style.width = width + \"px\"; });\n\n// One insertion into the live document\nconst fragment = document.createDocumentFragment();\nitems.forEach((item) => fragment.append(buildRow(item)));\ntable.append(fragment);                              // a single reflow",
        "language" => "javascript",
        "annotations" => [
          "A DocumentFragment is not in the document, so building it costs no layout.",
          "`classList.toggle` is cheaper than setting individual style properties.",
          "`transform` and `opacity` can be composited without a reflow at all."
        ] } ],
    [ :pitfall, "Reflow versus repaint",
      { "body" => "Changing geometry — width, position, font size — forces a " \
                  "**reflow**: the browser recomputes where everything is. " \
                  "Changing only colour forces a **repaint**, which is cheaper. " \
                  "Animating `transform` or `opacity` can skip both and run on " \
                  "the compositor, which is why they are the properties to " \
                  "animate." } ],
    [ :interactive, "Reflow, repaint or neither?",
      { "kind" => "risk_spotter",
        "prompt" => "What does each change cost?",
        "cases" => [
          { "sql" => "element.style.width = '200px'", "risk" => true,
            "why" => "Reflow — geometry changed." },
          { "sql" => "element.style.color = 'red'", "risk" => false,
            "why" => "Repaint only." },
          { "sql" => "element.style.transform = 'translateX(10px)'", "risk" => false,
            "why" => "Often compositor-only — no reflow or repaint." },
          { "sql" => "reading element.getBoundingClientRect()", "risk" => true,
            "why" => "Forces a synchronous layout of pending writes." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A table of 2,000 rows takes 4 seconds to render and the " \
                       "tab is unresponsive throughout. Each row is created and " \
                       "appended individually, and a helper measures the " \
                       "container width per row to set a column size.",
        "question" => "Name the two separate problems.",
        "answer" => "First, layout thrashing: measuring the container inside the " \
                    "loop forces a synchronous layout per row, so 2,000 layouts. " \
                    "Hoist that read out of the loop. Second, 2,000 separate " \
                    "insertions into the live document — build a " \
                    "DocumentFragment and append once. Beyond that, 2,000 rows " \
                    "is usually more than a user can read, so virtualising the " \
                    "list removes the work rather than optimising it." } ],
    [ :interview, "How this is asked",
      { "question" => "What is layout thrashing and how do you avoid it?",
        "good_answer" => "Interleaving DOM writes with reads of layout " \
                         "properties, so each read forces the browser to flush " \
                         "pending writes and recompute layout. Avoid it by " \
                         "batching: do all reads first, then all writes, and " \
                         "insert built subtrees in one operation." } ],
    [ :revision, "Recall",
      { "prompt" => "Which costs more, changing width or changing colour, and why?",
        "answer" => "Width — it changes geometry and forces a reflow; colour only " \
                    "repaints." } ]
  ]
)

challenge!(
  slug: "batch-dom-writes", title: "One flush, not a thousand",
  topic: d1, skill_slug: "dom-rendering", type: :optimize, difficulty: :medium, xp: 50,
  prompt: "`apply_widths(elements, container)` sets every element's width to " \
          "the container's width.\n\n" \
          "The given version reads `container.measure` inside the loop, which " \
          "is the model of forcing a layout per iteration. Rewrite it so " \
          "`measure` is called **once**.\n\n" \
          "Return the list of widths applied.",
  starter: "def apply_widths(elements, container)\n" \
           "  elements.map do |el|\n" \
           "    width = container.measure\n" \
           "    el.width = width\n" \
           "    width\n" \
           "  end\n" \
           "end\n",
  solution: "def apply_widths(elements, container)\n" \
            "  width = container.measure\n" \
            "  elements.map do |el|\n" \
            "    el.width = width\n" \
            "    width\n" \
            "  end\n" \
            "end\n",
  explanation: "Hoisting the read out of the loop is the whole fix — one layout " \
               "instead of n. In the browser the read is `offsetWidth` and the " \
               "flush is invisible, which is why this bug survives code review: " \
               "nothing in the loop body looks expensive.",
  metadata: { "target_complexity" => "one read, n writes" },
  tests: [
    [ "applies the width to each element",
      "Box = Struct.new(:width); C = Struct.new(:calls) do; def measure; self.calls += 1; 100; end; end; " \
      "c = C.new(0); apply_widths([Box.new(0), Box.new(0)], c)", "[100, 100]" ],
    [ "measures only once",
      "Box2 = Struct.new(:width); C2 = Struct.new(:calls) do; def measure; self.calls += 1; 100; end; end; " \
      "c = C2.new(0); apply_widths([Box2.new(0), Box2.new(0), Box2.new(0)], c); c.calls", "1" ],
    [ "sets the width on the elements",
      "Box3 = Struct.new(:width); C3 = Struct.new(:calls) do; def measure; self.calls += 1; 42; end; end; " \
      "b = Box3.new(0); apply_widths([b], C3.new(0)); b.width", "42" ],
    [ "handles no elements",
      "C4 = Struct.new(:calls) do; def measure; self.calls += 1; 10; end; end; " \
      "apply_widths([], C4.new(0))", "[]", true ]
  ],
  hints: [
    [ :nudge, "Does the container's width change as you set element widths?", 2 ],
    [ :concept, "If the value cannot change during the loop, read it before the " \
                "loop starts.", 4 ],
    [ :solution, "Move `width = container.measure` above the `map`.", 8 ]
  ]
)

challenge!(
  slug: "classify-render-cost", title: "Reflow, repaint or neither",
  topic: d1, skill_slug: "dom-rendering", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Write `render_cost(property)` returning `:reflow`, `:repaint` or " \
          "`:composite` for a CSS property being changed.\n\n" \
          "Geometry properties (`width`, `height`, `top`, `left`, " \
          "`font-size`, `margin`, `padding`) force a reflow. Paint-only " \
          "properties (`color`, `background-color`, `box-shadow`, " \
          "`visibility`) repaint. `transform` and `opacity` can be handled by " \
          "the compositor.\n\n" \
          "Anything else: return `:reflow`, because assuming the expensive " \
          "case is the safe default.",
  starter: "def render_cost(property)\n  # Your code here\nend\n",
  solution: "def render_cost(property)\n" \
            "  composite = %w[transform opacity]\n" \
            "  repaint = %w[color background-color box-shadow visibility]\n" \
            "  return :composite if composite.include?(property)\n" \
            "  return :repaint if repaint.include?(property)\n" \
            "  :reflow\n" \
            "end\n",
  explanation: "Defaulting to `:reflow` for the unknown case is the point: when " \
               "you are not sure whether a property changes geometry, assume it " \
               "does and measure. Animating `transform` instead of `left` is the " \
               "single highest-value habit this classification buys you.",
  tests: [
    [ "width forces a reflow", "render_cost('width')", ":reflow" ],
    [ "color only repaints", "render_cost('color')", ":repaint" ],
    [ "transform can composite", "render_cost('transform')", ":composite" ],
    [ "opacity can composite", "render_cost('opacity')", ":composite" ],
    [ "font-size forces a reflow", "render_cost('font-size')", ":reflow" ],
    [ "box-shadow repaints", "render_cost('box-shadow')", ":repaint" ],
    [ "an unknown property defaults to reflow", "render_cost('zoom')", ":reflow", true ]
  ],
  hints: [
    [ :nudge, "Three categories. Which two are small, closed lists?", 2 ],
    [ :solution, "Check the composite list, then the repaint list, then default " \
                 "to :reflow.", 6 ]
  ]
)

challenge!(
  slug: "debug-fragment-append", title: "A thousand insertions",
  topic: d1, skill_slug: "dom-rendering", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`render_rows(table, items)` should build all the rows and attach " \
          "them to the live `table` in **one** operation — the " \
          "DocumentFragment pattern.\n\n" \
          "It appends to the table once per item instead, so the hidden test " \
          "asserting a single attach fails. Fix it using the provided " \
          "`fragment` object, which has `append` and is not in the document.",
  starter: "def render_rows(table, items, fragment)\n" \
           "  items.each { |item| table.append(\"row-\#{item}\") }\n" \
           "  table\n" \
           "end\n",
  solution: "def render_rows(table, items, fragment)\n" \
            "  items.each { |item| fragment.append(\"row-\#{item}\") }\n" \
            "  table.append_all(fragment.children)\n" \
            "  table\n" \
            "end\n",
  explanation: "Building into a detached fragment costs no layout at all, because " \
               "it is not part of the rendered document. Attaching it once means " \
               "the browser computes layout a single time rather than per row — " \
               "the same work, one flush.",
  tests: [
    [ "attaches the table only once",
      "T = Struct.new(:children, :appends) do; def append(c); self.appends += 1; children << c; end; " \
      "def append_all(cs); self.appends += 1; children.concat(cs); end; end; " \
      "F = Struct.new(:children) do; def append(c); children << c; end; end; " \
      "t = T.new([], 0); render_rows(t, [1, 2, 3], F.new([])); t.appends", "1" ],
    [ "ends up with every row",
      "T2 = Struct.new(:children, :appends) do; def append(c); self.appends += 1; children << c; end; " \
      "def append_all(cs); self.appends += 1; children.concat(cs); end; end; " \
      "F2 = Struct.new(:children) do; def append(c); children << c; end; end; " \
      "t = T2.new([], 0); render_rows(t, [1, 2], F2.new([])); t.children",
      '["row-1", "row-2"]' ],
    [ "handles no items",
      "T3 = Struct.new(:children, :appends) do; def append(c); self.appends += 1; children << c; end; " \
      "def append_all(cs); self.appends += 1; children.concat(cs); end; end; " \
      "F3 = Struct.new(:children) do; def append(c); children << c; end; end; " \
      "t = T3.new([], 0); render_rows(t, [], F3.new([])); t.children", "[]" ],
    [ "returns the table",
      "T4 = Struct.new(:children, :appends) do; def append(c); self.appends += 1; children << c; end; " \
      "def append_all(cs); self.appends += 1; children.concat(cs); end; end; " \
      "F4 = Struct.new(:children) do; def append(c); children << c; end; end; " \
      "t = T4.new([], 0); render_rows(t, [1], F4.new([])).equal?(t)", "true", true ]
  ],
  hints: [
    [ :nudge, "What is the fragment for, if the rows go straight to the table?", 3 ],
    [ :concept, "Build into the detached fragment, then attach its children to " \
                "the live node once.", 5 ],
    [ :solution, "Append each row to `fragment`, then " \
                 "`table.append_all(fragment.children)`.", 9 ]
  ]
)

question!(
  body: "A table of 2,000 rows takes four seconds to render and the tab is " \
        "unresponsive. What are the problems?",
  skill_slug: "dom-rendering", type: "optimization", band: :mid, difficulty: :hard,
  topic: d1,
  model: "Likely two separate issues. Layout thrashing: if a layout property is " \
         "read inside the loop, every iteration forces a synchronous " \
         "recalculation — hoist the read out. And 2,000 individual insertions " \
         "into the live document, each potentially triggering layout — build a " \
         "DocumentFragment and attach once. Beyond both, 2,000 rows is more than " \
         "anyone reads, so virtualising the list removes the work instead of " \
         "optimising it.",
  answer_key: { "keywords" => [ "reflow", "thrash", "fragment", "batch",
                                "virtual", "layout", "read" ],
                "required" => [ "batch" ] },
  follow_ups: [
    { body: "Which CSS properties can you animate without a reflow?",
      trigger: "always",
      expects: [ "transform", "opacity", "composit" ],
      model: "`transform` and `opacity` — they can be handled by the compositor " \
             "without recomputing layout or repainting, which is why they are " \
             "the properties to animate." },
    { body: "The page is still janky after batching. What next?",
      trigger: "always",
      expects: [ "profile", "devtools", "virtual", "worker", "measure" ],
      model: "Profile it rather than guess: the performance panel shows whether " \
             "the time is in layout, paint, scripting or style recalculation. " \
             "That decides between virtualising, moving work to a worker, or " \
             "simplifying selectors." }
  ]
)
