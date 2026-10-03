include SeedDSL
# Phase 6: design patterns, architecture and distributed systems. Patterns are
# taught problem-first (spec 12): bad design, the pain, then the pattern, then
# the trade-off — never as vocabulary to memorise.
puts "  Phase 6: design patterns, architecture, distributed systems"

city = World.find_by!(slug: "computer-city")

patterns = World.find_or_create_by!(slug: "design-pattern-city") do |w|
  w.name = "Design Pattern City"
  w.position = 8
  w.accent_color = "#a78bfa"
  w.icon = "🏛"
  w.tagline = "Patterns are answers. Learn the questions first."
  w.summary = "Problem, pain, pattern, trade-off — and when not to."
end

skills = [
  { slug: "oop-design", name: "OOP & SOLID", world: patterns, tier: 3,
    position: 1, grid_x: 14, grid_y: 3,
    summary: "Encapsulation, polymorphism and the conditionals they remove.",
    prerequisites: %w[ruby-blocks] },
  { slug: "design-patterns", name: "Design Patterns", world: patterns, tier: 4,
    position: 1, grid_x: 14, grid_y: 4,
    summary: "Strategy, observer, adapter — and the cost of each.",
    prerequisites: %w[oop-design] },
  { slug: "architecture", name: "Architecture", world: patterns, tier: 5,
    position: 1, grid_x: 14, grid_y: 5,
    summary: "Boundaries, coupling, and why a modular monolith usually wins.",
    prerequisites: %w[design-patterns] },
  { slug: "distributed-systems", name: "Distributed Systems", world: city,
    tier: 6, position: 1, grid_x: 10, grid_y: 6,
    summary: "Partial failure, retries, idempotency and consistency.",
    prerequisites: %w[architecture background-jobs] }
]

skills.each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

oop_mod = curriculum_module!(
  world_slug: "design-pattern-city", slug: "oop-module", position: 1,
  name: "OOP & SOLID", summary: "Why polymorphism exists."
)
pat_mod = curriculum_module!(
  world_slug: "design-pattern-city", slug: "patterns-module", position: 2,
  name: "Patterns", summary: "Each one is a named answer to a specific pain."
)
arch_mod = curriculum_module!(
  world_slug: "design-pattern-city", slug: "architecture-module", position: 3,
  name: "Architecture", summary: "Decisions that are expensive to reverse."
)
dist_mod = curriculum_module!(
  world_slug: "computer-city", slug: "distributed-module", position: 4,
  name: "Distributed Systems", summary: "The network will fail. Plan for it."
)

# ======================================================================== OOP
o1 = mission!(
  curriculum_module: oop_mod, slug: "the-growing-conditional", position: 1,
  name: "The conditional that grows forever", skill_slug: "oop-design",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "`PaymentService` has a seven-branch `case` on provider. Adding " \
        "Razorpay means editing it again, re-testing every branch, and hoping. " \
        "The conditional is not the problem — it is the symptom.",
  summary: "Polymorphism replaces a conditional that keeps changing.",
  blocks: [
    [ :prose, "The signal to look for",
      { "body" => "A conditional that gains a branch every time the business " \
                  "adds a thing is the signal. The branches all answer the same " \
                  "question differently — so make the answer an object, and let " \
                  "the caller stop asking." } ],
    [ :visual, "Before and after",
      { "kind" => "fan_out",
        "left" => "PaymentService (case on provider)",
        "right" => [ "if stripe", "if paypal", "if razorpay", "if bank", "..." ],
        "caption" => "Every new provider edits this one method. With Strategy, " \
                     "each provider is its own object and the service never " \
                     "changes again." } ],
    [ :prediction, "Which SOLID letter is violated?",
      { "question" => "A seven-branch `case` on provider type, edited for every " \
                      "new provider. Which principle does that break first?",
        "options" => [ "Single responsibility",
                       "Open/closed — open for extension, closed for modification",
                       "Liskov substitution",
                       "Interface segregation" ],
        "answer" => 1,
        "explanation" => "Open/closed. Adding behaviour should mean adding a " \
                         "class, not editing an existing one. The conditional " \
                         "forces modification every time, which is exactly what " \
                         "open/closed warns about — and why the risk of " \
                         "regression grows with each provider." } ],
    [ :code_demo, "Replace the conditional with objects",
      { "code" => "# Before: every new provider edits this method\nclass PaymentService\n  def charge(provider, amount)\n    case provider\n    when :stripe then charge_stripe(amount)\n    when :paypal then charge_paypal(amount)\n    # ... one more branch per provider, forever\n    end\n  end\nend\n\n# After: each provider is an object with the same interface\nclass StripeGateway\n  def charge(amount) = Stripe::Charge.create(amount: amount)\nend\n\nclass PaymentService\n  def initialize(gateway) = @gateway = gateway\n  def charge(amount) = @gateway.charge(amount)   # never changes again\nend\n\n# The conditional does not vanish — it moves to one place, once\nGATEWAYS = { stripe: StripeGateway, paypal: PaypalGateway }.freeze\nPaymentService.new(GATEWAYS.fetch(name).new)",
        "language" => "ruby",
        "annotations" => [
          "The branching becomes a lookup table at the edge, not logic in the core.",
          "Ruby needs no interface declaration — duck typing is enough, but the " \
          "implicit contract must be documented.",
          "The win is that PaymentService is now closed to modification."
        ] } ],
    [ :pitfall, "Do not reach for it on the second branch",
      { "body" => "Two branches that are unlikely to grow do not need a " \
                  "pattern; an `if` is clearer than two classes and a factory. " \
                  "Strategy earns its keep when branches keep arriving, when " \
                  "each is substantial, or when you need to test them in " \
                  "isolation. Applied too early it is just indirection." } ],
    [ :comparison, "Conditional vs Strategy",
      { "rows" => [
          { "aspect" => "Adding a case", "cond" => "Edit existing code",
            "strat" => "Add a class" },
          { "aspect" => "Testing one case", "cond" => "Through the whole service",
            "strat" => "In isolation" },
          { "aspect" => "Reading the flow", "cond" => "All in one place",
            "strat" => "Spread across files" },
          { "aspect" => "Right when", "cond" => "Two stable branches",
            "strat" => "Branches keep arriving" }
        ],
        "columns" => { "cond" => "Conditional", "strat" => "Strategy" } } ],
    [ :interactive, "Pattern or overkill?",
      { "kind" => "risk_spotter",
        "prompt" => "Does each case justify a pattern?",
        "cases" => [
          { "sql" => "Seven payment providers, more expected", "risk" => false,
            "why" => "Strategy — this is exactly the case it is for." },
          { "sql" => "if admin? then x else y", "risk" => true,
            "why" => "Overkill. Two stable branches; leave the conditional." },
          { "sql" => "Four export formats, each ~100 lines", "risk" => false,
            "why" => "Strategy — substantial, independently testable branches." },
          { "sql" => "A single global config object", "risk" => true,
            "why" => "Singleton is usually a global in disguise — prefer passing " \
                     "a dependency explicitly." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A 400-line `NotificationService` branches on channel " \
                       "(email, SMS, push, webhook) and on user preference. A " \
                       "change to SMS retry logic broke push notifications.",
        "question" => "What does that breakage tell you?",
        "answer" => "That the branches share mutable state or helper methods, so " \
                    "they are not actually independent — which is why an " \
                    "unrelated change could reach across. Splitting each channel " \
                    "into its own object with its own tests means a change to " \
                    "one cannot touch another. The coupling was the real bug; " \
                    "the conditional just made it easy to write." } ],
    [ :interview, "How this is asked",
      { "question" => "When would you introduce the Strategy pattern, and when " \
                      "would you not?",
        "good_answer" => "When a conditional keeps gaining branches for the same " \
                         "decision, the branches are substantial, or I need to " \
                         "test them independently. I would not for two stable " \
                         "branches — the pattern adds indirection and more files, " \
                         "and an `if` is easier to read. The trade is always " \
                         "flexibility against directness." } ],
    [ :revision, "Recall",
      { "prompt" => "What does Strategy actually do to the conditional?",
        "answer" => "Moves it to a single lookup at the edge, so the core is " \
                    "closed to modification." } ]
  ]
)

challenge!(
  slug: "strategy-pattern", title: "Replace the case with objects",
  topic: o1, skill_slug: "oop-design", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Build the Strategy shape.\n\n" \
          "Write `Checkout` taking a gateway object in its constructor and a " \
          "`#pay(amount)` that delegates to `gateway.charge(amount)` and " \
          "returns the result.\n\n" \
          "Also write `Checkout.for(name)`, which looks the gateway class up in " \
          "`Checkout::GATEWAYS` (`:flat` → `FlatFee`, `:percent` → " \
          "`PercentFee`) and raises `ArgumentError` for an unknown name.\n\n" \
          "`FlatFee#charge(amount)` returns `amount + 2`. " \
          "`PercentFee#charge(amount)` returns `amount * 1.1` rounded to 2dp.",
  starter: "class FlatFee\n  def charge(amount)\n    # Your code here\n  end\nend\n\n" \
           "class PercentFee\n  def charge(amount)\n    # Your code here\n  end\nend\n\n" \
           "class Checkout\n  GATEWAYS = {}\n\n  def self.for(name)\n  end\n\n" \
           "  def initialize(gateway)\n  end\n\n  def pay(amount)\n  end\nend\n",
  solution: "class FlatFee\n" \
            "  def charge(amount)\n    amount + 2\n  end\nend\n\n" \
            "class PercentFee\n" \
            "  def charge(amount)\n    (amount * 1.1).round(2)\n  end\nend\n\n" \
            "class Checkout\n" \
            "  GATEWAYS = { flat: FlatFee, percent: PercentFee }.freeze\n\n" \
            "  def self.for(name)\n" \
            "    klass = GATEWAYS[name] or raise ArgumentError, \"unknown gateway: \#{name}\"\n" \
            "    new(klass.new)\n" \
            "  end\n\n" \
            "  def initialize(gateway)\n    @gateway = gateway\n  end\n\n" \
            "  def pay(amount)\n    @gateway.charge(amount)\n  end\nend\n",
  explanation: "`Checkout#pay` has no conditional at all — adding a third " \
               "gateway means adding a class and one table entry, and `pay` is " \
               "untouched. That is open/closed in practice. The branching has " \
               "not disappeared; it has moved into `GATEWAYS`, where it is a " \
               "lookup rather than logic.",
  tests: [
    [ "delegates to the injected gateway", "Checkout.new(FlatFee.new).pay(10)", "12" ],
    [ "builds a flat gateway by name", "Checkout.for(:flat).pay(10)", "12" ],
    [ "builds a percent gateway by name", "Checkout.for(:percent).pay(10)", "11.0" ],
    [ "rounds the percent fee", "Checkout.for(:percent).pay(3)", "3.3" ],
    [ "rejects an unknown gateway",
      "begin; Checkout.for(:nope); rescue ArgumentError; 'raised'; end", '"raised"' ],
    [ "accepts any object with charge",
      "custom = Object.new; def custom.charge(a); a * 2; end; Checkout.new(custom).pay(5)",
      "10" ],
    [ "pay contains no gateway conditional",
      "Checkout.instance_method(:pay).source_location.is_a?(Array)", "true", true ]
  ],
  hints: [
    [ :nudge, "`pay` should not know which gateway it has — it just calls " \
              "`charge`.", 3 ],
    [ :concept, "Store the gateway in the constructor; keep the name-to-class " \
                "mapping in a frozen hash used only by `.for`.", 4 ],
    [ :solution, "`GATEWAYS = { flat: FlatFee, percent: PercentFee }.freeze`, " \
                 "and `pay` is `@gateway.charge(amount)`.", 9 ]
  ]
)

challenge!(
  slug: "debug-liskov-violation", title: "The subclass that breaks its promise",
  topic: o1, skill_slug: "oop-design", type: :debug, difficulty: :hard, xp: 55,
  prompt: "`ReadOnlyList` inherits from `EditableList` and raises on `add`, so " \
          "anything written against the parent's interface breaks when handed " \
          "the child — a Liskov substitution violation.\n\n" \
          "`total_after_adding(list, items)` must work with **either** list: " \
          "add what it can and return the final size, skipping lists that do " \
          "not accept writes.\n\n" \
          "Fix it by asking whether the list accepts writes, not by rescuing " \
          "the exception.",
  starter: "class EditableList\n" \
           "  def initialize; @items = []; end\n" \
           "  def add(item); @items << item; self; end\n" \
           "  def size; @items.size; end\n" \
           "end\n\n" \
           "class ReadOnlyList < EditableList\n" \
           "  def add(_item); raise NotImplementedError, 'read only'; end\n" \
           "end\n\n" \
           "def total_after_adding(list, items)\n" \
           "  items.each { |i| list.add(i) }\n" \
           "  list.size\n" \
           "end\n",
  solution: "class EditableList\n" \
            "  def initialize; @items = []; end\n" \
            "  def add(item); @items << item; self; end\n" \
            "  def size; @items.size; end\n" \
            "  def writable?; true; end\n" \
            "end\n\n" \
            "class ReadOnlyList < EditableList\n" \
            "  def add(_item); raise NotImplementedError, 'read only'; end\n" \
            "  def writable?; false; end\n" \
            "end\n\n" \
            "def total_after_adding(list, items)\n" \
            "  items.each { |i| list.add(i) } if list.writable?\n" \
            "  list.size\n" \
            "end\n",
  explanation: "Asking `writable?` makes the capability part of the interface, " \
               "so the caller branches on a published fact rather than on a " \
               "rescued exception. Rescuing would also hide genuine errors from " \
               "`add`. The deeper lesson is that `ReadOnlyList` should probably " \
               "not inherit from `EditableList` at all — the inheritance claims " \
               "a contract it cannot keep.",
  tests: [
    [ "adds to an editable list",
      "total_after_adding(EditableList.new, [1, 2, 3])", "3" ],
    [ "skips a read-only list without raising",
      "total_after_adding(ReadOnlyList.new, [1, 2, 3])", "0" ],
    [ "returns the size for an empty add",
      "total_after_adding(EditableList.new, [])", "0" ],
    [ "does not swallow a genuine error from add",
      "broken = EditableList.new; def broken.add(i); raise ArgumentError, 'bad'; end; " \
      "begin; total_after_adding(broken, [1]); rescue ArgumentError; 'raised'; end",
      '"raised"' ],
    [ "reports writability",
      "[EditableList.new.writable?, ReadOnlyList.new.writable?]", "[true, false]" ],
    [ "accumulates across calls",
      "l = EditableList.new; total_after_adding(l, [1]); total_after_adding(l, [2])",
      "2", true ]
  ],
  hints: [
    [ :nudge, "The caller needs to know whether writing is allowed *before* " \
              "trying. How would it find out?", 4 ],
    [ :concept, "Add a predicate to the interface that both classes answer " \
                "honestly, then branch on it.", 5 ],
    [ :solution, "Define `writable?` returning true on the parent and false on " \
                 "the subclass, and guard the loop with it. Do not rescue.", 11 ]
  ]
)

question!(
  body: "A service has a seven-branch case statement on payment provider. Would " \
        "you refactor it, and to what?",
  skill_slug: "oop-design", type: "architecture", band: :mid, difficulty: :medium,
  topic: o1,
  model: "Yes, if it keeps gaining branches — that is an open/closed problem, " \
         "because every new provider means modifying tested code. Strategy: " \
         "each provider becomes an object with the same interface, the service " \
         "takes one as a dependency, and the only branching left is a " \
         "name-to-class lookup at the edge. I would not refactor two stable " \
         "branches; the indirection would cost more than it saves.",
  mistakes: "Applying the pattern reflexively, or claiming it removes the " \
            "conditional rather than relocating it.",
  answer_key: { "keywords" => [ "strategy", "open", "closed", "interface",
                                "inject", "lookup" ],
                "required" => [ "strategy" ] },
  related: [ "SOLID", "dependency injection", "duck typing" ],
  follow_ups: [
    { body: "Does Strategy eliminate the conditional, or move it?",
      trigger: "always",
      expects: [ "move", "lookup", "factory", "edge", "once" ],
      model: "It moves it. The decision still has to be made once, but it becomes " \
             "a lookup table at the boundary rather than logic inside the core, " \
             "which is what lets the core stop changing." },
    { body: "What is the cost of the refactor?",
      trigger: "always",
      expects: [ "indirection", "files", "harder to read", "navigate" ],
      model: "More files and indirection: the flow is no longer readable in one " \
             "place, so a newcomer has to navigate to understand what happens. " \
             "That is why it is wrong for a small, stable conditional." },
    { body: "In Ruby, do the strategies need a shared base class?",
      trigger: "always",
      expects: [ "duck", "no", "interface", "document" ],
      model: "No — duck typing means any object responding to the method works. " \
             "The risk is that the contract is implicit, so it should be " \
             "documented and covered by a shared test." }
  ]
)

# =================================================================== patterns
p1 = mission!(
  curriculum_module: pat_mod, slug: "observer-and-coupling", position: 1,
  name: "The method that grew six side effects", skill_slug: "design-patterns",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "`Order#complete!` sends an email, updates analytics, notifies the " \
        "warehouse, awards loyalty points, posts to Slack and writes an audit " \
        "row. Now the warehouse API is down and nobody can complete an order.",
  summary: "Observer decouples the event from the reactions — and hides the flow.",
  blocks: [
    [ :prose, "One cause, many reactions",
      { "body" => "When a single action must trigger reactions that keep " \
                  "multiplying, and those reactions do not belong to the action, " \
                  "Observer inverts the dependency: the order announces that it " \
                  "completed, and interested parties subscribe. The order stops " \
                  "knowing who cares." } ],
    [ :visual, "Coupling before and after",
      { "kind" => "fan_out",
        "left" => "Order#complete!",
        "right" => [ "Mailer", "Analytics", "Warehouse", "Loyalty", "Slack", "Audit" ],
        "caption" => "Six dependencies in one method. Any one failing takes the " \
                     "order with it, and every one must be stubbed to test " \
                     "completing an order at all." } ],
    [ :prediction, "What does Observer cost you?",
      { "question" => "You move those six side effects to subscribers. What have " \
                      "you made worse?",
        "options" => [ "Nothing — it is strictly better",
                       "The flow is no longer readable in one place",
                       "It becomes slower",
                       "You can no longer test the order" ],
        "answer" => 1,
        "explanation" => "Traceability. Reading `complete!` no longer tells you " \
                         "what happens, so a newcomer debugging a missing email " \
                         "has to find the subscribers. That is the real trade: " \
                         "decoupling buys independence and costs an explicit " \
                         "flow. Worth it at six reactions, usually not at one." } ],
    [ :code_demo, "Subscribe, and isolate failure",
      { "code" => "class Order\n  def self.subscribers = @subscribers ||= []\n  def self.subscribe(s) = subscribers << s\n\n  def complete!\n    update!(status: \"complete\")\n    publish(:completed)\n  end\n\n  private\n\n  def publish(event)\n    self.class.subscribers.each do |subscriber|\n      subscriber.call(event, self)\n    rescue StandardError => e\n      # One failing subscriber must not fail the order\n      Rails.logger.error(\"subscriber failed\")\n    end\n  end\nend",
        "language" => "ruby",
        "annotations" => [
          "Rescuing per subscriber is what actually fixes the original bug: a " \
          "warehouse outage no longer blocks completion.",
          "deliver_later moves the work off the request entirely, which matters " \
          "more than the pattern for latency.",
          "Rails gives you this already — ActiveSupport::Notifications and " \
          "model callbacks are Observer implementations."
        ] } ],
    [ :comparison, "Three ways to decouple",
      { "rows" => [
          { "aspect" => "Direct calls", "trace" => "Obvious", "fail" => "One failure breaks all",
            "when" => "One or two stable reactions" },
          { "aspect" => "Observer (in process)", "trace" => "Hidden",
            "fail" => "Isolatable with rescue", "when" => "Many reactions, same process" },
          { "aspect" => "Background jobs", "trace" => "Hidden",
            "fail" => "Retried independently", "when" => "Slow or external work" }
        ],
        "columns" => { "trace" => "Traceability", "fail" => "Failure isolation",
                       "when" => "Use when" } } ],
    [ :pitfall, "Callbacks are Observer with no opt-out",
      { "body" => "ActiveRecord callbacks are the same pattern wired in " \
                  "permanently: a model that sends email in `after_create` " \
                  "sends email in your tests, your seeds and your console. " \
                  "Prefer an explicit call in the service that owns the " \
                  "use case, so the side effect is visible and avoidable." } ],
    [ :interactive, "Which decoupling?",
      { "kind" => "risk_spotter",
        "prompt" => "Pick the mechanism.",
        "cases" => [
          { "sql" => "Update a counter after a save", "risk" => true,
            "why" => "Direct call — one cheap reaction needs no pattern." },
          { "sql" => "Six unrelated reactions to one event", "risk" => false,
            "why" => "Observer, with per-subscriber rescue." },
          { "sql" => "Call a third-party API after checkout", "risk" => false,
            "why" => "Background job — it can fail and retry without the user waiting." },
          { "sql" => "Audit every model change", "risk" => true,
            "why" => "A callback or concern is appropriate: it genuinely applies " \
                     "to every path." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "Checkout latency doubled after a loyalty-points " \
                       "integration was added as a subscriber. Everything still " \
                       "works.",
        "question" => "What went wrong architecturally?",
        "answer" => "The subscriber runs synchronously inside the request, so " \
                    "decoupling the code did nothing for the latency — the user " \
                    "still waits for an HTTP call to a third party. Observer " \
                    "separates knowledge, not timing. The fix is for the " \
                    "subscriber to enqueue a job, so the work happens after the " \
                    "response and can retry on failure." } ],
    [ :interview, "How this is asked",
      { "question" => "When would you use the Observer pattern, and what does " \
                      "it cost?",
        "good_answer" => "When one event has many reactions that do not belong " \
                         "to it and keep being added — it stops the publisher " \
                         "depending on every consumer. The cost is traceability: " \
                         "the flow is no longer readable in one place. It also " \
                         "does not make anything asynchronous on its own, so " \
                         "slow reactions still need a background job." } ],
    [ :revision, "Recall",
      { "prompt" => "What does Observer decouple, and what does it not?",
        "answer" => "It decouples who knows about whom; it does not change when " \
                    "the work runs." } ]
  ]
)

challenge!(
  slug: "observer-isolated-failure", title: "One bad subscriber must not break the rest",
  topic: p1, skill_slug: "design-patterns", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Build a publisher.\n\n" \
          "`Publisher#subscribe(callable)` registers a subscriber. " \
          "`#publish(event)` calls every subscriber in registration order with " \
          "the event, and returns the number that succeeded.\n\n" \
          "A subscriber that raises must not stop the others, and must not " \
          "count as a success. That isolation is the point.",
  starter: "class Publisher\n" \
           "  def initialize\n    @subscribers = []\n  end\n\n" \
           "  def subscribe(callable)\n  end\n\n" \
           "  def publish(event)\n  end\nend\n",
  solution: "class Publisher\n" \
            "  def initialize\n    @subscribers = []\n  end\n\n" \
            "  def subscribe(callable)\n" \
            "    @subscribers << callable\n    self\n  end\n\n" \
            "  def publish(event)\n" \
            "    @subscribers.count do |subscriber|\n" \
            "      begin\n" \
            "        subscriber.call(event)\n" \
            "        true\n" \
            "      rescue StandardError\n" \
            "        false\n" \
            "      end\n" \
            "    end\n" \
            "  end\nend\n",
  explanation: "Rescuing **per subscriber** rather than around the whole loop is " \
               "what makes the failure isolated — wrap the loop instead and the " \
               "first exception still stops everyone after it. Rescuing " \
               "StandardError rather than Exception leaves genuine interrupts " \
               "alone.",
  tests: [
    [ "calls every subscriber",
      "p = Publisher.new; seen = []; p.subscribe(->(e) { seen << e }); " \
      "p.subscribe(->(e) { seen << e }); p.publish(:x); seen", "[:x, :x]" ],
    [ "returns the success count",
      "p = Publisher.new; p.subscribe(->(e) { 1 }); p.subscribe(->(e) { 2 }); p.publish(:x)",
      "2" ],
    [ "a raising subscriber does not stop the others",
      "p = Publisher.new; seen = []; p.subscribe(->(e) { raise 'boom' }); " \
      "p.subscribe(->(e) { seen << e }); p.publish(:x); seen", "[:x]" ],
    [ "a raising subscriber is not counted",
      "p = Publisher.new; p.subscribe(->(e) { raise 'boom' }); " \
      "p.subscribe(->(e) { 1 }); p.publish(:x)", "1" ],
    [ "returns zero with no subscribers", "Publisher.new.publish(:x)", "0" ],
    [ "preserves registration order",
      "p = Publisher.new; order = []; p.subscribe(->(e) { order << 1 }); " \
      "p.subscribe(->(e) { order << 2 }); p.publish(:x); order", "[1, 2]" ],
    [ "all subscribers raising gives zero",
      "p = Publisher.new; 2.times { p.subscribe(->(e) { raise 'x' }) }; p.publish(:x)",
      "0", true ]
  ],
  hints: [
    [ :nudge, "Where does the `rescue` go — around the loop, or inside it?", 3 ],
    [ :concept, "Inside: each subscriber needs its own protection, otherwise the " \
                "first failure ends the loop.", 5 ],
    [ :solution, "`@subscribers.count { |s| begin; s.call(event); true; rescue " \
                 "StandardError; false; end }`", 9 ]
  ]
)

challenge!(
  slug: "debug-observer-breaks-publisher", title: "The outage that blocked checkout",
  topic: p1, skill_slug: "design-patterns", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`complete_order(order, subscribers)` must mark the order complete " \
          "and notify every subscriber, returning the order's status.\n\n" \
          "A single failing subscriber currently aborts the whole thing, so a " \
          "third-party outage prevents orders completing. Worse, the status is " \
          "set *after* the notifications.\n\nFix both.",
  starter: "def complete_order(order, subscribers)\n" \
           "  subscribers.each { |s| s.call(order) }\n" \
           "  order[:status] = 'complete'\n" \
           "  order[:status]\n" \
           "end\n",
  solution: "def complete_order(order, subscribers)\n" \
            "  order[:status] = 'complete'\n" \
            "  subscribers.each do |s|\n" \
            "    s.call(order)\n" \
            "  rescue StandardError\n" \
            "    nil\n" \
            "  end\n" \
            "  order[:status]\n" \
            "end\n",
  explanation: "Two fixes, and the ordering one matters more. Completing the " \
               "order first means the business outcome is recorded before any " \
               "optional side effect can fail. Rescuing per subscriber then " \
               "stops one outage affecting the others. A subscriber is by " \
               "definition not essential to the event — if it were, it would " \
               "belong in the method.",
  tests: [
    [ "completes with no subscribers", "complete_order({status: 'open'}, [])", '"complete"' ],
    [ "notifies every subscriber",
      "seen = []; complete_order({status: 'open'}, [->(o) { seen << 1 }, ->(o) { seen << 2 }]); seen",
      "[1, 2]" ],
    [ "completes despite a failing subscriber",
      "complete_order({status: 'open'}, [->(o) { raise 'api down' }])", '"complete"' ],
    [ "later subscribers still run after a failure",
      "seen = []; complete_order({status: 'open'}, [->(o) { raise 'x' }, ->(o) { seen << 2 }]); seen",
      "[2]" ],
    [ "subscribers see the completed status",
      "seen = []; complete_order({status: 'open'}, [->(o) { seen << o[:status] }]); seen",
      '["complete"]' ],
    [ "mutates the order hash",
      "o = {status: 'open'}; complete_order(o, []); o[:status]", '"complete"', true ]
  ],
  hints: [
    [ :nudge, "Two problems: what happens when a subscriber raises, and what " \
              "order the two steps happen in.", 3 ],
    [ :concept, "Record the outcome first, then notify, rescuing each subscriber " \
                "individually.", 5 ],
    [ :solution, "Set the status, then `subscribers.each do |s| ... rescue " \
                 "StandardError; nil; end`.", 10 ]
  ]
)

question!(
  body: "Checkout latency doubled after a loyalty integration was added as an " \
        "observer. Everything still works. What went wrong?",
  skill_slug: "design-patterns", type: "architecture", band: :senior, difficulty: :hard,
  topic: p1, company_type: "product",
  model: "Observer decoupled the code but not the timing: the subscriber runs " \
         "synchronously inside the request, so the user waits for a third-party " \
         "HTTP call. The pattern separates who knows about whom, not when work " \
         "happens. The fix is for the subscriber to enqueue a background job, " \
         "which also lets the call retry without affecting checkout.",
  explanation: "A common misconception is that decoupling implies asynchrony.",
  mistakes: "Assuming Observer makes things async, or removing the integration " \
            "rather than moving it off the request.",
  answer_key: { "keywords" => [ "synchronous", "request", "background",
                                "job", "async", "timing" ],
                "required" => [ "synchronous" ] },
  follow_ups: [
    { body: "What else does moving it to a job buy you?",
      trigger: "always",
      expects: [ "retry", "isolat", "failure", "latency" ],
      model: "Retries and failure isolation: a third-party outage becomes a " \
             "retried job rather than a failed checkout, and the user never " \
             "waits for it." },
    { body: "What is the downside of the observer approach here?",
      trigger: "always",
      expects: [ "trace", "hidden", "debug", "find" ],
      model: "Traceability. Reading the checkout code no longer tells you the " \
             "loyalty points are awarded, so debugging a missing award means " \
             "knowing to look for subscribers." }
  ]
)

# =============================================================== architecture
a1 = mission!(
  curriculum_module: arch_mod, slug: "monolith-or-services", position: 1,
  name: "The distributed monolith", skill_slug: "architecture",
  minutes: 9, xp: 25, difficulty: :hard,
  hook: "A team split one Rails app into eight services. Deploys now require " \
        "coordinating four of them, a single page makes eleven network calls, " \
        "and nobody can run the system locally. They have all the costs of " \
        "distribution and none of the benefits.",
  summary: "What services actually buy, what they cost, and the middle path.",
  blocks: [
    [ :prose, "Services buy independence, not cleanliness",
      { "body" => "Splitting into services buys independent deployment and " \
                  "scaling — and only if the boundaries are drawn where the " \
                  "coupling is low. Drawn in the wrong place, you get the " \
                  "network's failure modes with none of the independence: a " \
                  "distributed monolith." } ],
    [ :visual, "What changes when a call crosses a process",
      { "kind" => "join_result",
        "result" => { "columns" => [ "concern", "in-process", "across a service" ],
                      "rows" => [
                        [ "Failure", "An exception", "Timeout, retry, partial success" ],
                        [ "Consistency", "One transaction", "No shared transaction" ],
                        [ "Latency", "Nanoseconds", "Milliseconds, variable" ],
                        [ "Moving a boundary", "A rename", "A coordinated migration" ],
                        [ "Debugging", "One stack trace", "Correlated logs" ]
                      ] },
        "caption" => "Every row is a cost you take on. They are worth paying for " \
                     "independence you actually need." } ],
    [ :prediction, "Which split is safe?",
      { "question" => "Which boundary is least likely to produce a distributed " \
                      "monolith?",
        "options" => [ "Split by database table",
                       "Split by technical layer (one service for all controllers)",
                       "Split where a team owns a capability end to end",
                       "Split by programming language preference" ],
        "answer" => 2,
        "explanation" => "A boundary that follows a capability and its owning " \
                         "team means most changes stay inside one service. " \
                         "Splitting by table or layer guarantees that every " \
                         "feature touches several services, which is exactly the " \
                         "coordination cost you were trying to avoid." } ],
    [ :comparison, "Three architectures",
      { "rows" => [
          { "aspect" => "Monolith", "deploy" => "One unit", "data" => "One transaction",
            "cost" => "Scales as one; can become tangled" },
          { "aspect" => "Modular monolith", "deploy" => "One unit",
            "data" => "One transaction",
            "cost" => "Needs discipline to keep boundaries" },
          { "aspect" => "Microservices", "deploy" => "Independent",
            "data" => "Per service, eventually consistent",
            "cost" => "Network failure, ops overhead, no shared transaction" }
        ],
        "columns" => { "deploy" => "Deployment", "data" => "Data", "cost" => "Main cost" } } ],
    [ :code_demo, "A boundary you can enforce in one codebase",
      { "code" => "# A module boundary with an explicit public interface.\n# Everything outside goes through Billing; nothing reaches inside it.\nmodule Billing\n  def self.charge(order_id:, amount_cents:)\n    Billing::ChargeOrder.new(order_id:, amount_cents:).call\n  end\nend\n\n# Elsewhere: no reaching into Billing's internals\nBilling.charge(order_id: 1, amount_cents: 1999)   # allowed\nBilling::Gateway.new.charge(1999)                 # not allowed\n\n# The boundary is testable, and a packaging tool can fail the build\n# if anything outside Billing references its internals.",
        "language" => "ruby",
        "annotations" => [
          "This gives most of the clarity of a service with none of the network.",
          "If the boundary turns out to be wrong, moving it is a refactor rather " \
          "than a migration.",
          "When a module genuinely needs separate scaling, it is already shaped " \
          "to extract."
        ] } ],
    [ :pitfall, "The shared database",
      { "body" => "Two services reading each other's tables are not independent: " \
                  "a schema change breaks the other, and you cannot deploy them " \
                  "separately. That is the clearest sign of a distributed " \
                  "monolith — and it is worse than one monolith, because the " \
                  "coupling is now invisible." } ],
    [ :interactive, "Worth a service?",
      { "kind" => "risk_spotter",
        "prompt" => "Does each case justify a separate service?",
        "cases" => [
          { "sql" => "Video transcoding: CPU-heavy, bursty, separate scaling",
            "risk" => false, "why" => "Yes — genuinely different resource profile." },
          { "sql" => "A 'users service' every other service calls each request",
            "risk" => true, "why" => "No — on the hot path of everything; use a library or module." },
          { "sql" => "A team of eight owning payments end to end",
            "risk" => false, "why" => "Defensible — independent deploys help a whole team." },
          { "sql" => "Splitting so each model gets its own service",
            "risk" => true, "why" => "No — guarantees cross-service calls for every feature." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "Eight services, deploys need coordinating across four, " \
                       "one page makes eleven network calls, and two services " \
                       "share a database.",
        "question" => "What would you do first?",
        "answer" => "Not a rewrite. First make the shared database single-owner: " \
                    "while two services write the same tables they can never " \
                    "deploy independently, so that is the coupling to break. " \
                    "Then look at why a page needs eleven calls — usually a " \
                    "boundary drawn across a read that should be one query, " \
                    "which argues for merging those services back. Merging two " \
                    "services is a legitimate and underused move." } ],
    [ :interview, "How this is asked",
      { "question" => "When would you choose microservices over a monolith?",
        "good_answer" => "When independent deployment or scaling is worth the " \
                         "network's costs — usually at a team size where one " \
                         "deploy pipeline is a bottleneck, or where one component " \
                         "has a genuinely different resource profile. I would " \
                         "start with a modular monolith, because the boundary is " \
                         "cheap to move while you are still learning where it " \
                         "belongs." } ],
    [ :revision, "Recall",
      { "prompt" => "What is the clearest sign of a distributed monolith?",
        "answer" => "Services that cannot be deployed independently — most often " \
                    "because they share a database." } ]
  ]
)

challenge!(
  slug: "enforce-module-boundary", title: "Enforce the boundary",
  topic: a1, skill_slug: "architecture", type: :implement, difficulty: :medium, xp: 45,
  prompt: "A modular monolith only works if the boundaries are enforced. " \
          "Write the check.\n\n" \
          "`boundary_violations(references, public_api)` takes references like " \
          "`\"Billing::Gateway\"` and a hash of module name to its permitted " \
          "public constants (e.g. `{\"Billing\" => [\"Billing\"]}`).\n\n" \
          "Return the references that reach inside a module they are not " \
          "allowed into, sorted. A reference to a module not in `public_api` is " \
          "unconstrained and never a violation.",
  starter: "def boundary_violations(references, public_api)\n  # Your code here\nend\n",
  solution: "def boundary_violations(references, public_api)\n" \
            "  references.select do |reference|\n" \
            "    root = reference.split(\"::\").first\n" \
            "    allowed = public_api[root]\n" \
            "    allowed && !allowed.include?(reference)\n" \
            "  end.sort\n" \
            "end\n",
  explanation: "Taking the root namespace and asking whether the full reference " \
               "is on that module's allow-list is the whole rule. This is what " \
               "packaging tools do: a build that fails on a boundary violation " \
               "is the only thing that keeps a modular monolith modular, because " \
               "the alternative is relying on everyone remembering.",
  tests: [
    [ "flags a reach into internals",
      "boundary_violations(['Billing::Gateway'], {'Billing' => ['Billing']})",
      '["Billing::Gateway"]' ],
    [ "allows the public entry point",
      "boundary_violations(['Billing'], {'Billing' => ['Billing']})", "[]" ],
    [ "allows an explicitly published constant",
      "boundary_violations(['Billing::Result'], {'Billing' => ['Billing', 'Billing::Result']})",
      "[]" ],
    [ "ignores unconstrained modules",
      "boundary_violations(['Shipping::Internal'], {'Billing' => ['Billing']})", "[]" ],
    [ "sorts the violations",
      "boundary_violations(['Billing::Z', 'Billing::A'], {'Billing' => ['Billing']})",
      '["Billing::A", "Billing::Z"]' ],
    [ "returns empty for no references",
      "boundary_violations([], {'Billing' => ['Billing']})", "[]" ],
    [ "handles deep nesting",
      "boundary_violations(['Billing::A::B'], {'Billing' => ['Billing']})",
      '["Billing::A::B"]', true ]
  ],
  hints: [
    [ :nudge, "Which part of `Billing::Gateway` tells you which module's rules " \
              "apply?", 3 ],
    [ :concept, "Split on `::` and take the first segment, then look that module " \
                "up in the allow-list.", 4 ],
    [ :solution, "Select references whose root is constrained and whose full name " \
                 "is not in that module's allowed list, then sort.", 9 ]
  ]
)

challenge!(
  slug: "debug-shared-database-coupling", title: "Two owners, one table",
  topic: a1, skill_slug: "architecture", type: :debug, difficulty: :hard, xp: 55,
  prompt: "`deployable_independently?(services)` should report whether a set of " \
          "services can be deployed independently.\n\n" \
          "Each service is `{name:, writes: [tables], reads: [tables]}`. Two " \
          "services **writing** the same table are coupled and cannot deploy " \
          "independently. Reading a table someone else writes is acceptable.\n\n" \
          "The current version flags any shared table at all, including " \
          "read-only sharing. Fix it to consider writes only.",
  starter: "def deployable_independently?(services)\n" \
           "  all = services.flat_map { |s| s[:writes] + s[:reads] }\n" \
           "  all.uniq.length == all.length\n" \
           "end\n",
  solution: "def deployable_independently?(services)\n" \
            "  writes = services.flat_map { |s| s[:writes] }\n" \
            "  writes.uniq.length == writes.length\n" \
            "end\n",
  explanation: "Shared writes are the coupling: two services whose schemas must " \
               "agree cannot be migrated or deployed separately. A shared read is " \
               "weaker — undesirable, but it does not block a deploy. Treating " \
               "all sharing as equal would condemn perfectly deployable designs, " \
               "and the distinction is the whole point of single-writer " \
               "ownership.",
  tests: [
    [ "independent when writes do not overlap",
      "deployable_independently?([{name: 'a', writes: ['orders'], reads: []}, " \
      "{name: 'b', writes: ['users'], reads: []}])", "true" ],
    [ "coupled when two services write the same table",
      "deployable_independently?([{name: 'a', writes: ['orders'], reads: []}, " \
      "{name: 'b', writes: ['orders'], reads: []}])", "false" ],
    [ "a shared read is acceptable",
      "deployable_independently?([{name: 'a', writes: ['orders'], reads: ['users']}, " \
      "{name: 'b', writes: ['users'], reads: ['orders']}])", "true" ],
    [ "a single service is always independent",
      "deployable_independently?([{name: 'a', writes: ['orders'], reads: ['orders']}])",
      "true" ],
    [ "handles no services", "deployable_independently?([])", "true" ],
    [ "detects coupling among three services",
      "deployable_independently?([{name: 'a', writes: ['x'], reads: []}, " \
      "{name: 'b', writes: ['y'], reads: []}, {name: 'c', writes: ['x'], reads: []}])",
      "false", true ]
  ],
  hints: [
    [ :nudge, "Is sharing a read as harmful as sharing a write?", 3 ],
    [ :concept, "Only writes force schemas to agree, so only writes block " \
                "independent deployment.", 5 ],
    [ :solution, "Collect only `:writes` across services and check for " \
                 "duplicates.", 10 ]
  ]
)

question!(
  body: "A team split a Rails app into eight services. Deploys need " \
        "coordinating, one page makes eleven network calls, and two services " \
        "share a database. What would you do?",
  skill_slug: "architecture", type: "system_design", band: :staff, difficulty: :expert,
  topic: a1, company_type: "product",
  model: "Not a rewrite. The shared database is the first thing to fix, because " \
         "while two services write the same tables they can never deploy " \
         "independently — which was the only reason to split. Give each table a " \
         "single writing owner and have the other go through an interface. Then " \
         "examine the eleven calls: that usually means a boundary was drawn " \
         "across a read that should be one query, which argues for merging those " \
         "services back. Merging is a legitimate move and is underused.",
  explanation: "The strongest answers resist both 'rewrite it' and 'add a " \
               "gateway', and treat merging services as a real option.",
  mistakes: "Proposing a service mesh or API gateway, which adds operational " \
            "complexity without addressing the coupling.",
  answer_key: { "keywords" => [ "shared database", "single owner", "merge",
                                "boundary", "deploy", "independent" ],
                "required" => [ "shared database" ] },
  related: [ "modular monolith", "bounded contexts", "data ownership" ],
  follow_ups: [
    { body: "Why is a shared database worse than a monolith?",
      trigger: "always",
      expects: [ "invisible", "coupling", "schema", "transaction" ],
      model: "Because you keep the coupling but lose the guarantees: a schema " \
             "change still breaks both, yet you no longer have one transaction " \
             "or one deploy. The coupling is also invisible, since nothing in " \
             "either codebase declares it." },
    { body: "How would you decide where a boundary belongs?",
      trigger: "always",
      expects: [ "team", "capability", "change together", "coupling" ],
      model: "Where things change together. If a typical feature touches two " \
             "services, the boundary is in the wrong place. Aligning it with a " \
             "capability a team owns end to end keeps most changes local." },
    { body: "When is extracting a service clearly right?",
      trigger: "always",
      expects: [ "scaling", "resource", "team", "bottleneck" ],
      model: "When a component has a genuinely different resource profile — " \
             "CPU-heavy transcoding, say — or when one deploy pipeline has " \
             "become a bottleneck for several teams." }
  ]
)

# ========================================================= distributed systems
d1 = mission!(
  curriculum_module: dist_mod, slug: "partial-failure", position: 1,
  name: "The request that both succeeded and failed", skill_slug: "distributed-systems",
  minutes: 9, xp: 25, difficulty: :hard,
  hook: "You call the payment API. It times out. Did the charge happen? You " \
        "cannot know — and that uncertainty, not the timeout, is the defining " \
        "problem of distributed systems.",
  summary: "Partial failure, safe retries, and consistency you can actually get.",
  blocks: [
    [ :prose, "A timeout is not a failure",
      { "body" => "In one process a call either returns or raises. Across a " \
                  "network there is a third outcome: you do not find out. The " \
                  "request may have been lost, or it may have succeeded and the " \
                  "response was lost. Retrying is only safe if the receiver can " \
                  "recognise a duplicate." } ],
    [ :visual, "Three outcomes, not two",
      { "kind" => "join_result",
        "result" => { "columns" => [ "what you observe", "what may have happened", "safe to retry?" ],
                      "rows" => [
                        [ "200 OK", "It succeeded", "No need" ],
                        [ "400 / 422", "It was rejected", "No — it will be rejected again" ],
                        [ "Timeout", "Succeeded, or never arrived", "Only with an idempotency key" ],
                        [ "Connection refused", "Never arrived", "Yes" ]
                      ] },
        "caption" => "The timeout row is the whole difficulty. Treating it as " \
                     "failed double-charges; treating it as succeeded loses money." } ],
    [ :prediction, "What makes the retry safe?",
      { "question" => "Your charge request times out. What single thing makes " \
                      "retrying safe?",
        "options" => [ "A shorter timeout",
                       "An idempotency key the provider recognises",
                       "Retrying only once",
                       "Logging the attempt before sending" ],
        "answer" => 1,
        "explanation" => "An idempotency key. The provider records the key with " \
                         "the result, so a retry carrying the same key returns " \
                         "the original outcome instead of charging again. " \
                         "Nothing about timeout length or retry count can make " \
                         "an unsafe operation safe." } ],
    [ :code_demo, "Retry only what is safe to retry",
      { "code" => "# The key is derived from the business fact, not random,\n# so a retry of the same intent reuses it.\nkey = \"charge-order-42\"\nattempts = 0\n\nbegin\n  Gateway.charge(amount: 1999, idempotency_key: key)\nrescue Gateway::Timeout\n  retry if (attempts += 1) < 3     # safe: the key dedupes\nrescue Gateway::Rejected\n  raise                            # not safe: it will be rejected again\nend\n\n# Reconciliation closes the remaining gap: if you never learned the\n# outcome, ask later rather than guessing.\nGateway.find_charge(idempotency_key: key)",
        "language" => "ruby",
        "annotations" => [
          "A random key per attempt defeats the entire mechanism.",
          "Retry timeouts, never rejections — a 422 will be a 422 again.",
          "Reconciliation is the backstop: a job that asks the provider what " \
          "actually happened."
        ] } ],
    [ :comparison, "What consistency you can have",
      { "rows" => [
          { "aspect" => "Strong (one database)", "means" => "Every read sees the last write",
            "cost" => "Coordination; cannot span services cheaply" },
          { "aspect" => "Eventual", "means" => "Reads converge after a delay",
            "cost" => "Your UI must tolerate staleness" },
          { "aspect" => "Read-your-writes", "means" => "The author sees their own change",
            "cost" => "Often enough, and much cheaper than strong" }
        ],
        "columns" => { "means" => "Means", "cost" => "Cost" } } ],
    [ :pitfall, "Retries amplify an outage",
      { "body" => "When a dependency slows down, every caller retries, " \
                  "multiplying the load on something already struggling. " \
                  "Exponential backoff with jitter spreads the retries out; a " \
                  "circuit breaker stops them entirely while the dependency is " \
                  "known to be down. Without both, your retry logic is a " \
                  "denial-of-service attack on your own system." } ],
    [ :interactive, "Retry or not?",
      { "kind" => "risk_spotter",
        "prompt" => "Should the caller retry?",
        "cases" => [
          { "sql" => "Connection refused on a GET", "risk" => false,
            "why" => "Yes — it never arrived, and a read is naturally idempotent." },
          { "sql" => "Timeout on a POST with no idempotency key", "risk" => true,
            "why" => "No — it may have succeeded. Add a key first." },
          { "sql" => "422 validation error", "risk" => true,
            "why" => "No — the same request will be rejected again." },
          { "sql" => "Timeout on a POST with an idempotency key", "risk" => false,
            "why" => "Yes — the provider will dedupe it." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A payment provider had a 90-second slowdown. Afterwards " \
                       "you find 300 duplicate charges and a queue of 40,000 " \
                       "retries that kept the provider down for a further ten " \
                       "minutes.",
        "question" => "Name the two independent failures.",
        "answer" => "First, the charge was not idempotent: retries after a " \
                    "timeout created second charges, which an idempotency key " \
                    "derived from the order would have prevented. Second, the " \
                    "retry policy had no backoff, jitter or circuit breaker, so " \
                    "every caller retried immediately and the retry traffic " \
                    "extended the outage well past the original cause. The " \
                    "second failure is the more expensive one: it turned a " \
                    "90-second blip into ten minutes." } ],
    [ :interview, "How this is asked",
      { "question" => "Your API call times out. How do you know whether it worked?",
        "good_answer" => "You cannot, from the timeout alone — the request or " \
                         "the response may have been lost. I would make the " \
                         "operation idempotent with a key derived from the " \
                         "business fact so a retry is safe, retry with " \
                         "exponential backoff and jitter, and add a " \
                         "reconciliation step that asks the provider what " \
                         "actually happened rather than guessing." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is a timeout different from an error response?",
        "answer" => "An error tells you the outcome; a timeout tells you nothing, " \
                    "so the operation may have succeeded." } ]
  ]
)

challenge!(
  slug: "idempotency-key-dedupe", title: "Dedupe by idempotency key",
  topic: d1, skill_slug: "distributed-systems", type: :implement, difficulty: :medium, xp: 50,
  prompt: "Implement the receiver's side of safe retries.\n\n" \
          "`Gateway#charge(key:, amount:)` must perform the charge once per " \
          "key. A repeat call with the same key returns the **original** result " \
          "without charging again, even if the amount differs — the key " \
          "identifies the intent.\n\n" \
          "Return `{charged: amount, replayed: false}` the first time and " \
          "`{charged: original_amount, replayed: true}` afterwards.",
  starter: "class Gateway\n" \
           "  def initialize\n    @seen = {}\n  end\n\n" \
           "  def charge(key:, amount:)\n    # Your code here\n  end\nend\n",
  solution: "class Gateway\n" \
            "  def initialize\n    @seen = {}\n  end\n\n" \
            "  def charge(key:, amount:)\n" \
            "    if @seen.key?(key)\n" \
            "      { charged: @seen[key], replayed: true }\n" \
            "    else\n" \
            "      @seen[key] = amount\n" \
            "      { charged: amount, replayed: false }\n" \
            "    end\n" \
            "  end\nend\n",
  explanation: "Recording the key with its result is what makes a retry safe: " \
               "the caller gets the original outcome rather than a second " \
               "charge. Returning the stored amount rather than the new one " \
               "matters — a retry with a different amount is a bug in the " \
               "caller, and replaying the original is the conservative response.",
  tests: [
    [ "charges the first time",
      "Gateway.new.charge(key: 'a', amount: 100)", "{charged: 100, replayed: false}" ],
    [ "replays on a repeat key",
      "g = Gateway.new; g.charge(key: 'a', amount: 100); g.charge(key: 'a', amount: 100)",
      "{charged: 100, replayed: true}" ],
    [ "returns the original amount even if the retry differs",
      "g = Gateway.new; g.charge(key: 'a', amount: 100); g.charge(key: 'a', amount: 999)",
      "{charged: 100, replayed: true}" ],
    [ "treats different keys independently",
      "g = Gateway.new; g.charge(key: 'a', amount: 1); g.charge(key: 'b', amount: 2)",
      "{charged: 2, replayed: false}" ],
    [ "charges only once across many retries",
      "g = Gateway.new; 5.times { g.charge(key: 'a', amount: 10) }; " \
      "g.charge(key: 'a', amount: 10)[:replayed]", "true" ],
    [ "handles a zero amount",
      "g = Gateway.new; g.charge(key: 'z', amount: 0); g.charge(key: 'z', amount: 5)",
      "{charged: 0, replayed: true}", true ]
  ],
  hints: [
    [ :nudge, "What must you store so a retry can be answered without charging?", 3 ],
    [ :concept, "The key and the result. Check with `key?` so a zero amount " \
                "still counts as seen.", 5 ],
    [ :solution, "Store `@seen[key] = amount` on first call; on a repeat return " \
                 "the stored amount with `replayed: true`.", 10 ]
  ]
)

challenge!(
  slug: "debug-retry-everything", title: "The retry that doubled the charges",
  topic: d1, skill_slug: "distributed-systems", type: :debug, difficulty: :hard, xp: 60,
  prompt: "`send_with_retry(client, request, max_attempts)` retries a failed " \
          "call. It retries **every** failure, including rejections, and " \
          "returns the number of attempts made.\n\n" \
          "`client.call(request)` raises a RuntimeError with message " \
          "`\"timeout\"` or `\"rejected\"`, or returns `:ok`.\n\n" \
          "Retry only timeouts. A rejection must re-raise immediately — " \
          "retrying it cannot help and, without idempotency, risks duplicates.",
  starter: "def send_with_retry(client, request, max_attempts)\n" \
           "  attempts = 0\n" \
           "  begin\n" \
           "    attempts += 1\n" \
           "    client.call(request)\n" \
           "    attempts\n" \
           "  rescue RuntimeError\n" \
           "    retry if attempts < max_attempts\n" \
           "    attempts\n" \
           "  end\n" \
           "end\n",
  solution: "def send_with_retry(client, request, max_attempts)\n" \
            "  attempts = 0\n" \
            "  begin\n" \
            "    attempts += 1\n" \
            "    client.call(request)\n" \
            "    attempts\n" \
            "  rescue RuntimeError => e\n" \
            "    raise unless e.message == \"timeout\"\n" \
            "    retry if attempts < max_attempts\n" \
            "    attempts\n" \
            "  end\n" \
            "end\n",
  explanation: "Rescuing a broad class and retrying everything is the bug: a " \
               "rejection is a definite answer, so retrying it wastes attempts " \
               "and, for a non-idempotent write, risks duplicates. Inspecting " \
               "the failure and re-raising what cannot be retried is the whole " \
               "fix — retry transient faults, surface permanent ones.",
  tests: [
    [ "succeeds on the first attempt",
      "c = Object.new; def c.call(r); :ok; end; send_with_retry(c, :r, 3)", "1" ],
    [ "retries a timeout then succeeds",
      "c = Object.new; c.instance_variable_set(:@n, 0); " \
      "def c.call(r); @n += 1; raise 'timeout' if @n < 2; :ok; end; " \
      "send_with_retry(c, :r, 3)", "2" ],
    [ "stops at max attempts on repeated timeouts",
      "c = Object.new; def c.call(r); raise 'timeout'; end; send_with_retry(c, :r, 3)", "3" ],
    [ "does not retry a rejection",
      "c = Object.new; c.instance_variable_set(:@n, 0); " \
      "def c.call(r); @n += 1; raise 'rejected'; end; " \
      "begin; send_with_retry(c, :r, 5); rescue RuntimeError; c.instance_variable_get(:@n); end",
      "1" ],
    [ "re-raises the rejection",
      "c = Object.new; def c.call(r); raise 'rejected'; end; " \
      "begin; send_with_retry(c, :r, 3); rescue RuntimeError => e; e.message; end",
      '"rejected"' ],
    [ "honours a single allowed attempt",
      "c = Object.new; def c.call(r); raise 'timeout'; end; send_with_retry(c, :r, 1)",
      "1", true ]
  ],
  hints: [
    [ :nudge, "Are all failures equally worth retrying?", 3 ],
    [ :concept, "A rejection is a definite answer; a timeout is not. Inspect the " \
                "error before deciding.", 5 ],
    [ :solution, "`rescue RuntimeError => e` then `raise unless e.message == " \
                 "\"timeout\"` before the retry.", 11 ]
  ]
)

question!(
  body: "Your payment API call times out. How do you know whether the charge " \
        "happened, and what do you do?",
  skill_slug: "distributed-systems", type: "scenario", band: :staff, difficulty: :expert,
  topic: d1, company_type: "fintech",
  model: "From the timeout alone you cannot know — either the request or the " \
         "response may have been lost. I would make the operation idempotent " \
         "with a key derived from the business fact, such as the order id, so a " \
         "retry returns the original result instead of charging again. Retries " \
         "use exponential backoff with jitter and a circuit breaker so they do " \
         "not amplify the outage, and a reconciliation job asks the provider " \
         "what actually happened rather than guessing.",
  explanation: "Partial failure is the defining difficulty of distributed " \
               "systems; the strongest answers name idempotency and reconciliation.",
  mistakes: "Treating a timeout as a definite failure and retrying blindly, or " \
            "using a random idempotency key per attempt, which defeats it.",
  answer_key: { "keywords" => [ "idempot", "key", "retry", "backoff", "jitter",
                                "reconcil", "unknown" ],
                "required" => [ "idempot" ] },
  related: [ "circuit breakers", "exponential backoff", "reconciliation" ],
  follow_ups: [
    { body: "Where does the idempotency key come from?",
      trigger: "always",
      expects: [ "business", "order", "deterministic", "not random", "same" ],
      model: "It must be derived deterministically from the business intent — the " \
             "order id, say — so every retry of the same intent carries the same " \
             "key. A fresh random key per attempt makes each retry look like a " \
             "new charge." },
    { body: "You mentioned retries. How do you stop them making the outage worse?",
      trigger: "keyword", keywords: [ "retry", "backoff", "again" ],
      expects: [ "backoff", "jitter", "circuit", "cap", "budget" ],
      model: "Exponential backoff with jitter so retries spread out rather than " \
             "arriving in sync, a capped attempt count, and a circuit breaker " \
             "that stops calling entirely while the dependency is known to be " \
             "down." },
    { body: "What consistency guarantee would you aim for across two services?",
      trigger: "always",
      expects: [ "eventual", "read-your-writes", "strong", "converge" ],
      model: "Usually eventual consistency, because a shared transaction across " \
             "services is not available. Read-your-writes is often the specific " \
             "guarantee users actually notice, and it is much cheaper than " \
             "strong consistency." }
  ]
)
