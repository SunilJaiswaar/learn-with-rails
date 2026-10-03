include SeedDSL
# The Rails vertical slice (spec 11-14, 114).
#
# Rails is the brief's flagship specialisation and had no curriculum at all:
# no skill, no mission, no challenge. This is the first slice — the request
# lifecycle, routing and controllers — built to the spec 116 definition of
# done rather than to the per-mission floor.
#
# Every coding challenge here is pure Ruby. The sandbox has no Rails loaded and
# must not: these model the *mechanism* (an onion of layers, a route matcher, a
# halting callback chain) so the learner implements the idea rather than
# memorising an API. Rails itself is explored in the Rails Request Lab, which
# traces a request through this application's real middleware stack.
puts "  Rails: request lifecycle, routing, controllers"

rails = Technology.find_or_create_by!(slug: "rails") do |t|
  t.name = "Ruby on Rails"
  t.category = "framework"
  t.position = 4
  t.icon = "🚂"
  t.summary = "The framework this platform is built with, and the one it teaches most deeply."
end

[
  { number: "8.1", status: :current, released_on: Date.new(2025, 9, 4),
    docs_url: "https://guides.rubyonrails.org/",
    notes: "What this application runs. Default in all content unless stated." },
  { number: "8.0", status: :maintained, released_on: Date.new(2024, 11, 7),
    docs_url: "https://guides.rubyonrails.org/v8.0/",
    notes: "Still common in production; Solid Queue and Solid Cache became defaults here." },
  { number: "7.2", status: :maintained, released_on: Date.new(2024, 8, 9),
    docs_url: "https://guides.rubyonrails.org/v7.2/",
    notes: "Widely deployed. Worth knowing for interviews at companies that have not upgraded." },
  { number: "6.1", status: :eol, released_on: Date.new(2020, 12, 9),
    notes: "No longer receiving security fixes. Appears here only so legacy code is readable." }
].each do |attrs|
  TechnologyVersion.find_or_create_by!(technology: rails, number: attrs[:number]) do |v|
    v.assign_attributes(attrs)
  end
end

v81 = version!("rails", "8.1")

citadel = World.find_or_create_by!(slug: "rails-citadel") do |w|
  w.name = "Rails Citadel"
  w.position = 10
  w.accent_color = "#dc2626"
  w.icon = "🚂"
  w.tagline = "A framework is a machine, not a list of methods."
  w.summary = "Where a request comes from, what runs before your code, and " \
              "which layer to blame when the answer is wrong."
end

# --- Skills ------------------------------------------------------------------
# The chain is deliberate: you cannot reason about routing until you know what
# ran before the router, and you cannot reason about a controller callback
# until you know routing picked the action.
[
  { slug: "rails-request-cycle", name: "The Request Cycle", world: citadel,
    technology: rails, tier: 2, position: 1, grid_x: 1, grid_y: 2,
    summary: "Socket to response: Puma, Rack, middleware, and what runs before you do.",
    prerequisites: %w[ruby-basics] },
  { slug: "rails-routing", name: "Routing & Params", world: citadel,
    technology: rails, tier: 3, position: 2, grid_x: 2, grid_y: 3,
    summary: "How a URL becomes a controller, an action and a params hash.",
    prerequisites: %w[rails-request-cycle] },
  { slug: "rails-controllers", name: "Controllers & Callbacks", world: citadel,
    technology: rails, tier: 3, position: 3, grid_x: 3, grid_y: 3,
    summary: "Callback order, halting the chain, and strong parameters.",
    prerequisites: %w[rails-routing] }
].each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

foundations = curriculum_module!(
  world_slug: "rails-citadel", slug: "rails-foundations", position: 1,
  name: "Foundations",
  summary: "What happens between the socket and your controller."
)

# ===================================================== 1. The request lifecycle
m1 = mission!(
  curriculum_module: foundations, slug: "rails-request-lifecycle", position: 1,
  name: "Before your code runs", skill_slug: "rails-request-cycle",
  minutes: 12, xp: 30, difficulty: :medium, technology: v81,
  hook: "A request reaches your controller having already passed through " \
        "23 layers. Two of the most common Rails bugs — a 404 you cannot " \
        "rescue and a session that silently refuses to grow — are decided " \
        "in those layers, before your code is reached.",
  summary: "Puma, Rack, the middleware onion, and which layer answers when.",
  blocks: [
    [ :prose, "Rack is an interface, not a library",
      { "body" => "Rack says an application is **anything that responds to " \
                  "`call(env)` and returns `[status, headers, body]`**. That is " \
                  "the entire contract. Your whole Rails application is one such " \
                  "object, and so is every piece of middleware wrapped around it.\n\n" \
                  "This is why middleware composes: each layer receives `env`, " \
                  "may change it, calls the next layer, and may change what " \
                  "comes back. The stack is an onion, and a request passes " \
                  "through every layer twice — inward, then outward." } ],
    [ :visual, "The onion, inward and outward",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "Puma (thread)", "points_to" => "env" },
                     { "label" => "middleware ×23", "points_to" => "env" },
                     { "label" => "Router", "points_to" => "env" } ],
        "objects" => [ { "id" => "env", "value" => "{ 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/skills/sql-joins', ... }" } ],
        "caption" => "Every layer is handed the same mutable `env` Hash. " \
                     "`X-Runtime` and `ETag` are attached on the way *out*, " \
                     "which is why they exist even when your controller never " \
                     "mentioned them." } ],
    [ :prediction, "Which layer answers?",
      { "question" => "You add `rescue_from ActionController::RoutingError` to " \
                      "ApplicationController, then request a path that matches " \
                      "no route. What happens?",
        "options" => [ "Your rescue_from handles it and renders your page",
                       "A 404 is rendered, and your rescue_from never runs",
                       "A 500 is raised because the rescue is in the wrong place",
                       "The router retries with the next matching route" ],
        "answer" => 1,
        "explanation" => "The router raises **before** any controller is chosen, " \
                         "so there is no controller instance to run your rescue. " \
                         "`ActionDispatch::ShowExceptions` — middleware, further " \
                         "out — turns it into a 404. To customise it you " \
                         "configure `exceptions_app`, not a controller." } ],
    [ :interactive, "Match the layer to its fingerprint",
      { "kind" => "pair_matching",
        "prompt" => "Each middleware leaves evidence you can see from outside. " \
                    "Pair them.",
        "left" => [ "Rack::Runtime", "ActionDispatch::RequestId",
                    "Rack::ETag", "ActionDispatch::Session::CookieStore",
                    "Rack::MethodOverride" ],
        "right" => [ "X-Runtime response header", "X-Request-Id response header",
                     "ETag from a digest of the body", "A 4KB ceiling on session",
                     "An HTML form can send PATCH" ],
        "note" => "The session limit is the one that surprises people: the " \
                  "session *is* a cookie, and cookies cap at 4KB, so storing " \
                  "a large object in it raises CookieOverflow." } ],
    [ :code_demo, "Middleware is just a wrapper",
      { "code" => "class Timing\n" \
                  "  def initialize(app)\n" \
                  "    @app = app          # the next layer inward\n" \
                  "  end\n\n" \
                  "  def call(env)\n" \
                  "    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)\n" \
                  "    status, headers, body = @app.call(env)   # inward\n" \
                  "    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started\n" \
                  "    headers['X-Runtime'] = elapsed.to_s      # outward\n" \
                  "    [ status, headers, body ]\n" \
                  "  end\n" \
                  "end",
        "language" => "ruby",
        "annotations" => [
          { "line" => 3, "note" => "`@app` is the rest of the stack, including your application." },
          { "line" => 8, "note" => "Everything after this line runs on the way out." },
          { "line" => 10, "note" => "Forget to return the triple and the response is gone." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A client reports that POSTs to your API intermittently " \
                       "return 429 with a Retry-After header. Your application " \
                       "logs show no matching requests at all — not even a " \
                       "'Started POST' line.",
        "question" => "Where are the requests going?",
        "answer" => "They are being refused by middleware before `Rails::Rack::Logger` " \
                    "runs, so nothing is logged as a request. Rack::Attack sits " \
                    "further out than the logger. Absence from the application " \
                    "log is evidence about *which layer* answered, not evidence " \
                    "that the request never arrived — check the proxy or " \
                    "middleware metrics instead." } ],
    [ :pitfall, "Three that bite",
      { "body" => "**Putting authentication in middleware** — it works, but you " \
                  "lose access to the route, so you cannot make per-action " \
                  "decisions. **Storing an object in `session`** — it is a 4KB " \
                  "cookie, and overflow raises. **Expecting `rescue_from` to " \
                  "catch a routing error** — by then there is no controller." } ],
    [ :revision, "Recall",
      { "prompt" => "Name the layer that decides each outcome: a 404 for an " \
                    "unknown path, a 429 for too many requests, a 422 for a " \
                    "missing CSRF token.",
        "answer" => "Router, middleware (Rack::Attack), controller callback. " \
                    "The spread is the point: all three are 'the request failed', " \
                    "and all three fail in a different place." } ]
  ]
)

challenge!(
  slug: "rails-middleware-stack", title: "Build the onion",
  topic: m1, skill_slug: "rails-request-cycle", type: :implement,
  difficulty: :medium, xp: 45,
  prompt: "Implement `run_stack(layers, app)`.\n\n" \
          "`app` is a lambda taking a Hash and returning a String. Each entry " \
          "in `layers` is a lambda taking `(env, next_layer)`; it may change " \
          "`env`, must call `next_layer.call(env)`, and may change the result " \
          "before returning it.\n\n" \
          "Return a lambda that runs the layers **outermost first** — " \
          "`layers.first` wraps everything — and finally calls `app`.\n\n" \
          "This is the whole of Rack's composition model in one method.",
  starter: "def run_stack(layers, app)\n  # Your code here\nend\n",
  solution: "def run_stack(layers, app)\n" \
            "  layers.reverse.reduce(app) do |inner, layer|\n" \
            "    ->(env) { layer.call(env, inner) }\n" \
            "  end\n" \
            "end\n",
  explanation: "Build from the inside out: fold the layers in reverse, each one " \
               "closing over the stack built so far. That is exactly how " \
               "`Rack::Builder` assembles your application at boot — which is " \
               "why the stack is fixed once the process starts.",
  tests: [
    [ "with no layers it is just the app",
      "run_stack([], ->(env) { 'app' }).call({})", '"app"' ],
    [ "a single layer wraps the app",
      "run_stack([->(env, nxt) { \"[\#{nxt.call(env)}]\" }], ->(env) { 'app' }).call({})",
      '"[app]"' ],
    [ "the first layer is outermost",
      "run_stack([->(env, nxt) { \"a(\#{nxt.call(env)})\" }, ->(env, nxt) { \"b(\#{nxt.call(env)})\" }], ->(env) { 'app' }).call({})",
      '"a(b(app))"' ],
    [ "a layer can change env on the way in",
      "run_stack([->(env, nxt) { nxt.call(env.merge(id: 7)) }], ->(env) { env[:id].to_s }).call({})",
      '"7"' ],
    [ "env changes are visible to inner layers only",
      "run_stack([->(env, nxt) { nxt.call(env.merge(n: 1)) }, ->(env, nxt) { nxt.call(env.merge(n: env[:n] + 1)) }], ->(env) { env[:n].to_s }).call({})",
      '"2"' ],
    [ "a layer can answer without calling inward",
      "run_stack([->(env, nxt) { 'refused' }], ->(env) { 'app' }).call({})",
      '"refused"', true ]
  ],
  hints: [
    [ :nudge, "You need to end up with a single lambda. Build it by folding the " \
              "layers over the app — but which direction?", 3 ],
    [ :concept, "The innermost thing is `app`. So start from `app` and wrap it, " \
                "which means iterating the layers *backwards*.", 4 ],
    [ :solution, "`layers.reverse.reduce(app) { |inner, layer| ->(env) { layer.call(env, inner) } }`", 8 ]
  ]
)

challenge!(
  slug: "rails-debug-middleware-swallow", title: "The response vanished",
  topic: m1, skill_slug: "rails-request-cycle", type: :debug,
  difficulty: :medium, xp: 55,
  prompt: "`apply_layers(layers, app)` should return the app's result after " \
          "every layer has seen it.\n\n" \
          "With one layer it works. With two, the result is `nil`. Find the " \
          "cause and fix it.\n\n" \
          "This is the single most common mistake when writing real middleware.",
  starter: "def apply_layers(layers, app)\n" \
           "  result = app.call\n" \
           "  layers.each do |layer|\n" \
           "    layer.call(result)\n" \
           "  end\n" \
           "end\n",
  solution: "def apply_layers(layers, app)\n" \
            "  layers.reduce(app.call) do |result, layer|\n" \
            "    layer.call(result)\n" \
            "  end\n" \
            "end\n",
  explanation: "`each` returns the collection it iterated, not the block's value, " \
               "so the method returned `layers` — and the transformed result was " \
               "discarded. Real middleware fails the same way: forget to " \
               "*return* `@app.call(env)` and the response disappears.",
  tests: [
    [ "one layer still works", "apply_layers([->(r) { r + 1 }], -> { 1 })", "2" ],
    [ "two layers compose", "apply_layers([->(r) { r + 1 }, ->(r) { r * 10 }], -> { 1 })", "20" ],
    [ "order is outermost first", "apply_layers([->(r) { r * 10 }, ->(r) { r + 1 }], -> { 1 })", "11" ],
    [ "no layers returns the app's own result", "apply_layers([], -> { 42 })", "42" ],
    [ "three layers", "apply_layers([->(r) { r + 1 }, ->(r) { r + 2 }, ->(r) { r + 3 }], -> { 0 })", "6", true ]
  ],
  hints: [
    [ :nudge, "Run it with two layers and print what the method returns. It is " \
              "not a number.", 3 ],
    [ :concept, "`each` always returns the receiver. If you need the accumulated " \
                "value, you need something that threads it through.", 4 ],
    [ :solution, "`layers.reduce(app.call) { |result, layer| layer.call(result) }`", 8 ]
  ]
)

question!(
  body: "Walk me through what happens between a user clicking a link and your " \
        "controller action running.",
  skill_slug: "rails-request-cycle", type: "architecture", band: :junior,
  difficulty: :medium, topic: m1, interview_type: "technical",
  model: "Puma accepts the connection and builds a Rack env hash, then hands it " \
         "to the application on a thread. The env passes through the middleware " \
         "stack — roughly 23 layers — which attaches a request id, works out the " \
         "remote IP, decodes cookies and the session, and may answer early: " \
         "Rack::Attack can return 429 before routing happens at all. The router " \
         "matches method and path against routes.rb and sets " \
         "params[:controller] and params[:action], or raises RoutingError. Then " \
         "the controller runs its before_action callbacks in order, any of which " \
         "can halt the chain, and finally the action. The view renders to a " \
         "string, and the response travels back out through every middleware in " \
         "reverse, which is where X-Runtime and ETag are added.",
  explanation: "Interviewers ask this to find out whether you can localise a bug. " \
               "The valuable part is not the list of layers but knowing which one " \
               "owns which decision.",
  mistakes: "Saying 'the controller handles the request' and stopping there; " \
            "putting the router before middleware; not knowing anything can " \
            "answer before the router.",
  related: %w[rack middleware routing],
  follow_ups: [
    { body: "Which layer would you blame for a 404 on a path that should exist?",
      trigger: "always",
      expects: %w[router routes route],
      model: "The router, so I would check routes.rb and `rails routes` first — " \
             "the controller is not involved in that decision." },
    { body: "A request returns 429 and nothing appears in the Rails log. Why?",
      trigger: "always",
      expects: %w[middleware before rack attack logger],
      model: "It was refused by middleware sitting further out than " \
             "Rails::Rack::Logger, so no request line was ever written." },
    { body: "You mentioned the session. What is its size limit, and why?",
      trigger: "keyword", keywords: %w[session cookie],
      expects: %w[4kb cookie],
      model: "About 4KB, because the default session store *is* a cookie and " \
             "browsers cap cookies there. Larger state needs a server-side " \
             "store." },
    { body: "Where would you add a header on every response, and why there?",
      trigger: "missing_keyword", keywords: %w[middleware],
      expects: %w[middleware after_action],
      model: "Middleware, if it truly applies to every response including ones " \
             "your controllers never see, such as asset or error responses. An " \
             "after_action only covers requests that reached a controller." }
  ]
)

# ============================================================== 2. Routing
m2 = mission!(
  curriculum_module: foundations, slug: "rails-routing-and-params", position: 2,
  name: "A URL becomes a method call", skill_slug: "rails-routing",
  minutes: 11, xp: 30, difficulty: :medium, technology: v81,
  hook: "`params` is one hash assembled from three different places. Not " \
        "knowing which place a key came from is how a strong-parameters bug " \
        "turns into a mass-assignment vulnerability.",
  summary: "Matching order, dynamic segments, and the three sources of params.",
  blocks: [
    [ :prose, "Routes are matched in order, first match wins",
      { "body" => "`routes.rb` is read top to bottom and the **first** matching " \
                  "route wins. Nothing warns you that a later route is now " \
                  "unreachable, which makes a catch-all route placed too early " \
                  "one of the quietest bugs in a Rails application.\n\n" \
                  "A route contributes to `params` too: every dynamic segment " \
                  "becomes a key, plus `:controller` and `:action`." } ],
    [ :visual, "Three sources, one hash",
      { "kind" => "growth_table",
        "sizes" => [ "source", "example", "arrives as" ],
        "rows" => [
          { "label" => "Route segments", "values" => [ "/skills/:id", "params[:id]" ] },
          { "label" => "Query string", "values" => [ "?page=2&sort=name", "params[:page], params[:sort]" ] },
          { "label" => "Request body", "values" => [ "a form POST", "params[:skill][:name]" ] }
        ],
        "caption" => "They merge into one hash, and a later source silently " \
                     "overwrites an earlier one on a key collision. This is " \
                     "exactly why you must permit explicitly rather than trust " \
                     "the shape of params." } ],
    [ :prediction, "Which route wins?",
      { "question" => "routes.rb contains, in this order:\n" \
                      "  get '/skills/:id', to: 'skills#show'\n" \
                      "  get '/skills/new', to: 'skills#new'\n\n" \
                      "What does GET /skills/new do?",
        "options" => [ "Runs skills#new",
                       "Runs skills#show with params[:id] = 'new'",
                       "Raises an ambiguous route error",
                       "Returns 404" ],
        "answer" => 1,
        "explanation" => "The first route matches, because `:id` happily captures " \
                         "the literal string `new`. The second route is " \
                         "unreachable and Rails never says so. Static segments " \
                         "must be declared before dynamic ones — which is why " \
                         "`resources` emits them in that order for you." } ],
    [ :interactive, "Spot the unreachable route",
      { "kind" => "risk_spotter",
        "prompt" => "Decide whether the second route can ever be reached.",
        "cases" => [
          { "sql" => "get '/p/:id' then get '/p/featured'", "risk" => true,
            "why" => "Unreachable — `:id` captures 'featured' first." },
          { "sql" => "get '/p/featured' then get '/p/:id'", "risk" => false,
            "why" => "Both reachable — the static segment is declared first." },
          { "sql" => "get '/*path' then get '/about'", "risk" => true,
            "why" => "Unreachable — a wildcard placed first swallows everything." },
          { "sql" => "post '/items' then get '/items'", "risk" => false,
            "why" => "Both reachable — the verb is part of the match, not just the path." },
          { "sql" => "get '/u/:id' then get '/u/:slug'", "risk" => true,
            "why" => "The second never runs. Identical shape, so the first " \
                     "always wins; the parameter name does not affect matching." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A developer adds `get '/*anything', to: 'pages#show'` to " \
                       "serve CMS pages, near the top of routes.rb. Deploy goes " \
                       "out. Within minutes, every API endpoint returns the CMS " \
                       "404 page with status 200.",
        "question" => "What happened, and why did the tests not catch it?",
        "answer" => "The wildcard matched before every other route, so nothing " \
                    "below it was reachable. Request specs that name a controller " \
                    "directly can still pass, because they bypass route " \
                    "matching order; only specs that exercise real paths catch " \
                    "it. `rails routes` would have shown the wildcard above " \
                    "everything else." } ],
    [ :revision, "Recall",
      { "prompt" => "Name the three sources that merge into `params`, and say " \
                    "which wins on a key collision.",
        "answer" => "Route segments, query string, request body. Later sources " \
                    "overwrite earlier ones, which is why permitting explicitly " \
                    "matters more than knowing the shape." } ]
  ]
)

challenge!(
  slug: "rails-route-matcher", title: "Match a path to a route",
  topic: m2, skill_slug: "rails-routing", type: :implement,
  difficulty: :medium, xp: 45,
  prompt: "Implement `match_route(routes, path)`.\n\n" \
          "`routes` is an array of pattern Strings in declaration order, where a " \
          "segment beginning with `:` is dynamic — `'/skills/:id'`. `path` is a " \
          "request path.\n\n" \
          "Return `[pattern, params_hash]` for the **first** matching route, " \
          "where the hash maps each dynamic segment name (without the colon, as " \
          "a String) to the matched segment. Return `nil` if nothing matches.\n\n" \
          "A route only matches a path with the same number of segments.",
  starter: "def match_route(routes, path)\n  # Your code here\nend\n",
  solution: "def match_route(routes, path)\n" \
            "  segments = path.split('/').reject(&:empty?)\n\n" \
            "  routes.each do |pattern|\n" \
            "    parts = pattern.split('/').reject(&:empty?)\n" \
            "    next unless parts.size == segments.size\n\n" \
            "    params = {}\n" \
            "    matched = parts.zip(segments).all? do |part, segment|\n" \
            "      if part.start_with?(':')\n" \
            "        params[part[1..]] = segment\n" \
            "        true\n" \
            "      else\n" \
            "        part == segment\n" \
            "      end\n" \
            "    end\n\n" \
            "    return [ pattern, params ] if matched\n" \
            "  end\n\n" \
            "  nil\n" \
            "end\n",
  explanation: "First match wins, and a dynamic segment matches any single " \
               "segment — including one that looks like a static route you " \
               "declared later. That is the whole reason `/skills/new` must be " \
               "declared above `/skills/:id`.",
  tests: [
    [ "matches a static route",
      "match_route(['/about'], '/about')", '["/about", {}]' ],
    [ "captures a dynamic segment",
      "match_route(['/skills/:id'], '/skills/sql-joins')",
      '["/skills/:id", {"id" => "sql-joins"}]' ],
    [ "returns nil when nothing matches",
      "match_route(['/about'], '/contact')", "nil" ],
    [ "requires the same number of segments",
      "match_route(['/skills/:id'], '/skills')", "nil" ],
    [ "first declaration wins, even over a later static route",
      "match_route(['/skills/:id', '/skills/new'], '/skills/new')",
      '["/skills/:id", {"id" => "new"}]' ],
    [ "a static route declared first is reachable",
      "match_route(['/skills/new', '/skills/:id'], '/skills/new')",
      '["/skills/new", {}]' ],
    [ "captures two dynamic segments",
      "match_route(['/worlds/:world_id/skills/:id'], '/worlds/a/skills/b')",
      '["/worlds/:world_id/skills/:id", {"world_id" => "a", "id" => "b"}]' ],
    [ "handles the root path",
      "match_route(['/'], '/')", '["/", {}]', true ]
  ],
  hints: [
    [ :nudge, "Split both the pattern and the path on `/` and drop the empty " \
              "strings. Then compare segment by segment.", 3 ],
    [ :concept, "A segment starting with `:` matches anything and records its " \
                "value. A segment without one must be equal. Check the lengths " \
                "match before comparing at all.", 4 ],
    [ :solution, "Iterate `routes` in order, `zip` the parts against the " \
                 "segments, and `return` on the first route where every pair " \
                 "matches.", 8 ]
  ]
)

challenge!(
  slug: "rails-debug-params-merge", title: "The query string won",
  topic: m2, skill_slug: "rails-routing", type: :debug,
  difficulty: :medium, xp: 55,
  prompt: "`build_params(route_params, query_params, body_params)` should merge " \
          "the three sources the way Rails does: **route segments first, then " \
          "query string, then body**, with later sources overwriting earlier " \
          "ones on a collision.\n\n" \
          "A request for `/skills/sql-joins?id=evil` is returning " \
          "`id = 'sql-joins'` when it should return `'evil'`. Fix the merge " \
          "order.\n\n" \
          "All keys are Strings.",
  starter: "def build_params(route_params, query_params, body_params)\n" \
           "  body_params.merge(query_params).merge(route_params)\n" \
           "end\n",
  solution: "def build_params(route_params, query_params, body_params)\n" \
            "  route_params.merge(query_params).merge(body_params)\n" \
            "end\n",
  explanation: "`a.merge(b)` lets **b** win. The starter merged in reverse, so " \
               "route segments overwrote everything. Getting this backwards in " \
               "real code is how a request smuggles a value into a key you " \
               "believed was controlled by the route — and why permitting " \
               "explicitly, rather than reasoning about precedence, is the " \
               "actual defence.",
  tests: [
    [ "query string beats a route segment",
      "build_params({'id' => 'sql-joins'}, {'id' => 'evil'}, {})", '{"id" => "evil"}' ],
    [ "body beats the query string",
      "build_params({}, {'name' => 'from-query'}, {'name' => 'from-body'})",
      '{"name" => "from-body"}' ],
    [ "body beats a route segment",
      "build_params({'id' => '1'}, {}, {'id' => '2'})", '{"id" => "2"}' ],
    [ "non-colliding keys all survive",
      "build_params({'id' => '1'}, {'page' => '2'}, {'name' => 'x'})",
      '{"id" => "1", "page" => "2", "name" => "x"}' ],
    [ "empty sources produce an empty hash",
      "build_params({}, {}, {})", "{}" ],
    [ "does not mutate the route params it was given",
      "(r = {'id' => '1'}; build_params(r, {'id' => '2'}, {}); r)", '{"id" => "1"}', true ]
  ],
  hints: [
    [ :nudge, "Which argument of `a.merge(b)` wins when both have the same key?", 3 ],
    [ :concept, "`b` wins. So the source that should win must be the *last* " \
                "thing merged in, not the first.", 4 ],
    [ :solution, "`route_params.merge(query_params).merge(body_params)`", 8 ]
  ]
)

question!(
  body: "A request for /skills/new is running the show action with " \
        "params[:id] set to \"new\". Why, and how do you fix it?",
  skill_slug: "rails-routing", type: "debugging", band: :junior,
  difficulty: :easy, topic: m2, interview_type: "technical",
  model: "Routes match in declaration order and the first match wins. " \
         "`get '/skills/:id'` is declared above `get '/skills/new'`, and `:id` " \
         "captures any single segment including the literal 'new', so the " \
         "second route is unreachable. The fix is to declare the static route " \
         "first. `resources :skills` already emits them in the correct order, " \
         "which is one reason to prefer it over hand-written routes.",
  explanation: "This checks whether a candidate knows routing is ordered rather " \
               "than a lookup table, and whether they would reach for " \
               "`rails routes` to see the real order.",
  mistakes: "Claiming Rails picks the 'most specific' route; adding a constraint " \
            "to work around the ordering instead of fixing the order.",
  related: %w[routing params resources],
  follow_ups: [
    { body: "How would you confirm the order rather than guess it?",
      trigger: "always",
      expects: %w[rails routes bin/rails],
      model: "`rails routes`, optionally with `-g skills`, prints them in " \
             "match order." },
    { body: "Would a constraint on :id be a reasonable fix?",
      trigger: "always",
      expects: %w[order ordering specific],
      model: "It would work — `constraints: { id: /\\d+/ }` stops it capturing " \
             "'new' — but it treats the symptom. The ordering is the real " \
             "problem, and a constraint adds a rule someone has to maintain." },
    { body: "Why did the test suite not catch this?",
      trigger: "missing_keyword", keywords: %w[test spec],
      expects: %w[controller spec path route],
      model: "A controller spec invokes the action directly and never consults " \
             "the routing table, so it passes. Only a request spec hitting the " \
             "real path exercises matching order." }
  ]
)

# =========================================================== 3. Controllers
m3 = mission!(
  curriculum_module: foundations, slug: "rails-controller-callbacks", position: 3,
  name: "Callbacks, halting and strong parameters", skill_slug: "rails-controllers",
  minutes: 12, xp: 30, difficulty: :medium, technology: v81,
  hook: "A `before_action` that forgets to halt does not fail — it lets the " \
        "action run anyway. The request looks authenticated because the " \
        "redirect was queued, and the action has already read the record.",
  summary: "Callback order, what actually halts a chain, and why permit exists.",
  blocks: [
    [ :prose, "A callback halts by rendering or redirecting",
      { "body" => "`before_action` callbacks run in the order they are declared. " \
                  "The chain stops only if a callback **renders or redirects** — " \
                  "returning `false` does nothing, and `return` only exits that " \
                  "one callback.\n\n" \
                  "Inherited callbacks run before the subclass's own, which is " \
                  "why `ApplicationController`'s authentication runs first " \
                  "without any controller mentioning it." } ],
    [ :visual, "Order of execution",
      { "kind" => "growth_table",
        "sizes" => [ "step", "where it is declared" ],
        "rows" => [
          { "label" => "1. require_authentication", "values" => [ "ApplicationController" ] },
          { "label" => "2. set_topic", "values" => [ "TopicsController" ] },
          { "label" => "3. gate_topic", "values" => [ "TopicsController, after set_topic" ] },
          { "label" => "4. the action", "values" => [ "only if nothing halted" ] },
          { "label" => "5. after_action", "values" => [ "reverse declaration order" ] }
        ],
        "caption" => "`gate_topic` depends on `set_topic` having run, so " \
                     "declaration order is a real dependency, not style. This " \
                     "is the actual callback chain in this application's " \
                     "TopicsController." } ],
    [ :prediction, "Does the action run?",
      { "question" => "class PostsController < ApplicationController\n" \
                      "  before_action :check\n\n" \
                      "  def show\n    @ran = true\n  end\n\n" \
                      "  private\n\n" \
                      "  def check\n    return false unless signed_in?\n  end\n" \
                      "end\n\n" \
                      "A signed-out user requests show. What happens?",
        "options" => [ "The chain halts and show never runs",
                       "show runs, because returning false does not halt",
                       "A double-render error is raised",
                       "The user is redirected to sign in" ],
        "answer" => 1,
        "explanation" => "Returning `false` has not halted a callback chain since " \
                         "Rails 5. The callback simply returns and the action " \
                         "runs. You must `render` or `redirect_to` — and if you " \
                         "forget, nothing warns you, because a callback that " \
                         "does nothing is a legal callback." } ],
    [ :interactive, "Which of these actually halts?",
      { "kind" => "risk_spotter",
        "prompt" => "Decide whether the action still runs after this callback.",
        "cases" => [
          { "sql" => "return false unless signed_in?", "risk" => true,
            "why" => "Action still runs. `false` has not halted since Rails 5." },
          { "sql" => "redirect_to login_path unless signed_in?", "risk" => false,
            "why" => "Halts — a redirect ends the chain." },
          { "sql" => "head :forbidden unless allowed?", "risk" => false,
            "why" => "Halts — `head` is a render." },
          { "sql" => "raise ActiveRecord::RecordNotFound unless @post", "risk" => false,
            "why" => "Halts, via an exception rescued into a 404 by middleware." },
          { "sql" => "throw(:abort) unless signed_in?", "risk" => false,
            "why" => "Halts — but it sends no response, so the client gets a " \
                     "blank 204. Correct mechanically, wrong for a user." },
          { "sql" => "flash[:alert] = 'Denied' unless signed_in?", "risk" => true,
            "why" => "Action still runs. Setting a flash is not a response." }
        ] } ],
    [ :code_demo, "What permit actually does",
      { "code" => "# params from a crafted request:\n" \
                  "# { \"user\" => { \"name\" => \"Ada\", \"role\" => \"admin\" } }\n\n" \
                  "params.require(:user).permit(:name)\n" \
                  "# => { \"name\" => \"Ada\" }    role is dropped, not an error\n\n" \
                  "params.require(:user).permit!\n" \
                  "# => everything, including role. Never do this with user input.\n\n" \
                  "# Nested: you must say the shape\n" \
                  "params.require(:user).permit(:name, address: [ :city ])",
        "language" => "ruby",
        "annotations" => [
          { "line" => 4, "note" => "Unpermitted keys are dropped silently by default." },
          { "line" => 7, "note" => "`permit!` is how a mass-assignment vulnerability is written." },
          { "line" => 11, "note" => "A nested hash needs its keys declared, or it is dropped entirely." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A signup form posts `user[name]` and `user[email]`. An " \
                       "attacker adds `user[role]=admin` to the request body. " \
                       "The controller calls `User.create!(params[:user])`.",
        "question" => "What happens, and what would have stopped it?",
        "answer" => "In a modern Rails application `params[:user]` is an " \
                    "ActionController::Parameters, and passing it unpermitted " \
                    "raises ForbiddenAttributesError — so this fails loudly " \
                    "rather than creating an admin. The vulnerability appears " \
                    "the moment someone 'fixes' the error with `permit!` or " \
                    "`to_unsafe_h`. The real defence is permitting an explicit " \
                    "list, and never making `role` assignable from a form at all." } ],
    [ :pitfall, "The quiet ones",
      { "body" => "**`return false` in a callback** — does not halt. " \
                  "**`throw(:abort)`** — halts but sends no response, so the " \
                  "user sees a blank page. **An `only:` option with a typo** — " \
                  "the callback silently never runs, and nothing checks that the " \
                  "action name exists." } ],
    [ :revision, "Recall",
      { "prompt" => "Name three things a before_action can do that halt the " \
                    "chain, and one thing that looks like it should but does not.",
        "answer" => "Halt: render, redirect_to, head, or raise. Does not halt: " \
                    "returning false — or setting a flash and nothing else." } ]
  ]
)

challenge!(
  slug: "rails-callback-chain", title: "Run the chain, and stop it",
  topic: m3, skill_slug: "rails-controllers", type: :implement,
  difficulty: :medium, xp: 45,
  prompt: "Implement `run_callbacks(callbacks, action)`.\n\n" \
          "Each callback is a lambda taking no arguments and returning either " \
          "`nil` (carry on) or a String (a response — this halts the chain). " \
          "`action` is a lambda returning a String.\n\n" \
          "Run the callbacks in order. If one returns a String, return it " \
          "immediately and do not run the rest, nor the action. If all return " \
          "`nil`, return the action's result.\n\n" \
          "Note that `false` is **not** a halt — only a String is. That is the " \
          "Rails rule, and the point of the exercise.",
  starter: "def run_callbacks(callbacks, action)\n  # Your code here\nend\n",
  solution: "def run_callbacks(callbacks, action)\n" \
            "  callbacks.each do |callback|\n" \
            "    result = callback.call\n" \
            "    return result if result.is_a?(String)\n" \
            "  end\n\n" \
            "  action.call\n" \
            "end\n",
  explanation: "Only an actual response halts the chain. Checking " \
               "`if result` would treat `false` as a halt — the mistake this " \
               "models — and checking `unless result.nil?` would halt on " \
               "`false` too. The type of the return value is the signal.",
  tests: [
    [ "with no callbacks the action runs",
      "run_callbacks([], -> { 'action' })", '"action"' ],
    [ "a nil callback does not halt",
      "run_callbacks([-> { nil }], -> { 'action' })", '"action"' ],
    [ "a String callback halts",
      "run_callbacks([-> { 'redirect' }], -> { 'action' })", '"redirect"' ],
    [ "false does not halt, which is the Rails rule",
      "run_callbacks([-> { false }], -> { 'action' })", '"action"' ],
    [ "the first halting callback wins",
      "run_callbacks([-> { 'first' }, -> { 'second' }], -> { 'action' })", '"first"' ],
    [ "callbacks after a halt do not run",
      "(ran = []; run_callbacks([-> { 'stop' }, -> { ran << 1; nil }], -> { 'action' }); ran)",
      "[]" ],
    [ "callbacks run in declaration order",
      "(order = []; run_callbacks([-> { order << :a; nil }, -> { order << :b; nil }], -> { 'x' }); order)",
      "[:a, :b]" ],
    [ "the action does not run when a later callback halts",
      "(ran = []; run_callbacks([-> { nil }, -> { 'stop' }], -> { ran << :action; 'a' }); ran)",
      "[]", true ]
  ],
  hints: [
    [ :nudge, "Loop the callbacks, call each one, and decide from what it " \
              "returned whether to stop.", 3 ],
    [ :concept, "`if result` would stop on any truthy value and let `false` " \
                "through — but it would also stop on things that are not " \
                "responses. Test the *type*.", 4 ],
    [ :solution, "`return result if result.is_a?(String)` inside the loop, then " \
                 "`action.call` after it.", 8 ]
  ]
)

challenge!(
  slug: "rails-debug-permit", title: "role came through",
  topic: m3, skill_slug: "rails-controllers", type: :debug,
  difficulty: :hard, xp: 60,
  prompt: "`permit(attrs, allowed)` should return a new Hash containing only " \
          "the keys in `allowed`.\n\n" \
          "A crafted request with `role` in it is still getting `role` through. " \
          "Find the cause and fix it.\n\n" \
          "All keys are Strings. `allowed` is an array of Strings.",
  starter: "def permit(attrs, allowed)\n" \
           "  attrs.reject { |key, _value| allowed.include?(key) }\n" \
           "end\n",
  solution: "def permit(attrs, allowed)\n" \
            "  attrs.select { |key, _value| allowed.include?(key) }\n" \
            "end\n",
  explanation: "`reject` kept exactly the keys that were *not* allowed — the " \
               "filter was inverted, so it functioned as a denylist of the " \
               "permitted keys. An allow-list must `select`. This is the shape " \
               "of a real mass-assignment bug: the code looks like it filters, " \
               "and it does, in the wrong direction.",
  tests: [
    [ "drops a key that is not allowed",
      "permit({'name' => 'Ada', 'role' => 'admin'}, ['name'])", '{"name" => "Ada"}' ],
    [ "keeps every allowed key",
      "permit({'name' => 'Ada', 'email' => 'a@b.c'}, ['name', 'email'])",
      '{"name" => "Ada", "email" => "a@b.c"}' ],
    [ "an empty allow-list permits nothing",
      "permit({'name' => 'Ada'}, [])", "{}" ],
    [ "a missing allowed key is simply absent",
      "permit({'name' => 'Ada'}, ['name', 'nickname'])", '{"name" => "Ada"}' ],
    [ "empty attributes stay empty",
      "permit({}, ['name'])", "{}" ],
    [ "does not mutate what it was given",
      "(a = {'name' => 'Ada', 'role' => 'admin'}; permit(a, ['name']); a)",
      '{"name" => "Ada", "role" => "admin"}' ],
    [ "a falsy value on an allowed key is kept",
      "permit({'active' => false}, ['active'])", '{"active" => false}', true ]
  ],
  hints: [
    [ :nudge, "Run it and compare what you got with what you wanted. The output " \
              "is the exact complement of the right answer.", 3 ],
    [ :concept, "An allow-list keeps what is listed. `reject` removes what the " \
                "block matches, so passing it the allowed keys removes exactly " \
                "the wrong half.", 4 ],
    [ :solution, "`attrs.select { |key, _value| allowed.include?(key) }`", 8 ]
  ]
)

question!(
  body: "You inherit a controller with `before_action :require_login`, and the " \
        "callback body is `return false unless current_user`. A signed-out user " \
        "can still reach the action. Explain why, and fix it.",
  skill_slug: "rails-controllers", type: "security", band: :mid,
  difficulty: :medium, topic: m3, interview_type: "technical",
  model: "Returning `false` has not halted a callback chain since Rails 5. The " \
         "callback returns, the chain continues, and the action runs — so the " \
         "controller is effectively unauthenticated while looking protected. A " \
         "callback halts only by producing a response: `redirect_to login_path` " \
         "or `head :unauthorized`. `throw(:abort)` also halts but sends no " \
         "body, so the user gets a blank response. I would use " \
         "`redirect_to login_path unless current_user` and add a request spec " \
         "asserting a signed-out request is redirected, because this class of " \
         "bug is invisible unless something actually makes the request.",
  explanation: "This is a real regression introduced by the Rails 4 to 5 " \
               "upgrade and it is worth asking because it fails open: the " \
               "mistake makes a protected controller public while the code still " \
               "reads as if it guards.",
  mistakes: "Saying `return` halts the chain; reaching for `throw(:abort)` " \
            "without knowing it sends no response; assuming a test would have " \
            "caught it when controller specs often do not.",
  related: %w[callbacks authentication security],
  follow_ups: [
    { body: "What does throw(:abort) do differently?",
      trigger: "always",
      expects: %w[halt no response blank 204],
      model: "It halts the chain but renders nothing, so the client receives an " \
             "empty 204. Mechanically correct, but a user sees a blank page." },
    { body: "How would you prove the fix works?",
      trigger: "always",
      expects: %w[request spec redirect],
      model: "A request spec that hits the real path signed out and asserts a " \
             "redirect to login — a controller spec can miss it." },
    { body: "Where else does this fail-open pattern show up?",
      trigger: "missing_keyword", keywords: %w[authorization pundit policy],
      expects: %w[authorize policy pundit],
      model: "Authorisation: calling a policy method and ignoring its result, " \
             "rather than `authorize` which raises. Anything that returns a " \
             "boolean nobody checks fails open." }
  ]
)
