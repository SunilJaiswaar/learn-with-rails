include SeedDSL
# Rails vertical slice 3: caching, security and testing (spec 13, 43, 45).
#
# Background jobs are deliberately absent: `background-jobs` already exists as
# a skill with the Sidekiq Factory lab behind it, and a Rails-flavoured copy
# would be the duplication the audit flagged. The caching mission reaches into
# it instead.
#
# Prerequisites again cross worlds — caching needs redis-caching, security
# needs web-security, testing needs testing-rspec — so the Rails content joins
# the existing graph rather than running beside it.
puts "  Rails: caching, security, testing"

v81 = version!("rails", "8.1")
rails = Technology.find_by!(slug: "rails")
citadel = World.find_by!(slug: "rails-citadel")

[
  { slug: "rails-caching", name: "Caching & Invalidation", world: citadel,
    technology: rails, tier: 6, position: 1, grid_x: 1, grid_y: 6,
    summary: "Fragment, russian-doll and HTTP caching — and the key that makes " \
             "invalidation unnecessary.",
    prerequisites: %w[active-record-associations redis-caching] },
  { slug: "rails-security", name: "Rails Security", world: citadel,
    technology: rails, tier: 5, position: 2, grid_x: 4, grid_y: 5,
    summary: "What Rails protects you from by default, and the four places it " \
             "cannot.",
    prerequisites: %w[rails-controllers web-security] },
  { slug: "rails-testing", name: "Testing Rails", world: citadel,
    technology: rails, tier: 5, position: 3, grid_x: 5, grid_y: 5,
    summary: "Which spec type catches which bug, and the ones that catch nothing.",
    prerequisites: %w[rails-controllers testing-rspec] }
].each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

production = curriculum_module!(
  world_slug: "rails-citadel", slug: "rails-production", position: 3,
  name: "Production",
  summary: "Caching, security and the tests that would have caught it."
)

# ================================================================= 1. Caching
m1 = mission!(
  curriculum_module: production, slug: "rails-cache-keys", position: 1,
  name: "The key that never needs invalidating", skill_slug: "rails-caching",
  minutes: 12, xp: 35, difficulty: :hard, technology: v81,
  hook: "Every caching bug you will ever debug is an invalidation bug. The way " \
        "out is not better invalidation — it is a key that changes when the " \
        "data changes, so the old entry is simply never asked for again.",
  summary: "Fragment and russian-doll caching, key-based expiry, and why " \
           "touch: true exists.",
  blocks: [
    [ :prose, "Expire by key, not by deletion",
      { "body" => "A cache key built from the record's `updated_at` changes the " \
                  "moment the record changes. The old entry is not deleted — " \
                  "nothing asks for it again, and it ages out on its own. " \
                  "Rails calls this **key-based expiry**, and `cache @post` " \
                  "generates exactly such a key: " \
                  "`posts/42-20260104120000/<template digest>`.\n\n" \
                  "The template digest matters as much as the timestamp. Edit " \
                  "the partial and every key changes, so a deploy cannot serve " \
                  "markup from the previous version of a template." } ],
    [ :visual, "Russian-doll nesting",
      { "kind" => "reference_diagram",
        "nodes" => [ { "label" => "cache @post", "points_to" => "outer" },
                     { "label" => "cache comment (×50)", "points_to" => "inner" } ],
        "objects" => [
          { "id" => "outer", "value" => "posts/42-<post.updated_at>/digest" },
          { "id" => "inner", "value" => "comments/99-<comment.updated_at>/digest" }
        ],
        "caption" => "Editing one comment changes one inner key. The outer " \
                     "fragment must also change, or it keeps serving the old " \
                     "HTML — which is what `touch: true` on the belongs_to is " \
                     "for: it bumps the post's updated_at when a comment is " \
                     "saved." } ],
    [ :prediction, "Does the page update?",
      { "question" => "A post's show page does `cache @post` around a list of " \
                      "comments, each wrapped in `cache comment`. " \
                      "`Comment belongs_to :post` with no `touch:` option. " \
                      "A user edits a comment. What does the next visitor see?",
        "options" => [ "The edited comment, because its own fragment changed",
                       "The old comment, because the outer fragment is still " \
                         "cached under an unchanged key",
                       "An error, because the nested keys disagree",
                       "The edited comment after the TTL expires" ],
        "answer" => 1,
        "explanation" => "The outer key is built from `post.updated_at`, which " \
                         "did not change — so Rails never looks inside and the " \
                         "inner fragment is never consulted. `belongs_to :post, " \
                         "touch: true` makes saving a comment bump the post, " \
                         "which changes the outer key. Without it, " \
                         "russian-doll caching serves stale HTML indefinitely." } ],
    [ :interactive, "Which cache layer?",
      { "kind" => "pair_matching",
        "prompt" => "Pair each situation with the caching tool that fits.",
        "left" => [ "An expensive partial rendered on many pages",
                    "A JSON response the client can revalidate",
                    "A computed value with no natural key",
                    "A whole page identical for every visitor",
                    "A list where one item changes often" ],
        "right" => [ "cache @record — fragment with key-based expiry",
                     "fresh_when / stale? — HTTP 304",
                     "Rails.cache.fetch with an explicit TTL",
                     "an HTTP cache header served by the CDN",
                     "russian-doll nesting with touch: true" ],
        "note" => "`fresh_when` is the cheapest of all of them: the response " \
                  "body is never generated and never sent. You pay for routing " \
                  "and a lookup, then return 304." } ],
    [ :scenario, "In production",
      { "situation" => "A team adds `Rails.cache.fetch` around a 3-second " \
                       "dashboard query with a 10-minute TTL. It works. Two " \
                       "weeks later the database alarms every ten minutes, in a " \
                       "pattern that lines up exactly with the expiry.",
        "question" => "What is happening, and what is the fix?",
        "answer" => "A cache stampede. At expiry every concurrent request " \
                    "misses, and all of them run the 3-second query at once. " \
                    "The fix is either `race_condition_ttl`, which lets one " \
                    "request recompute while the others serve the slightly " \
                    "stale value, or recomputing just before expiry in a " \
                    "background job so no request ever pays for it. You met " \
                    "this in **Redis & Caching** — the Rails-specific part is " \
                    "that `fetch` gives you the option as a keyword argument." } ],
    [ :pitfall, "Three caching traps",
      { "body" => "**Caching a relation, not its result** — a lazy relation " \
                  "serialises as a query, not rows, so you cache nothing " \
                  "useful. Call `to_a` first. **Caching per-user content under " \
                  "a shared key** — one user's data is then served to " \
                  "everyone, which is a data leak rather than a bug. " \
                  "**Forgetting the template digest in a manual key** — your " \
                  "handcrafted key survives a template change and serves last " \
                  "release's markup." } ],
    [ :revision, "Recall",
      { "prompt" => "Why does key-based expiry remove the need to delete cache " \
                    "entries, and what breaks it in a nested fragment?",
                    "answer" => "The key contains something that changes when " \
                    "the data does, so a changed record simply produces a " \
                    "different key and the old entry is never requested. In a " \
                    "nested fragment it breaks when the child changes without " \
                    "the parent's timestamp moving — which is what " \
                    "`touch: true` fixes." } ]
  ]
)

challenge!(
  slug: "rails-cache-key", title: "Build a key that expires itself",
  topic: m1, skill_slug: "rails-caching", type: :implement,
  difficulty: :medium, xp: 50,
  prompt: "Implement `cache_key(record, template_digest)`.\n\n" \
          "`record` is a Hash with `:model`, `:id` and `:updated_at` (an " \
          "Integer timestamp). Return the String " \
          "`\"<model>/<id>-<updated_at>/<template_digest>\"`.\n\n" \
          "If `:updated_at` is nil, use the literal `\"new\"` in its place — an " \
          "unsaved record has no timestamp to key on.\n\n" \
          "This is the shape `cache @post` generates, and the reason a changed " \
          "record is never served from a stale entry.",
  starter: "def cache_key(record, template_digest)\n  # Your code here\nend\n",
  solution: "def cache_key(record, template_digest)\n" \
            "  stamp = record[:updated_at] || 'new'\n" \
            "  \"\#{record[:model]}/\#{record[:id]}-\#{stamp}/\#{template_digest}\"\n" \
            "end\n",
  explanation: "Three parts, each earning its place: the model and id identify " \
               "the record, the timestamp makes the key change when the data " \
               "does, and the template digest makes it change when the markup " \
               "does. Drop any one and you have a cache that can serve " \
               "something wrong.",
  tests: [
    [ "builds the full key",
      "cache_key({model: 'posts', id: 42, updated_at: 1700000000}, 'abc123')",
      '"posts/42-1700000000/abc123"' ],
    [ "a different timestamp is a different key",
      "cache_key({model: 'posts', id: 42, updated_at: 1}, 'd') == cache_key({model: 'posts', id: 42, updated_at: 2}, 'd')",
      "false" ],
    [ "a different template digest is a different key",
      "cache_key({model: 'posts', id: 42, updated_at: 1}, 'a') == cache_key({model: 'posts', id: 42, updated_at: 1}, 'b')",
      "false" ],
    [ "the same record and template give the same key",
      "cache_key({model: 'posts', id: 42, updated_at: 1}, 'a') == cache_key({model: 'posts', id: 42, updated_at: 1}, 'a')",
      "true" ],
    [ "an unsaved record keys on new",
      "cache_key({model: 'posts', id: nil, updated_at: nil}, 'abc')",
      '"posts/-new/abc"' ],
    [ "two different records never collide",
      "cache_key({model: 'posts', id: 1, updated_at: 5}, 'a') == cache_key({model: 'posts', id: 2, updated_at: 5}, 'a')",
      "false", true ]
  ],
  hints: [
    [ :nudge, "It is string interpolation. The only decision is what to put " \
              "where `updated_at` would be when there is not one.", 2 ],
    [ :concept, "`record[:updated_at] || 'new'` handles the unsaved case in " \
                "one expression.", 3 ],
    [ :solution, "`\"\#{record[:model]}/\#{record[:id]}-\#{record[:updated_at] || 'new'}/\#{template_digest}\"`", 7 ]
  ]
)

challenge!(
  slug: "rails-debug-stale-nested-cache", title: "The comment that would not update",
  topic: m1, skill_slug: "rails-caching", type: :debug,
  difficulty: :hard, xp: 60,
  prompt: "`render_cached(post, comments, store)` should return the cached HTML " \
          "for a post, recomputing it whenever the post **or any of its " \
          "comments** has changed.\n\n" \
          "`store` is a Hash used as the cache. The post and each comment have " \
          "`:id` and `:updated_at`.\n\n" \
          "Editing a comment leaves the page stale. Fix the key so it changes " \
          "when a comment changes — this is what `touch: true` achieves in " \
          "Rails.\n\n" \
          "Return the String `\"post-<id>:<comment ids joined by commas>\"`.",
  starter: "def render_cached(post, comments, store)\n" \
           "  key = \"post/\#{post[:id]}-\#{post[:updated_at]}\"\n" \
           "  store[key] ||= \"post-\#{post[:id]}:\#{comments.map { |c| c[:id] }.join(',')}\"\n" \
           "end\n",
  solution: "def render_cached(post, comments, store)\n" \
            "  newest = ([ post[:updated_at] ] + comments.map { |c| c[:updated_at] }).max\n" \
            "  key = \"post/\#{post[:id]}-\#{newest}\"\n" \
            "  store[key] ||= \"post-\#{post[:id]}:\#{comments.map { |c| c[:id] }.join(',')}\"\n" \
            "end\n",
  explanation: "The key only tracked the post, so a changed comment produced the " \
               "same key and `||=` returned the old value. Keying on the newest " \
               "timestamp across the post and its comments makes any change " \
               "produce a new key. `belongs_to :post, touch: true` does the " \
               "same thing from the other direction — it moves the parent's " \
               "timestamp so the parent's key changes on its own.",
  tests: [
    [ "renders and caches",
      "render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}], {})",
      '"post-1:7"' ],
    [ "a changed comment produces fresh output",
      "(s = {}; render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}], s); render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}, {id: 8, updated_at: 99}], s))",
      '"post-1:7,8"' ],
    [ "an unchanged page is served from the cache",
      "(s = {}; render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}], s); s.size)",
      "1" ],
    [ "rendering twice unchanged adds no second entry",
      "(s = {}; 2.times { render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}], s) }; s.size)",
      "1" ],
    [ "a changed comment adds a new entry",
      "(s = {}; render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}], s); render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 50}], s); s.size)",
      "2" ],
    [ "a changed post still busts the cache",
      "(s = {}; render_cached({id: 1, updated_at: 10}, [{id: 7, updated_at: 5}], s); render_cached({id: 1, updated_at: 20}, [{id: 7, updated_at: 5}], s); s.size)",
      "2" ],
    [ "works with no comments at all",
      "render_cached({id: 1, updated_at: 10}, [], {})", '"post-1:"', true ]
  ],
  hints: [
    [ :nudge, "Render, then change a comment's updated_at and render again. The " \
              "key is identical both times.", 3 ],
    [ :concept, "The key must depend on everything the output depends on. The " \
                "output includes the comments; the key does not.", 5 ],
    [ :solution, "Take the `max` of the post's timestamp and all the comments' " \
                 "timestamps, and key on that.", 10 ]
  ]
)

question!(
  body: "A post page uses russian-doll caching. Editing a comment does not " \
        "change the page. Why, and what are your options?",
  skill_slug: "rails-caching", type: "debugging", band: :mid,
  difficulty: :medium, topic: m1, interview_type: "technical",
  model: "The outer fragment is keyed on the post's updated_at, which a comment " \
         "edit does not change — so Rails finds the outer entry, serves it, and " \
         "never looks at the inner fragments at all. The usual fix is " \
         "`belongs_to :post, touch: true` so saving a comment bumps the post's " \
         "timestamp and the outer key changes. The alternatives are keying the " \
         "outer fragment on the maximum updated_at across the collection, or " \
         "not nesting and caching each comment independently. `touch: true` has " \
         "a cost worth naming: every comment write now also writes the post " \
         "row, which on a hot post is extra contention.",
  explanation: "This separates people who have used fragment caching from " \
               "people who have debugged it. The giveaway is knowing Rails " \
               "never descends into a fragment it found in the cache.",
  mistakes: "Blaming the TTL, when key-based expiry has none; suggesting " \
            "`Rails.cache.clear`; not knowing `touch: true` exists.",
  related: %w[caching associations invalidation],
  follow_ups: [
    { body: "What does touch: true cost you?",
      trigger: "always",
      expects: %w[write contention update extra],
      model: "An extra UPDATE on the parent for every child write, plus the " \
             "row-level contention that comes with it on a popular record." },
    { body: "Why is there no TTL to blame here?",
      trigger: "always",
      expects: %w[key based expiry never deleted],
      model: "Key-based expiry does not expire anything. A changed record " \
             "produces a different key and the old entry is simply never " \
             "requested again." },
    { body: "You mentioned the template digest. What does it protect against?",
      trigger: "keyword", keywords: %w[digest template],
      expects: %w[deploy markup template change],
      model: "Serving markup from a previous version of a template after a " \
             "deploy. The digest changes when the template does, so every key " \
             "changes with it." },
    { body: "How would you prove the fix rather than eyeball it?",
      trigger: "missing_keyword", keywords: %w[test spec],
      expects: %w[test spec key assert],
      model: "Assert that the cache key changes when a comment is touched — a " \
             "test on the key itself, not on the rendered page, since the page " \
             "looks right the first time either way." }
  ]
)

# ================================================================ 2. Security
m2 = mission!(
  curriculum_module: production, slug: "rails-security-defaults", position: 2,
  name: "What Rails will not protect you from", skill_slug: "rails-security",
  minutes: 12, xp: 35, difficulty: :hard, technology: v81,
  hook: "Rails escapes your output, signs your cookies and checks a CSRF token " \
        "without being asked. It will not decide who is allowed to see a " \
        "record — and that is the vulnerability class that actually gets " \
        "shipped.",
  summary: "The defaults you get for free, and the four places you are on your " \
           "own.",
  blocks: [
    [ :prose, "Free by default, and the gaps",
      { "body" => "Rails gives you, with no effort: **output escaping** in " \
                  "ERB, **parameterised queries** when you pass bind values, " \
                  "**CSRF tokens** on non-GET requests, **signed and encrypted " \
                  "cookies**, and **strong parameters** refusing unpermitted " \
                  "attributes.\n\n" \
                  "What it does not give you: **authorisation** — whether this " \
                  "user may see this record; **safe identifiers** — a column " \
                  "name cannot be bound, so `ORDER BY \#{params[:sort]}` is " \
                  "still injectable; **`html_safe` discipline** — calling it " \
                  "turns escaping off; and **safe redirects** — " \
                  "`redirect_to params[:next]` will happily send a user " \
                  "off-site." } ],
    [ :visual, "Where each defence lives",
      { "kind" => "growth_table",
        "sizes" => [ "attack", "what stops it", "who is responsible" ],
        "rows" => [
          { "label" => "XSS", "values" => [ "ERB escaping", "Rails — until you call html_safe" ] },
          { "label" => "SQL injection (values)", "values" => [ "bind parameters", "Rails — if you pass them" ] },
          { "label" => "SQL injection (identifiers)", "values" => [ "an allow-list", "you" ] },
          { "label" => "CSRF", "values" => [ "authenticity token", "Rails" ] },
          { "label" => "Mass assignment", "values" => [ "strong parameters", "Rails — until permit!" ] },
          { "label" => "IDOR", "values" => [ "scoped lookup", "you" ] },
          { "label" => "Open redirect", "values" => [ "an allow-list", "you" ] }
        ],
        "caption" => "Every row where the answer is \"you\" is a row where the " \
                     "code looks correct and is not." } ],
    [ :prediction, "Which of these is exploitable?",
      { "question" => "def show\n" \
                      "  @invoice = Invoice.find(params[:id])\n" \
                      "  redirect_to root_path and return unless @invoice.user == current_user\n" \
                      "end\n\n" \
                      "Is this safe?",
        "options" => [ "Yes — it checks ownership before rendering",
                       "No — it loads another user's record before deciding, so " \
                         "any side effect or timing difference leaks",
                       "No — find is injectable",
                       "Yes, but only with strong parameters" ],
        "answer" => 1,
        "explanation" => "The check is in the right place but the lookup is not. " \
                         "The record is loaded first, so anything that touches " \
                         "it before the check — logging, an audit callback, a " \
                         "`before_action` ordering change later — leaks. " \
                         "`current_user.invoices.find(params[:id])` cannot load " \
                         "the wrong record at all: an unauthorised id simply " \
                         "does not exist, and you get a 404 rather than a " \
                         "decision." } ],
    [ :interactive, "Safe or not?",
      { "kind" => "risk_spotter",
        "prompt" => "Decide whether each line is a vulnerability.",
        "cases" => [
          { "sql" => "User.where(\"name = ?\", params[:q])", "risk" => false,
            "why" => "Safe — the value is bound." },
          { "sql" => "User.where(\"name = '\#{params[:q]}'\")", "risk" => true,
            "why" => "Injectable — string interpolation into SQL." },
          { "sql" => "User.order(params[:sort])", "risk" => true,
            "why" => "Injectable. A column name is an identifier and cannot be " \
                     "bound; map it through an allow-list." },
          { "sql" => "<%= @post.title %>", "risk" => false,
            "why" => "Safe — ERB escapes it." },
          { "sql" => "<%= @post.body.html_safe %>", "risk" => true,
            "why" => "XSS if the body contains user input. html_safe means " \
                     "\"trust me\", not \"make safe\"." },
          { "sql" => "redirect_to params[:return_to]", "risk" => true,
            "why" => "Open redirect — send users anywhere, including a " \
                     "credential-harvesting clone." },
          { "sql" => "current_user.invoices.find(params[:id])", "risk" => false,
            "why" => "Safe — scoped, so an unauthorised id is simply not found." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A security researcher reports that changing the id in " \
                       "/invoices/4812 shows another company's invoice. The " \
                       "controller does call an authorisation check — the team " \
                       "can see it in the code.",
        "question" => "How is it still exploitable?",
        "answer" => "Almost certainly the check ran on a record that had " \
                    "already been loaded and used, or a `before_action` with an " \
                    "`only:` list that no longer covers every action, or a " \
                    "policy whose return value nobody raised on. All three are " \
                    "fail-open: the code reads as a guard and permits by " \
                    "default. Scoping the lookup through the owner association " \
                    "is fail-closed instead — there is no path where the wrong " \
                    "record is in memory." } ],
    [ :pitfall, "Fail-open shapes",
      { "body" => "**A policy method whose boolean nobody checks.** **A " \
                  "`before_action ... only:` list that drifts from the actions.** " \
                  "**`rescue nil` around an authorisation call.** All three " \
                  "permit when they fail. Prefer `authorize` that raises, and " \
                  "scoped lookups that cannot find the wrong row." } ],
    [ :revision, "Recall",
      { "prompt" => "Name three attacks Rails stops by default and three it " \
                    "does not.",
        "answer" => "Stops: XSS in ERB, SQL injection of bound values, CSRF, " \
                    "mass assignment. Does not: authorisation / IDOR, injected " \
                    "identifiers such as ORDER BY, open redirects — and " \
                    "anything after you call html_safe or permit!." } ]
  ]
)

challenge!(
  slug: "rails-scoped-lookup", title: "Make the wrong record unfindable",
  topic: m2, skill_slug: "rails-security", type: :implement,
  difficulty: :medium, xp: 50,
  prompt: "Implement `scoped_find(records, owner_id, id)`.\n\n" \
          "`records` is an array of Hashes with `:id` and `:owner_id`. Return " \
          "the record with that `id` **only if** it belongs to `owner_id`, " \
          "otherwise `nil`.\n\n" \
          "The point is the order: filter by owner first, so a record belonging " \
          "to someone else is never a candidate. An unauthorised id must be " \
          "indistinguishable from an id that does not exist.",
  starter: "def scoped_find(records, owner_id, id)\n  # Your code here\nend\n",
  solution: "def scoped_find(records, owner_id, id)\n" \
            "  records.find { |r| r[:owner_id] == owner_id && r[:id] == id }\n" \
            "end\n",
  explanation: "One predicate, both conditions — so there is no moment at which " \
               "the wrong record is in hand. `current_user.invoices.find(id)` " \
               "is this same idea expressed as a scope: the WHERE clause " \
               "carries the owner, so the database never returns a row you were " \
               "not allowed to see.",
  tests: [
    [ "finds an owned record",
      "scoped_find([{id: 1, owner_id: 7}], 7, 1)", "{id: 1, owner_id: 7}" ],
    [ "refuses a record owned by someone else",
      "scoped_find([{id: 1, owner_id: 9}], 7, 1)", "nil" ],
    [ "returns nil for an id that does not exist",
      "scoped_find([{id: 1, owner_id: 7}], 7, 99)", "nil" ],
    [ "an unauthorised id is indistinguishable from a missing one",
      "scoped_find([{id: 1, owner_id: 9}], 7, 1) == scoped_find([{id: 1, owner_id: 9}], 7, 99)",
      "true" ],
    [ "picks the right record among several owners",
      "scoped_find([{id: 1, owner_id: 9}, {id: 1, owner_id: 7}], 7, 1)",
      "{id: 1, owner_id: 7}" ],
    [ "an empty collection finds nothing",
      "scoped_find([], 7, 1)", "nil" ],
    [ "owner 0 is not treated as no owner",
      "scoped_find([{id: 1, owner_id: 0}], 0, 1)", "{id: 1, owner_id: 0}", true ]
  ],
  hints: [
    [ :nudge, "One `find` with both conditions in the block. Resist looking up " \
              "by id and then checking.", 3 ],
    [ :concept, "If you find by id first, you are holding a record you may not " \
                "be allowed to hold — even if you then discard it.", 4 ],
    [ :solution, "`records.find { |r| r[:owner_id] == owner_id && r[:id] == id }`", 8 ]
  ]
)

challenge!(
  slug: "rails-debug-existence-leak", title: "404 or 403?",
  topic: m2, skill_slug: "rails-security", type: :debug,
  difficulty: :hard, xp: 65,
  prompt: "`lookup(records, owner_id, id)` should return `[:ok, record]` for a " \
          "record the owner may see, and `[:not_found, nil]` otherwise.\n\n" \
          "It currently distinguishes \"exists but is not yours\" from \"does " \
          "not exist\", which lets an attacker enumerate which ids are real. " \
          "Fix it so both cases are identical.\n\n" \
          "Records have `:id` and `:owner_id`.",
  starter: "def lookup(records, owner_id, id)\n" \
           "  record = records.find { |r| r[:id] == id }\n" \
           "  return [ :not_found, nil ] if record.nil?\n" \
           "  return [ :forbidden, nil ] if record[:owner_id] != owner_id\n" \
           "  [ :ok, record ]\n" \
           "end\n",
  solution: "def lookup(records, owner_id, id)\n" \
            "  record = records.find { |r| r[:owner_id] == owner_id && r[:id] == id }\n" \
            "  return [ :not_found, nil ] if record.nil?\n" \
            "  [ :ok, record ]\n" \
            "end\n",
  explanation: "Returning `:forbidden` confirms the record exists, which is " \
               "enough to enumerate every id in the system and learn how many " \
               "customers, invoices or users there are. Scoping the lookup by " \
               "owner collapses both cases into one: the record is simply not " \
               "found. This is why Rails applications return 404 rather than " \
               "403 for another tenant's record.",
  tests: [
    [ "an owned record is returned",
      "lookup([{id: 1, owner_id: 7}], 7, 1)", "[:ok, {id: 1, owner_id: 7}]" ],
    [ "someone else's record is not found, not forbidden",
      "lookup([{id: 1, owner_id: 9}], 7, 1)", "[:not_found, nil]" ],
    [ "a missing id is not found",
      "lookup([{id: 1, owner_id: 7}], 7, 99)", "[:not_found, nil]" ],
    [ "the two refusals are byte-identical",
      "lookup([{id: 1, owner_id: 9}], 7, 1) == lookup([], 7, 1)", "true" ],
    [ "never returns :forbidden at all",
      "[lookup([{id: 1, owner_id: 9}], 7, 1), lookup([], 7, 2)].flatten.include?(:forbidden)",
      "false" ],
    [ "still finds the owner's record among several",
      "lookup([{id: 1, owner_id: 9}, {id: 2, owner_id: 7}], 7, 2)",
      "[:ok, {id: 2, owner_id: 7}]" ],
    [ "does not leak through the record slot either",
      "lookup([{id: 1, owner_id: 9}], 7, 1).last", "nil", true ]
  ],
  hints: [
    [ :nudge, "Compare the two refusal paths. They return different things, and " \
              "that difference is the information being leaked.", 3 ],
    [ :concept, "If the lookup is scoped by owner, there is only one failure " \
                "case left — and no branch that can report the other.", 5 ],
    [ :solution, "Find with both conditions, then there is exactly one " \
                 "`:not_found` return and no `:forbidden` branch to write.", 10 ]
  ]
)

question!(
  body: "A user changes the id in /invoices/4812 and sees another company's " \
        "invoice. The controller does have an authorisation check. How is that " \
        "possible, and how would you fix it so it cannot recur?",
  skill_slug: "rails-security", type: "security", band: :mid,
  difficulty: :hard, topic: m2, interview_type: "technical",
  model: "Almost always because the check is fail-open or ran too late. Common " \
         "shapes: a policy method whose boolean nobody acts on; a " \
         "`before_action` with an `only:` list that has drifted from the " \
         "actions; the record loaded with a global `find` and only then " \
         "checked, so anything touching it before the check leaks. The durable " \
         "fix is to make the lookup fail-closed — " \
         "`current_user.invoices.find(params[:id])` — so an unauthorised id " \
         "cannot be loaded at all and the response is a 404. I would also " \
         "return 404 rather than 403 for another tenant's record, because 403 " \
         "confirms the record exists and lets an attacker enumerate ids.",
  explanation: "The most commonly shipped vulnerability class in Rails " \
               "applications, and the answer that distinguishes candidates is " \
               "fail-closed scoping rather than a better check.",
  mistakes: "Adding another check instead of changing the lookup; using " \
            "non-sequential ids and calling it fixed; returning 403 and leaking " \
            "existence.",
  related: %w[authorization idor scoping],
  follow_ups: [
    { body: "Why 404 rather than 403?",
      trigger: "always",
      expects: %w[enumerat exist leak],
      model: "403 confirms the record exists. 404 reveals nothing, so ids " \
             "cannot be enumerated." },
    { body: "Would UUIDs instead of sequential ids solve it?",
      trigger: "always",
      expects: %w[no obscurity still authoriz],
      model: "No. It makes guessing harder but the authorisation hole is still " \
             "there, and ids leak through URLs, logs and exports anyway. " \
             "Obscurity is not the control." },
    { body: "How would you find the other places with this bug?",
      trigger: "keyword", keywords: %w[scope scoping fix],
      expects: %w[audit grep policy test brakeman],
      model: "Grep for `Model.find(params` across controllers, and add a " \
             "request spec per resource asserting a 404 for another user's " \
             "record. A policy object gives the rule one home so the audit is " \
             "possible at all." },
    { body: "What would you add so a new controller cannot reintroduce it?",
      trigger: "missing_keyword", keywords: %w[default base],
      expects: %w[base controller default verify authorize],
      model: "Pundit's `after_action :verify_authorized` — or a base controller " \
             "whose lookup is scoped by default, so the insecure version is the " \
             "one you have to write deliberately." }
  ]
)

# ================================================================= 3. Testing
m3 = mission!(
  curriculum_module: production, slug: "rails-which-spec", position: 3,
  name: "Which spec would have caught it", skill_slug: "rails-testing",
  minutes: 11, xp: 35, difficulty: :medium, technology: v81,
  hook: "Three of this platform's own bugs — a dead CSS class, a missing " \
        "turbo_stream template, and a routing order error — were invisible to " \
        "a suite of 420 passing specs. Not because the specs were bad, but " \
        "because none of them was the kind that could see those bugs.",
  summary: "What each spec type can and cannot observe, and the ones that pass " \
           "for the wrong reason.",
  blocks: [
    [ :prose, "Each level is blind to something",
      { "body" => "A **model spec** sees validations, scopes and methods, and " \
                  "nothing about HTTP. A **request spec** goes through routing, " \
                  "middleware and the real controller, and sees the response " \
                  "body as a String — so it can assert that text is present and " \
                  "cannot tell you whether it was visible. A **system spec** " \
                  "drives a real browser, so it sees rendering, JavaScript and " \
                  "layout, and is an order of magnitude slower.\n\n" \
                  "A **controller spec** invokes the action directly, bypassing " \
                  "routing — which is why it cannot catch a route declared in " \
                  "the wrong order." } ],
    [ :visual, "Which spec sees which bug",
      { "kind" => "growth_table",
        "sizes" => [ "bug", "caught by" ],
        "rows" => [
          { "label" => "A validation that never fires", "values" => [ "model spec" ] },
          { "label" => "A route shadowed by an earlier one", "values" => [ "request spec only" ] },
          { "label" => "A before_action that does not halt", "values" => [ "request spec" ] },
          { "label" => "An N+1 query", "values" => [ "request spec with a query counter" ] },
          { "label" => "A CSS class that does not exist", "values" => [ "system spec only" ] },
          { "label" => "A Turbo Stream that updates nothing", "values" => [ "system spec only" ] },
          { "label" => "A 4KB session overflow", "values" => [ "request spec asserting cookie size" ] }
        ],
        "caption" => "The two \"system spec only\" rows are why a suite with no " \
                     "browser-based tests can be green while the interface is " \
                     "broken." } ],
    [ :prediction, "Will this spec fail?",
      { "question" => "A `before_action :require_login` does " \
                      "`return false unless current_user` — which does not " \
                      "halt, so the action runs for signed-out users.\n\n" \
                      "The suite has a controller spec that calls the action " \
                      "directly with no session and asserts the response is " \
                      "successful. Does it fail?",
        "options" => [ "Yes — the action should not have run",
                       "No — it asserts success, and the action did succeed, so " \
                         "the spec passes and documents the bug",
                       "Yes — the callback raises",
                       "It errors, because there is no session" ],
        "answer" => 1,
        "explanation" => "The spec passes, and worse, it now encodes the broken " \
                         "behaviour as the expectation. A test that asserts " \
                         "what the code does rather than what it should do is " \
                         "how a security bug gets a green tick. The spec that " \
                         "catches it asserts a *redirect* for a signed-out " \
                         "request." } ],
    [ :interactive, "Does this assertion test anything?",
      { "kind" => "risk_spotter",
        "prompt" => "Decide whether the assertion could ever fail.",
        "cases" => [
          { "sql" => "expect(response).to be_truthy", "risk" => true,
            "why" => "Never fails — a response object is always truthy." },
          { "sql" => "expect(user.save).to be true", "risk" => false,
            "why" => "Real — fails when validation fails." },
          { "sql" => "expect { subject }.not_to raise_error", "risk" => true,
            "why" => "Passes for almost any implementation, including one that " \
                     "does nothing." },
          { "sql" => "expect(response.body).to include('')", "risk" => true,
            "why" => "Never fails — every String includes the empty String." },
          { "sql" => "expect(Thing.count).to eq(1)", "risk" => false,
            "why" => "Real — though it is order-dependent if another example " \
                     "created a Thing." },
          { "sql" => "expect(result).to eq(result)", "risk" => true,
            "why" => "Never fails. Looks absurd written down, and appears in " \
                     "real suites via a shared helper computing both sides." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A suite of 420 specs is green. A release goes out and " \
                       "every lab page's pass/fail colour-coding is invisible, " \
                       "a Turbo Stream button does nothing, and one page 500s " \
                       "after a few clicks because the session cookie overflowed " \
                       "4KB.",
        "question" => "What did the suite not have, and what is the smallest " \
                      "addition that would have caught all three?",
        "answer" => "No browser-based tests, so nothing rendered a page and " \
                    "observed it. Request specs saw the HTML as a String, which " \
                    "is why an undefined CSS class and a non-functioning stream " \
                    "both looked fine. One system spec per interactive page " \
                    "would catch the first two; the cookie overflow needs only a " \
                    "request spec asserting `Set-Cookie` stays under 4096 " \
                    "bytes — cheap, and specific to the bug." } ],
    [ :pitfall, "Specs that pass for the wrong reason",
      { "body" => "**Asserting on a truthy object** rather than its value. " \
                  "**`not_to raise_error`** as the only assertion. " \
                  "**Order dependence** — shared state that makes a spec pass " \
                  "only after another ran; run with `--seed` to find it. " \
                  "**Mocking the thing under test** so the assertion checks " \
                  "the mock." } ],
    [ :revision, "Recall",
      { "prompt" => "Name a bug a request spec cannot see, and a bug a " \
                    "controller spec cannot see.",
        "answer" => "A request spec cannot see anything that needs rendering or " \
                    "JavaScript — a missing CSS class, a dead Turbo Stream. A " \
                    "controller spec cannot see routing, because it invokes the " \
                    "action directly and never consults the routing table." } ]
  ]
)

challenge!(
  slug: "rails-isolated-examples", title: "Make the order not matter",
  topic: m3, skill_slug: "rails-testing", type: :implement,
  difficulty: :medium, xp: 50,
  prompt: "Implement `run_examples(examples, build_state)`.\n\n" \
          "`build_state` is a lambda returning a **fresh** state Hash. Each " \
          "example is a lambda taking the state and returning `true` or `false`.\n\n" \
          "Run every example against its own freshly built state and return an " \
          "array of the results, in order.\n\n" \
          "No example may observe anything another example did. That isolation " \
          "is what makes a suite reorderable — and what `let` and database " \
          "transactions give you in RSpec.",
  starter: "def run_examples(examples, build_state)\n  # Your code here\nend\n",
  solution: "def run_examples(examples, build_state)\n" \
            "  examples.map { |example| example.call(build_state.call) }\n" \
            "end\n",
  explanation: "`build_state.call` inside the map is the whole answer: calling " \
               "it once outside and sharing the result is exactly the " \
               "order-dependence bug. RSpec's `let` is memoised per example for " \
               "the same reason, and the transaction rolled back after each " \
               "example is the database version of the same idea.",
  tests: [
    [ "runs every example",
      "run_examples([->(s) { true }, ->(s) { false }], -> { {} })", "[true, false]" ],
    [ "each example gets a fresh state",
      "run_examples([->(s) { s[:n] = 1; true }, ->(s) { s[:n].nil? }], -> { {} })",
      "[true, true]" ],
    [ "a mutating example cannot affect the next one",
      "run_examples([->(s) { s[:seen] = true; true }, ->(s) { s.empty? }], -> { {} })",
      "[true, true]" ],
    [ "the result is order-independent",
      "(a = [->(s) { s[:n] = 1; true }, ->(s) { s[:n].nil? }]; run_examples(a, -> { {} }) == run_examples(a.reverse, -> { {} }))",
      "true" ],
    [ "state starts from what build_state returns",
      "run_examples([->(s) { s[:count] == 0 }], -> { {count: 0} })", "[true]" ],
    [ "no examples gives no results",
      "run_examples([], -> { {} })", "[]" ],
    [ "build_state is called once per example",
      "(calls = 0; run_examples([->(s) { true }, ->(s) { true }], -> { calls += 1; {} }); calls)",
      "2", true ]
  ],
  hints: [
    [ :nudge, "Where you call `build_state` decides everything. Inside the " \
              "iteration, or outside it?", 3 ],
    [ :concept, "Calling it once outside gives every example the same Hash, so " \
                "one example's writes are visible to the next. That is the bug " \
                "this prevents.", 4 ],
    [ :solution, "`examples.map { |example| example.call(build_state.call) }`", 8 ]
  ]
)

challenge!(
  slug: "rails-debug-order-dependent-spec", title: "Green, then red, same code",
  topic: m3, skill_slug: "rails-testing", type: :debug,
  difficulty: :medium, xp: 55,
  prompt: "`run_suite(examples)` should return the number of examples that " \
          "passed.\n\n" \
          "Each example is a lambda taking a state Hash and returning a " \
          "boolean. The suite passes when run in one order and fails in " \
          "another, with no code change. Fix it.\n\n" \
          "Each example must start from an empty Hash.",
  starter: "def run_suite(examples)\n" \
           "  state = {}\n" \
           "  examples.count { |example| example.call(state) }\n" \
           "end\n",
  solution: "def run_suite(examples)\n" \
            "  examples.count { |example| example.call({}) }\n" \
            "end\n",
  explanation: "One Hash was shared by every example, so whether an example " \
               "passed depended on what ran before it. This is the single most " \
               "common cause of a suite that is green locally and red in CI, " \
               "where the seed differs. The fix is a fresh state per example — " \
               "the same reason RSpec rolls back a transaction after each one.",
  tests: [
    [ "counts a passing example", "run_suite([->(s) { true }])", "1" ],
    [ "does not count a failing example", "run_suite([->(s) { false }])", "0" ],
    [ "an example cannot see another's writes",
      "run_suite([->(s) { s[:x] = 1; true }, ->(s) { s.empty? }])", "2" ],
    [ "the count is the same in either order",
      "(a = [->(s) { s[:x] = 1; true }, ->(s) { s.empty? }]; run_suite(a) == run_suite(a.reverse))",
      "true" ],
    [ "every example still runs",
      "(n = 0; run_suite([->(s) { n += 1; true }, ->(s) { n += 1; false }]); n)", "2" ],
    [ "an empty suite counts nothing", "run_suite([])", "0" ],
    [ "three mutating examples all pass",
      "run_suite([->(s) { s[:a] = 1; s.size == 1 }, ->(s) { s[:b] = 1; s.size == 1 }, ->(s) { s[:c] = 1; s.size == 1 }])",
      "3", true ]
  ],
  hints: [
    [ :nudge, "Run the two examples in both orders and compare. One order " \
              "passes, the other does not.", 3 ],
    [ :concept, "`state` is built once, before the iteration, and handed to " \
                "every example. Where should it be built instead?", 4 ],
    [ :solution, "`examples.count { |example| example.call({}) }` — a fresh " \
                 "Hash per example.", 8 ]
  ]
)

question!(
  body: "Your suite is green but a release broke the interface. What kind of " \
        "test was missing, and how do you decide what to add without doubling " \
        "the suite's runtime?",
  skill_slug: "rails-testing", type: "scenario", band: :mid,
  difficulty: :medium, topic: m3, interview_type: "technical",
  model: "Something that actually renders. Request specs see the response body " \
         "as a String, so an undefined CSS class, a Turbo Stream that targets " \
         "nothing, or a layout that collapses on a phone all look fine. That " \
         "needs a browser, which means system specs — and they are an order of " \
         "magnitude slower, so I would not add one per page. I would add one " \
         "per interactive mechanism: one that proves a Turbo Stream mutates the " \
         "DOM, one that proves a form submits. For the rest I would pick " \
         "cheaper assertions aimed at the specific failure — asserting the " \
         "Set-Cookie header stays under 4KB is a request spec, not a system " \
         "spec, and catches a session overflow exactly.",
  explanation: "Tests whether a candidate reasons about what a test level can " \
               "observe, and whether they trade runtime deliberately rather " \
               "than adding tests by reflex.",
  mistakes: "Saying 'add more tests'; proposing a system spec for every page; " \
            "not knowing request specs cannot see rendering.",
  related: %w[testing system-specs request-specs],
  follow_ups: [
    { body: "Give me a bug a controller spec structurally cannot catch.",
      trigger: "always",
      expects: %w[routing route order],
      model: "A route shadowed by an earlier declaration. A controller spec " \
             "invokes the action directly and never consults the routing " \
             "table, so matching order is invisible to it." },
    { body: "How would you find an order-dependent spec?",
      trigger: "always",
      expects: %w[seed random order],
      model: "Run with a different `--seed`, or `--order random` in CI. An " \
             "order-dependent spec is green until the order changes." },
    { body: "You mentioned N+1. Which level catches that, and how?",
      trigger: "keyword", keywords: %w[n+1 query],
      expects: %w[request count query subscri],
      model: "A request spec with a query counter — subscribe to " \
             "sql.active_record and assert the count. A model spec cannot see " \
             "the controller's loading strategy." },
    { body: "What makes a spec pass for the wrong reason?",
      trigger: "missing_keyword", keywords: %w[assert],
      expects: %w[truthy raise_error mock always],
      model: "Asserting on a truthy object rather than a value, using " \
             "`not_to raise_error` as the only assertion, or mocking the thing " \
             "under test so the assertion checks the mock." }
  ]
)

# =================================================== The Rails boss battle
# Spec 116 requires a boss per technology. This one crosses all six Rails
# skills rather than testing one, which is what makes it a capstone.
BossBattle.find_or_create_by!(slug: "the-rails-release") do |b|
  b.title = "The Release"
  b.boss_name = "Friday Deploy"
  b.skill = skill!("rails-caching")
  b.world = world!("rails-citadel")
  b.difficulty = :expert
  b.xp_reward = 500
  b.scenario = "16:50 on a Friday. A release went out twenty minutes ago. " \
               "Four reports are open.\n\n" \
               "One: every API endpoint is returning the CMS 404 page with " \
               "status 200. Two: a customer can see another company's invoice " \
               "by changing the id. Three: comment edits do not appear on post " \
               "pages. Four: the dashboard alarms the database every ten " \
               "minutes, exactly on the minute.\n\n" \
               "Five stages: order them, then diagnose each, then say what " \
               "changes so a Friday release is boring."
  b.debrief = "The ordering is the senior judgement. The IDOR is a live data " \
              "breach and outranks a total outage, because an outage is " \
              "recoverable and disclosed data is not. The routing wildcard is " \
              "next because it is breaking everything and is a one-line " \
              "revert. The stale cache and the stampede are both real and " \
              "neither is urgent.\n\n" \
              "Every one of the four is a default that was not taken: an " \
              "unscoped lookup instead of a scoped one, a wildcard route above " \
              "everything instead of below it, a nested fragment without " \
              "touch:, and a fetch without race_condition_ttl. That is the " \
              "pattern worth keeping — most production incidents are a safe " \
              "default someone had to remember and did not."
  b.stages = [
    { "label" => "Order them", "kind" => "choice",
      "prompt" => "Which do you deal with first?",
      "options" => [
        "The routing wildcard — every endpoint is down",
        "The cross-tenant invoice — data is being disclosed right now",
        "The stale comment cache — customers can see it",
        "The dashboard stampede — the database is at risk"
      ],
      "answer" => "1",
      "explanation" => "A data breach is irreversible and reportable; an outage " \
                       "is neither. Fix the disclosure first, then the outage.",
      "wrong_hint" => "Rank by what cannot be undone, not by how many users " \
                      "are affected." },
    { "label" => "The 200s", "kind" => "open",
      "prompt" => "Every API endpoint returns the CMS 404 page with status 200. " \
                  "What single change caused this, and which layer decided it?",
      "keywords" => [ "wildcard", "route", "order", "first", "match", "router" ],
      "explanation" => "A catch-all route declared above the others. Routes " \
                       "match in declaration order and the first wins, so " \
                       "nothing below the wildcard is reachable — and the " \
                       "router made that decision, so no controller was " \
                       "involved. `rails routes` shows it immediately." },
    { "label" => "The invoice", "kind" => "open",
      "prompt" => "The controller does call an authorisation check, and the " \
                  "customer still sees another company's invoice. What shape of " \
                  "mistake is this, and what is the fail-closed fix?",
      "keywords" => [ "scope", "current_user", "association", "fail", "404", "find" ],
      "explanation" => "A fail-open check: either its boolean was never acted " \
                       "on, an `only:` list drifted, or the record was loaded " \
                       "globally and checked afterwards. The fail-closed fix is " \
                       "to scope the lookup — `current_user.invoices.find(id)` " \
                       "— so the wrong record cannot be loaded at all, and to " \
                       "return 404 rather than 403 so ids cannot be " \
                       "enumerated." },
    { "label" => "The cache", "kind" => "open",
      "prompt" => "Comment edits do not appear. The comment fragments are " \
                  "cached individually inside a cached post fragment. Why does " \
                  "nothing update, and what are your options?",
      "keywords" => [ "touch", "updated_at", "key", "outer", "nest", "max" ],
      "explanation" => "The outer fragment's key is built from the post's " \
                       "updated_at, which a comment edit does not change — so " \
                       "Rails serves the outer entry and never looks inside. " \
                       "Either `touch: true` on the belongs_to, or key the " \
                       "outer fragment on the maximum updated_at across the " \
                       "collection." },
    { "label" => "Make Friday boring", "kind" => "open",
      "prompt" => "All four are safe defaults somebody had to remember. What " \
                  "changes so the next release does not need anyone to remember?",
      "keywords" => [ "spec", "test", "request", "scanner", "brakeman", "ci",
                      "default", "base", "verify" ],
      "explanation" => "Make the safe path the default and let CI fail when it " \
                       "is not taken: a base controller that scopes lookups, " \
                       "`verify_authorized` so an unauthorised action fails the " \
                       "test, request specs that hit real paths so routing " \
                       "order is exercised, a static scanner in the pipeline, " \
                       "and a spec on the cache key itself rather than the " \
                       "rendered page." }
  ]
end
