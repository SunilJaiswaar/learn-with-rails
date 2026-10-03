include SeedDSL
# Phase 7: Docker, CI/CD, cloud and observability. Wires the CI/CD game and
# incident catalogue that already exist into the skill tree.
puts "  Phase 7: DevOps, deployment and observability"

mountain = World.find_or_create_by!(slug: "devops-mountain") do |w|
  w.name = "DevOps Mountain"
  w.position = 9
  w.accent_color = "#2dd4bf"
  w.icon = "⛰"
  w.tagline = "Shipping is a feature."
  w.summary = "Containers, pipelines, deployment and knowing what production is doing."
end

skills = [
  { slug: "containers", name: "Containers & Docker", world: mountain, tier: 4,
    position: 1, grid_x: 16, grid_y: 4,
    summary: "Images, layers, and why it works on your machine.",
    prerequisites: %w[concurrency] },
  { slug: "ci-cd", name: "CI/CD", world: mountain, tier: 5,
    position: 1, grid_x: 16, grid_y: 5,
    summary: "Gates worth having, and deploys you can undo.",
    prerequisites: %w[containers testing-rspec] },
  { slug: "observability", name: "Observability", world: mountain, tier: 6,
    position: 1, grid_x: 16, grid_y: 6,
    summary: "Knowing it broke before the customer tells you.",
    prerequisites: %w[ci-cd] }
]

skills.each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

cont_mod = curriculum_module!(
  world_slug: "devops-mountain", slug: "containers-module", position: 1,
  name: "Containers", summary: "The same thing everywhere, for a reason."
)
ci_mod = curriculum_module!(
  world_slug: "devops-mountain", slug: "cicd-module", position: 2,
  name: "CI/CD", summary: "Automate the gates, keep the undo."
)
obs_mod = curriculum_module!(
  world_slug: "devops-mountain", slug: "observability-module", position: 3,
  name: "Observability", summary: "Signals that tell you something."
)

# =================================================================== containers
c1 = mission!(
  curriculum_module: cont_mod, slug: "layers-and-cache", position: 1,
  name: "The Dockerfile that rebuilds everything", skill_slug: "containers",
  minutes: 7, xp: 20, difficulty: :medium,
  hook: "Changing one line of Ruby triggers a seven-minute image build that " \
        "reinstalls every gem. The Dockerfile has the right commands in the " \
        "wrong order.",
  summary: "Layers, cache invalidation, and keeping images small.",
  blocks: [
    [ :prose, "Every instruction is a cached layer",
      { "body" => "Each Dockerfile instruction produces a layer, cached by its " \
                  "inputs. When one layer's inputs change, that layer and " \
                  "**every layer after it** are rebuilt. So the order of " \
                  "instructions decides how often you pay for the slow ones." } ],
    [ :visual, "Why order matters",
      { "kind" => "join_result",
        "result" => { "columns" => [ "order", "copy app then bundle install", "copy Gemfile, bundle, then app" ],
                      "rows" => [
                        [ "Change a Ruby file", "gems reinstalled (~7 min)", "cache hit (~10 s)" ],
                        [ "Change the Gemfile", "gems reinstalled", "gems reinstalled" ],
                        [ "Change nothing", "cache hit", "cache hit" ]
                      ] },
        "caption" => "Copy the dependency manifest and install *before* copying " \
                     "the application, so a code change cannot invalidate the " \
                     "gem layer." } ],
    [ :prediction, "Which change busts the cache?",
      { "question" => "Your Dockerfile does `COPY . .` and then " \
                      "`RUN bundle install`. You change a comment in a Ruby " \
                      "file. What happens?",
        "options" => [ "Nothing rebuilds",
                       "Only the COPY layer rebuilds",
                       "The COPY and everything after it rebuilds, including bundle install",
                       "Only bundle install rebuilds" ],
        "answer" => 2,
        "explanation" => "`COPY . .` sees a changed file, so its layer is " \
                         "invalid — and every subsequent layer with it, " \
                         "including the gem install. Copying Gemfile and " \
                         "Gemfile.lock first, installing, then copying the rest " \
                         "means a code change only invalidates the final cheap " \
                         "layer." } ],
    [ :code_demo, "Order for the cache, and build in stages",
      { "code" => "# Slow: any code change reinstalls every gem\nCOPY . .\nRUN bundle install\n\n# Fast: the gem layer only rebuilds when the manifest changes\nCOPY Gemfile Gemfile.lock ./\nRUN bundle install\nCOPY . .\n\n# Multi-stage: build tools do not ship to production\nFROM ruby:3.4 AS build\nRUN apt-get install -y build-essential   # compilers, ~400MB\nCOPY Gemfile Gemfile.lock ./\nRUN bundle install\n\nFROM ruby:3.4-slim                       # a clean, small base\nCOPY --from=build /usr/local/bundle /usr/local/bundle\nCOPY . .",
        "language" => "dockerfile",
        "annotations" => [
          "The cache rule is simply: least-frequently-changed first.",
          "Multi-stage keeps compilers out of the final image — smaller to ship, " \
          "and a smaller attack surface.",
          "A smaller image also means faster rollbacks, because the pull is faster."
        ] } ],
    [ :pitfall, "The image that carries your secrets",
      { "body" => "A layer is immutable, so `COPY .env .` followed by " \
                  "`RUN rm .env` still ships the secret — it is in the earlier " \
                  "layer, readable by anyone who pulls the image. Secrets belong " \
                  "in the runtime environment or a build secret mount, never in " \
                  "a layer." } ],
    [ :interactive, "Will the cache hold?",
      { "kind" => "risk_spotter",
        "prompt" => "After each change, does the gem install layer rebuild?",
        "cases" => [
          { "sql" => "Edit app/models/user.rb, with Gemfile copied first",
            "risk" => false, "why" => "No — the manifest did not change." },
          { "sql" => "Add a gem to the Gemfile", "risk" => true,
            "why" => "Yes, correctly — the dependencies really did change." },
          { "sql" => "Edit a Ruby file, with COPY . . before bundle install",
            "risk" => true, "why" => "Yes — and this is the bug." },
          { "sql" => "Change the base image tag", "risk" => true,
            "why" => "Yes — everything after the FROM rebuilds." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A 1.8GB image takes four minutes to pull. A rollback " \
                       "during an incident therefore takes four minutes per " \
                       "node, and the incident runs long.",
        "question" => "How does image size become an availability problem?",
        "answer" => "Rollback speed is bounded by pull time, so a large image " \
                    "directly extends every incident. Multi-stage builds that " \
                    "leave compilers and build caches behind typically cut the " \
                    "image by most of its size; a slim base cuts more. Keeping " \
                    "images warm on nodes helps, but the durable fix is shipping " \
                    "less." } ],
    [ :interview, "How this is asked",
      { "question" => "Why is Dockerfile instruction order important?",
        "good_answer" => "Because each instruction is a cached layer and a change " \
                         "invalidates everything after it. Put the " \
                         "least-frequently-changing steps first — copy the " \
                         "dependency manifest and install before copying the " \
                         "application — so an ordinary code change does not " \
                         "reinstall dependencies." } ],
    [ :revision, "Recall",
      { "prompt" => "Why does `COPY . .` before `bundle install` slow every build?",
        "answer" => "Any file change invalidates that layer and every layer after " \
                    "it, including the install." } ]
  ]
)

challenge!(
  slug: "dockerfile-layer-order", title: "Order the layers for the cache",
  topic: c1, skill_slug: "containers", type: :optimize, difficulty: :medium, xp: 45,
  prompt: "`rebuilt_layers(instructions, changed_files)` reports which layers " \
          "must rebuild.\n\n" \
          "Each instruction is `{name:, inputs: [files]}`. A layer rebuilds if " \
          "any of its inputs changed, **or if any earlier layer rebuilt**. " \
          "Return the names of rebuilt layers in order.\n\n" \
          "That cascade is the whole reason order matters.",
  starter: "def rebuilt_layers(instructions, changed_files)\n  # Your code here\nend\n",
  solution: "def rebuilt_layers(instructions, changed_files)\n" \
            "  changed = changed_files.to_set\n" \
            "  dirty = false\n" \
            "  instructions.each_with_object([]) do |instruction, rebuilt|\n" \
            "    dirty ||= instruction[:inputs].any? { |f| changed.include?(f) }\n" \
            "    rebuilt << instruction[:name] if dirty\n" \
            "  end\n" \
            "end\n",
  explanation: "The `dirty ||=` latch is the cascade: once a layer rebuilds, " \
               "every later layer does too, regardless of its own inputs. That " \
               "is why putting `bundle install` after `COPY . .` makes every " \
               "code change reinstall every gem.",
  metadata: { "target_complexity" => "O(n)" },
  tests: [
    [ "rebuilds from the changed layer onward",
      "rebuilt_layers([{name: 'copy_gemfile', inputs: ['Gemfile']}, " \
      "{name: 'bundle', inputs: []}, {name: 'copy_app', inputs: ['app.rb']}], ['Gemfile'])",
      '["copy_gemfile", "bundle", "copy_app"]' ],
    [ "a late change leaves earlier layers cached",
      "rebuilt_layers([{name: 'copy_gemfile', inputs: ['Gemfile']}, " \
      "{name: 'bundle', inputs: []}, {name: 'copy_app', inputs: ['app.rb']}], ['app.rb'])",
      '["copy_app"]' ],
    [ "nothing rebuilds when nothing changed",
      "rebuilt_layers([{name: 'a', inputs: ['x']}], [])", "[]" ],
    [ "a broad copy cascades to everything",
      "rebuilt_layers([{name: 'copy_all', inputs: ['app.rb', 'Gemfile']}, " \
      "{name: 'bundle', inputs: []}], ['app.rb'])", '["copy_all", "bundle"]' ],
    [ "handles no instructions", "rebuilt_layers([], ['x'])", "[]" ],
    [ "an unrelated change rebuilds nothing",
      "rebuilt_layers([{name: 'a', inputs: ['x']}], ['y'])", "[]", true ]
  ],
  hints: [
    [ :nudge, "Once one layer is invalid, what happens to the ones after it?", 3 ],
    [ :concept, "Carry a flag that latches to true and never resets.", 4 ],
    [ :solution, "`dirty ||= instruction[:inputs].any? { |f| changed.include?(f) }`, " \
                 "collecting names while dirty.", 9 ]
  ]
)

challenge!(
  slug: "image-size-from-layers", title: "Add up what you are shipping",
  topic: c1, skill_slug: "containers", type: :implement, difficulty: :easy, xp: 35,
  prompt: "Write `shipped_size(layers)` returning the total megabytes an image " \
          "carries.\n\n" \
          "Each layer is `{name:, mb:, stage:}`. Only layers whose `stage` is " \
          "`\"final\"` are shipped — `\"build\"` layers are discarded by a " \
          "multi-stage build. A `:run_rm` style deletion does not reduce the " \
          "total, so simply sum the final-stage layers.",
  starter: "def shipped_size(layers)\n  # Your code here\nend\n",
  solution: "def shipped_size(layers)\n" \
            "  layers.select { |l| l[:stage] == \"final\" }.sum { |l| l[:mb] }\n" \
            "end\n",
  explanation: "This is the arithmetic that makes multi-stage builds worth it: " \
               "a 400MB compiler toolchain in a build stage costs nothing in the " \
               "shipped image, while the same layer in the final stage is paid " \
               "for on every pull — and therefore on every rollback.",
  tests: [
    [ "sums only the final stage",
      "shipped_size([{name: 'compilers', mb: 400, stage: 'build'}, " \
      "{name: 'app', mb: 50, stage: 'final'}])", "50" ],
    [ "sums several final layers",
      "shipped_size([{name: 'base', mb: 80, stage: 'final'}, " \
      "{name: 'app', mb: 20, stage: 'final'}])", "100" ],
    [ "returns zero when everything is a build stage",
      "shipped_size([{name: 'c', mb: 400, stage: 'build'}])", "0" ],
    [ "returns zero for no layers", "shipped_size([])", "0" ],
    [ "ignores stage names it does not know",
      "shipped_size([{name: 'x', mb: 10, stage: 'test'}])", "0", true ]
  ],
  hints: [
    [ :nudge, "Which layers actually end up in the image you pull?", 2 ],
    [ :solution, "Select the layers whose stage is \"final\", then sum their mb.", 5 ]
  ]
)

challenge!(
  slug: "debug-secret-in-layer", title: "The secret still in the image",
  topic: c1, skill_slug: "containers", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`image_secrets(instructions)` should list secret files that remain " \
          "readable in a built image.\n\n" \
          "Each instruction is `{op: :copy|:run_rm, file:}`. The current " \
          "version treats a later `run_rm` as removing the secret — but layers " \
          "are immutable, so a file copied in an earlier layer is still in the " \
          "image even after a later layer deletes it.\n\n" \
          "Return every copied secret, sorted, regardless of deletion.",
  starter: "def image_secrets(instructions)\n" \
           "  present = []\n" \
           "  instructions.each do |i|\n" \
           "    present << i[:file] if i[:op] == :copy\n" \
           "    present.delete(i[:file]) if i[:op] == :run_rm\n" \
           "  end\n" \
           "  present.sort\n" \
           "end\n",
  solution: "def image_secrets(instructions)\n" \
            "  instructions.select { |i| i[:op] == :copy }\n" \
            "              .map { |i| i[:file] }\n" \
            "              .uniq\n" \
            "              .sort\n" \
            "end\n",
  explanation: "`RUN rm` adds a layer recording a deletion; it cannot remove " \
               "data from an earlier layer, which anyone who pulls the image can " \
               "still read. This is why the only safe handling is never to copy " \
               "the secret in: use a build secret mount, or inject it at " \
               "runtime.",
  tests: [
    [ "a deleted secret is still present",
      "image_secrets([{op: :copy, file: '.env'}, {op: :run_rm, file: '.env'}])",
      '[".env"]' ],
    [ "lists a copied secret", "image_secrets([{op: :copy, file: 'key.pem'}])",
      '["key.pem"]' ],
    [ "lists several, sorted",
      "image_secrets([{op: :copy, file: 'b'}, {op: :copy, file: 'a'}])", '["a", "b"]' ],
    [ "deduplicates repeated copies",
      "image_secrets([{op: :copy, file: 'a'}, {op: :copy, file: 'a'}])", '["a"]' ],
    [ "returns empty when nothing was copied",
      "image_secrets([{op: :run_rm, file: '.env'}])", "[]" ],
    [ "handles no instructions", "image_secrets([])", "[]", true ]
  ],
  hints: [
    [ :nudge, "Can a later layer actually remove bytes from an earlier one?", 3 ],
    [ :concept, "No — layers are immutable and additive. A deletion is just " \
                "another layer.", 4 ],
    [ :solution, "Ignore `run_rm` entirely: select the copies, map the files, " \
                 "uniq and sort.", 9 ]
  ]
)

question!(
  body: "Why does Dockerfile instruction order matter, and what belongs first?",
  skill_slug: "containers", type: "optimization", band: :mid, difficulty: :medium,
  topic: c1,
  model: "Each instruction is a cached layer, and changing one invalidates it " \
         "and every layer after it. So the least-frequently-changing steps go " \
         "first: base image, system packages, then the dependency manifest and " \
         "install, and only then the application code. That way an ordinary code " \
         "change does not reinstall dependencies.",
  answer_key: { "keywords" => [ "layer", "cache", "invalidat", "order",
                                "gemfile", "manifest" ],
                "required" => [ "cache" ] },
  follow_ups: [
    { body: "You copied a .env file and then deleted it in a later RUN. Is the " \
            "secret safe?",
      trigger: "always",
      expects: [ "no", "layer", "immutable", "still", "history" ],
      model: "No. Layers are immutable, so the file is still in the earlier layer " \
             "and readable by anyone who pulls the image. Use a build secret " \
             "mount or inject it at runtime." },
    { body: "How does image size affect an incident?",
      trigger: "always",
      expects: [ "rollback", "pull", "slow", "deploy" ],
      model: "Rollback speed is bounded by pull time, so a large image extends " \
             "every incident. Multi-stage builds that leave compilers behind are " \
             "usually the biggest win." }
  ]
)

# ======================================================================= CI/CD
ci1 = mission!(
  curriculum_module: ci_mod, slug: "gates-and-rollback", position: 1,
  name: "The deploy you cannot undo", skill_slug: "ci-cd",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "The deploy went out at 16:50 on Friday. It included a migration that " \
        "dropped a column. Rolling back the code does not bring the column " \
        "back.",
  summary: "Pipeline gates worth having, and making deploys reversible.",
  blocks: [
    [ :prose, "Reversibility is a design decision",
      { "body" => "Code is trivially reversible — redeploy the previous image. " \
                  "**Schema and data are not.** A deploy is only as reversible " \
                  "as its least reversible part, which is almost always the " \
                  "migration." } ],
    [ :visual, "Gates, cheapest first",
      { "kind" => "growth_table",
        "sizes" => [ "catches", "typical cost" ],
        "rows" => [
          { "label" => "Lint", "values" => [ "style, obvious mistakes", "seconds" ] },
          { "label" => "Unit + request specs", "values" => [ "logic and wiring", "a minute" ] },
          { "label" => "Security scan", "values" => [ "injection, unsafe defaults", "seconds" ] },
          { "label" => "Dependency audit", "values" => [ "known CVEs", "seconds" ] },
          { "label" => "Build the image", "values" => [ "packaging errors", "minutes" ] },
          { "label" => "Smoke test after deploy", "values" => [ "it actually boots", "seconds" ] }
        ],
        "caption" => "Order gates so the fastest feedback comes first. A failing " \
                     "linter should not wait behind a four-minute image build." } ],
    [ :prediction, "Which migration is safe to deploy?",
      { "question" => "Which of these can be rolled back without data loss?",
        "options" => [ "DROP COLUMN legacy_name",
                       "ADD COLUMN nickname (nullable)",
                       "RENAME COLUMN name TO full_name",
                       "Change a column type from text to integer" ],
        "answer" => 1,
        "explanation" => "Adding a nullable column is backward compatible: old " \
                         "code ignores it and a rollback simply leaves it " \
                         "unused. Dropping, renaming or retyping all destroy or " \
                         "transform data, so the previous code cannot run " \
                         "against the new schema. Those need the expand/contract " \
                         "approach across several deploys." } ],
    [ :code_demo, "Expand and contract",
      { "code" => "# Renaming a column safely takes three deploys, not one.\n\n# Deploy 1 — expand: add the new column, write to both\nadd_column :users, :full_name, :string\n# app writes name AND full_name; reads name\n\n# Deploy 2 — migrate and switch reads\n# backfill full_name from name in a batched job\n# app reads full_name, still writes both\n\n# Deploy 3 — contract: stop writing the old column, then drop it\nremove_column :users, :name\n\n# Each deploy is independently reversible. One big rename is not.",
        "language" => "ruby",
        "annotations" => [
          "At every point, the previous version of the code still runs.",
          "Backfill in batches so a long transaction does not lock the table.",
          "The contract step can wait weeks — there is no rush to drop."
        ] } ],
    [ :pitfall, "Green CI is not a working deploy",
      { "body" => "A suite can pass while the application fails to boot in " \
                  "production: a missing environment variable, an " \
                  "unprecompiled asset, a migration that has not run. A smoke " \
                  "check against the deployed instance — hit the health " \
                  "endpoint, assert 200 — catches exactly the class of failure " \
                  "that tests cannot." } ],
    [ :interactive, "Reversible?",
      { "kind" => "risk_spotter",
        "prompt" => "Can this deploy be rolled back cleanly?",
        "cases" => [
          { "sql" => "Add a nullable column", "risk" => false,
            "why" => "Yes — old code ignores it." },
          { "sql" => "Drop a column still read by the previous version",
            "risk" => true, "why" => "No — the old code breaks, and the data is gone." },
          { "sql" => "Add a NOT NULL column with no default", "risk" => true,
            "why" => "No — the previous version's inserts fail." },
          { "sql" => "Deploy code behind a feature flag, default off",
            "risk" => false, "why" => "Yes — and you can disable it without deploying." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A Friday deploy included a column drop. An unrelated bug " \
                       "is found an hour later and the team wants to roll back.",
        "question" => "What are the options, and what should have happened?",
        "answer" => "Rolling back the code alone leaves it reading a column that " \
                    "no longer exists, so the options are to roll forward with a " \
                    "fix, or restore the column and backfill from a backup — " \
                    "slow and lossy for anything written since. What should have " \
                    "happened is expand/contract: ship the code that stops using " \
                    "the column first, let it run, and drop the column in a " \
                    "later deploy. Then every step is individually reversible." } ],
    [ :interview, "How this is asked",
      { "question" => "How do you make a deploy that includes a migration " \
                      "reversible?",
        "good_answer" => "By making the migration backward compatible, so the " \
                         "previous version of the code still works against the " \
                         "new schema. Additive changes are safe; destructive " \
                         "ones get split into expand, migrate and contract " \
                         "across separate deploys, so no single deploy is " \
                         "irreversible." } ],
    [ :revision, "Recall",
      { "prompt" => "Why is rolling back code not enough after a destructive " \
                    "migration?",
        "answer" => "The old code cannot run against the new schema, and the " \
                    "dropped data is gone." } ]
  ]
)

challenge!(
  slug: "pipeline-gate-order", title: "Fail fast, cheapest gate first",
  topic: ci1, skill_slug: "ci-cd", type: :implement, difficulty: :easy, xp: 35,
  prompt: "`run_pipeline(stages)` runs gates in order and stops at the first " \
          "failure.\n\n" \
          "Each stage is `{name:, seconds:, passes:}`. Run them from cheapest " \
          "to most expensive by `seconds` (ties broken by name), stop at the " \
          "first failure, and return " \
          "`{ran: [names], failed: name_or_nil, seconds: total}`.\n\n" \
          "Ordering by cost is the point: a failing linter should not wait " \
          "behind an image build.",
  starter: "def run_pipeline(stages)\n  # Your code here\nend\n",
  solution: "def run_pipeline(stages)\n" \
            "  ran = []\n" \
            "  seconds = 0\n" \
            "  failed = nil\n\n" \
            "  stages.sort_by { |s| [s[:seconds], s[:name]] }.each do |stage|\n" \
            "    ran << stage[:name]\n" \
            "    seconds += stage[:seconds]\n" \
            "    unless stage[:passes]\n" \
            "      failed = stage[:name]\n" \
            "      break\n" \
            "    end\n" \
            "  end\n\n" \
            "  { ran: ran, failed: failed, seconds: seconds }\n" \
            "end\n",
  explanation: "Sorting by cost then short-circuiting means the feedback you get " \
               "is as fast as the cheapest failing gate. The failing stage is " \
               "included in `ran` because it did execute — reporting it as " \
               "skipped would misrepresent what happened.",
  tests: [
    [ "runs everything when all pass",
      "run_pipeline([{name: 'lint', seconds: 5, passes: true}, " \
      "{name: 'spec', seconds: 60, passes: true}])",
      '{ran: ["lint", "spec"], failed: nil, seconds: 65}' ],
    [ "stops at the first failure",
      "run_pipeline([{name: 'lint', seconds: 5, passes: false}, " \
      "{name: 'spec', seconds: 60, passes: true}])",
      '{ran: ["lint"], failed: "lint", seconds: 5}' ],
    [ "orders cheapest first regardless of input order",
      "run_pipeline([{name: 'build', seconds: 200, passes: true}, " \
      "{name: 'lint', seconds: 5, passes: false}])",
      '{ran: ["lint"], failed: "lint", seconds: 5}' ],
    [ "breaks ties by name",
      "run_pipeline([{name: 'b', seconds: 5, passes: true}, " \
      "{name: 'a', seconds: 5, passes: true}])[:ran]", '["a", "b"]' ],
    [ "handles no stages",
      "run_pipeline([])", "{ran: [], failed: nil, seconds: 0}" ],
    [ "a late failure still accumulates earlier time",
      "run_pipeline([{name: 'lint', seconds: 5, passes: true}, " \
      "{name: 'spec', seconds: 60, passes: false}])[:seconds]", "65", true ]
  ],
  hints: [
    [ :nudge, "Sort before running, and stop as soon as something fails.", 2 ],
    [ :concept, "`sort_by { [seconds, name] }` gives the order; `break` gives the " \
                "short circuit.", 4 ],
    [ :solution, "Accumulate name and seconds per stage, break on a failure, and " \
                 "return the hash.", 8 ]
  ]
)

challenge!(
  slug: "debug-irreversible-migration", title: "Which deploys can you undo",
  topic: ci1, skill_slug: "ci-cd", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`reversible?(migration)` should report whether a migration can be " \
          "rolled back without breaking the previous code or losing data.\n\n" \
          "`{op:, nullable:, default:}` where `op` is `:add_column`, " \
          "`:drop_column`, `:rename_column` or `:change_type`.\n\n" \
          "Only adding a column is reversible — and only if it is nullable or " \
          "has a default, otherwise the previous version's inserts fail. The " \
          "current version calls every `:add_column` safe. Fix it.",
  starter: "def reversible?(migration)\n" \
           "  migration[:op] == :add_column\n" \
           "end\n",
  solution: "def reversible?(migration)\n" \
            "  return false unless migration[:op] == :add_column\n\n" \
            "  migration[:nullable] || !migration[:default].nil?\n" \
            "end\n",
  explanation: "A NOT NULL column with no default breaks the previous version's " \
               "inserts, so the deploy is not reversible even though it is " \
               "additive — the subtlety the original missed. Dropping, renaming " \
               "and retyping are never reversible in one deploy, which is what " \
               "expand/contract exists to solve.",
  tests: [
    [ "a nullable added column is reversible",
      "reversible?({op: :add_column, nullable: true, default: nil})", "true" ],
    [ "a NOT NULL column with a default is reversible",
      "reversible?({op: :add_column, nullable: false, default: 0})", "true" ],
    [ "a NOT NULL column with no default is not",
      "reversible?({op: :add_column, nullable: false, default: nil})", "false" ],
    [ "dropping a column is not reversible",
      "reversible?({op: :drop_column, nullable: true, default: nil})", "false" ],
    [ "renaming is not reversible",
      "reversible?({op: :rename_column, nullable: true, default: nil})", "false" ],
    [ "changing a type is not reversible",
      "reversible?({op: :change_type, nullable: true, default: nil})", "false" ],
    [ "a false default still counts as a default",
      "reversible?({op: :add_column, nullable: false, default: false})", "true", true ]
  ],
  hints: [
    [ :nudge, "Is every added column safe for the *previous* version of the code?", 3 ],
    [ :concept, "A NOT NULL column with no default breaks old inserts. Check for " \
                "a default with `nil?`, not truthiness.", 5 ],
    [ :solution, "Require `:add_column`, then `nullable || !default.nil?`.", 9 ]
  ]
)

question!(
  body: "A Friday deploy included a column drop and you need to roll back. What " \
        "are your options, and what should have happened?",
  skill_slug: "ci-cd", type: "scenario", band: :senior, difficulty: :hard,
  topic: ci1, company_type: "product",
  model: "Rolling back the code alone leaves it reading a column that no longer " \
         "exists, so the realistic options are to roll forward with a fix, or " \
         "restore the column and backfill from a backup — slow, and lossy for " \
         "anything written since. What should have happened is expand/contract: " \
         "deploy the code that stops using the column, let it run, then drop the " \
         "column in a later deploy, so every step is individually reversible.",
  mistakes: "Assuming a code rollback is sufficient, or running a destructive " \
            "migration in the same deploy as the code that depends on it.",
  answer_key: { "keywords" => [ "expand", "contract", "backward compatible",
                                "roll forward", "backfill", "separate deploy" ],
                "required" => [ "backward" ] },
  related: [ "expand/contract", "feature flags", "zero-downtime migrations" ],
  follow_ups: [
    { body: "Which migrations are safe to ship with the code that uses them?",
      trigger: "always",
      expects: [ "additive", "nullable", "default", "backward" ],
      model: "Additive and backward compatible ones: a nullable column, or one " \
             "with a default, that the previous version can simply ignore." },
    { body: "How do feature flags change the calculation?",
      trigger: "always",
      expects: [ "decouple", "deploy", "release", "off", "without deploying" ],
      model: "They separate deploying from releasing: the code ships dark and is " \
             "enabled later, so disabling it is a config change rather than a " \
             "deploy. It does not help with schema, though." }
  ]
)

# =============================================================== observability
o1 = mission!(
  curriculum_module: obs_mod, slug: "signals-that-matter", position: 1,
  name: "The dashboard that said everything was fine", skill_slug: "observability",
  minutes: 8, xp: 20, difficulty: :medium,
  hook: "Average response time: 180ms. Error rate: 0.2%. Both green. " \
        "Meanwhile 1 in 20 users cannot check out, and nobody knows for six " \
        "hours.",
  summary: "Why averages hide outages, and what to alert on instead.",
  blocks: [
    [ :prose, "An average is not a user",
      { "body" => "If 95% of requests take 50ms and 5% take 8 seconds, the " \
                  "average is a comfortable 450ms and nobody experiences it. " \
                  "**Percentiles** describe real users: p50 is typical, p95 and " \
                  "p99 are the ones who are suffering." } ],
    [ :visual, "The same data, two summaries",
      { "kind" => "growth_table",
        "sizes" => [ "value", "what it tells you" ],
        "rows" => [
          { "label" => "Average", "values" => [ "450ms", "nothing anyone felt" ] },
          { "label" => "p50", "values" => [ "50ms", "the typical experience" ] },
          { "label" => "p95", "values" => [ "8s", "1 in 20 users — the outage" ] },
          { "label" => "p99", "values" => [ "9s", "the worst, and the loudest" ] }
        ],
        "caption" => "The average is the only number here that describes nobody. " \
                     "Alert on p95 or p99, not the mean." } ],
    [ :prediction, "Which alert catches a partial outage?",
      { "question" => "One of eight servers is failing every request. Which " \
                      "alert fires first?",
        "options" => [ "Average latency above 500ms",
                       "Error rate above 10% on any single instance",
                       "CPU above 90%",
                       "Disk usage above 80%" ],
        "answer" => 1,
        "explanation" => "A per-instance error rate. Aggregated across eight " \
                         "servers, one failing completely shows as a 12.5% error " \
                         "rate — which may sit under a global threshold — and " \
                         "barely moves the average latency. Alerts that aggregate " \
                         "away the dimension where the fault lives cannot see it." } ],
    [ :code_demo, "Three signals worth having",
      { "code" => "# 1. A health endpoint that checks dependencies, not just the process\nget \"/up\" => proc {\n  ActiveRecord::Base.connection.select_value(\"SELECT 1\")\n  Rails.cache.read(\"health\")\n  [200, {}, [\"ok\"]]\n}\n\n# 2. Structured logs: queryable fields, not prose\nRails.logger.info(event: \"checkout_failed\", order_id: order.id,\n                  reason: \"gateway_timeout\", duration_ms: 1_240)\n\n# 3. A correlation id so one request is traceable across services\nRails.logger.info(request_id: Current.request_id, ...)",
        "language" => "ruby",
        "annotations" => [
          "A health check that only proves the process is alive will pass during " \
          "a database outage.",
          "Structured fields can be aggregated and alerted on; a prose sentence " \
          "cannot.",
          "Without a correlation id, a multi-service failure is unreconstructable."
        ] } ],
    [ :comparison, "Logs, metrics, traces",
      { "rows" => [
          { "aspect" => "Logs", "answers" => "What happened in this one request",
            "cost" => "Volume; expensive to query at scale" },
          { "aspect" => "Metrics", "answers" => "How often, how slow, trending",
            "cost" => "No per-request detail" },
          { "aspect" => "Traces", "answers" => "Where the time went across services",
            "cost" => "Instrumentation effort, sampling" }
        ],
        "columns" => { "answers" => "Answers", "cost" => "Cost" } } ],
    [ :pitfall, "Alerts nobody acts on",
      { "body" => "An alert that fires daily and is always ignored is worse than " \
                  "no alert: it trains the team to dismiss the channel, so the " \
                  "real one is missed too. Every alert should be actionable and " \
                  "rare. If it is neither, it belongs on a dashboard, not in a " \
                  "page." } ],
    [ :interactive, "Alert, dashboard or log?",
      { "kind" => "risk_spotter",
        "prompt" => "Where does each signal belong?",
        "cases" => [
          { "sql" => "Checkout error rate above 2% for 5 minutes", "risk" => false,
            "why" => "Alert — actionable, user-affecting, rare." },
          { "sql" => "CPU at 70%", "risk" => true,
            "why" => "Dashboard. Not actionable on its own, and not a symptom users feel." },
          { "sql" => "One request's full parameter dump", "risk" => true,
            "why" => "A log, and mind the PII." },
          { "sql" => "p95 latency above the SLO for 10 minutes", "risk" => false,
            "why" => "Alert — it describes real users suffering." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "Checkout has been failing for 5% of users for six hours. " \
                       "The dashboard shows average latency 180ms and error rate " \
                       "0.2%, both green. The failures were only found when a " \
                       "customer emailed.",
        "question" => "What was wrong with the monitoring?",
        "answer" => "It measured the system, not the user journey. A 0.2% global " \
                    "error rate can hide a 5% failure in one flow, because " \
                    "checkout is a small share of all requests, and the average " \
                    "latency hides it entirely. The fix is to alert on the " \
                    "business outcome — checkout success rate, per flow — and on " \
                    "p95 rather than the mean, so the signal is proportional to " \
                    "what users experience." } ],
    [ :interview, "How this is asked",
      { "question" => "Why is average latency a poor thing to alert on?",
        "good_answer" => "Because it describes nobody: a small fraction of very " \
                         "slow requests barely moves the mean while being a real " \
                         "outage for those users. Percentiles describe actual " \
                         "experience, so I would alert on p95 or p99 against an " \
                         "SLO, and on business outcomes per flow rather than " \
                         "aggregate system metrics." } ],
    [ :revision, "Recall",
      { "prompt" => "Why can a 0.2% global error rate hide a broken checkout?",
        "answer" => "Checkout is a small share of total requests, so a large " \
                    "failure in it is a small number globally." } ]
  ]
)

challenge!(
  slug: "percentile-latency", title: "Report the percentile, not the mean",
  topic: o1, skill_slug: "observability", type: :implement, difficulty: :medium, xp: 45,
  prompt: "Write `percentile(values, p)` returning the p-th percentile latency " \
          "(p between 0 and 100) using the **nearest-rank** method: sort " \
          "ascending and take the value at index `ceil(p/100 * n) - 1`, " \
          "clamped into range.\n\n" \
          "Return `nil` for an empty list. `p = 0` returns the smallest value.",
  starter: "def percentile(values, p)\n  # Your code here\nend\n",
  solution: "def percentile(values, p)\n" \
            "  return nil if values.empty?\n\n" \
            "  sorted = values.sort\n" \
            "  rank = ((p / 100.0) * sorted.length).ceil - 1\n" \
            "  sorted[rank.clamp(0, sorted.length - 1)]\n" \
            "end\n",
  explanation: "Nearest-rank is the definition most monitoring tools use, and it " \
               "always returns an observed value rather than an interpolated " \
               "one. The clamp handles both ends: `p = 0` would give index -1 " \
               "without it, which in Ruby would silently return the *largest* " \
               "value — a quietly wrong answer.",
  tests: [
    [ "p50 of ten values", "percentile((1..10).to_a, 50)", "5" ],
    [ "p95 picks the slow tail when a tenth are slow",
      "percentile([50] * 18 + [8000] * 2, 95)", "8000" ],
    [ "p95 of 20 values is the 19th, so one outlier in 20 is p100",
      "percentile([50] * 19 + [8000], 95)", "50" ],
    [ "p100 is the maximum", "percentile([1, 2, 3], 100)", "3" ],
    [ "p0 is the minimum", "percentile([5, 1, 3], 0)", "1" ],
    [ "returns nil for no values", "percentile([], 95)", "nil" ],
    [ "handles a single value", "percentile([42], 99)", "42" ],
    [ "the mean would hide what p95 reveals",
      "data = [50] * 18 + [8000] * 2; [percentile(data, 50), percentile(data, 95)]",
      "[50, 8000]", true ]
  ],
  hints: [
    [ :nudge, "Sort first. Then which index corresponds to the percentile?", 3 ],
    [ :concept, "`ceil(p/100 * n) - 1`, clamped so p=0 does not become index -1.", 5 ],
    [ :solution, "`sorted[(((p / 100.0) * sorted.length).ceil - 1).clamp(0, " \
                 "sorted.length - 1)]`", 9 ]
  ]
)

challenge!(
  slug: "debug-aggregate-hides-outage", title: "The error rate that hid a dead server",
  topic: o1, skill_slug: "observability", type: :debug, difficulty: :medium, xp: 50,
  prompt: "`unhealthy_instances(instances, threshold)` should name the " \
          "instances whose own error rate exceeds the threshold, sorted.\n\n" \
          "It computes one *global* rate across all instances, so a single " \
          "completely failing server is averaged away and nothing is reported. " \
          "Fix it to evaluate each instance separately.\n\n" \
          "Each instance is `{name:, requests:, errors:}`. Ignore instances " \
          "with no requests.",
  starter: "def unhealthy_instances(instances, threshold)\n" \
           "  total = instances.sum { |i| i[:requests] }\n" \
           "  errors = instances.sum { |i| i[:errors] }\n" \
           "  return [] if total.zero?\n" \
           "  rate = errors.to_f / total\n" \
           "  rate > threshold ? instances.map { |i| i[:name] }.sort : []\n" \
           "end\n",
  solution: "def unhealthy_instances(instances, threshold)\n" \
            "  instances.select do |instance|\n" \
            "    instance[:requests].positive? &&\n" \
            "      (instance[:errors].to_f / instance[:requests]) > threshold\n" \
            "  end.map { |i| i[:name] }.sort\n" \
            "end\n",
  explanation: "Aggregating across the dimension where the fault lives makes the " \
               "fault invisible: one dead server out of eight is a 12.5% global " \
               "rate, which may sit under the threshold, and the global view also " \
               "cannot say *which* server. Evaluating per instance both detects " \
               "it and localises it.",
  tests: [
    [ "names the single failing instance",
      "unhealthy_instances([{name: 'a', requests: 100, errors: 100}, " \
      "{name: 'b', requests: 700, errors: 0}], 0.5)", '["a"]' ],
    [ "reports nothing when all are healthy",
      "unhealthy_instances([{name: 'a', requests: 100, errors: 1}], 0.5)", "[]" ],
    [ "names several failing instances, sorted",
      "unhealthy_instances([{name: 'z', requests: 10, errors: 10}, " \
      "{name: 'a', requests: 10, errors: 10}], 0.5)", '["a", "z"]' ],
    [ "ignores instances with no traffic",
      "unhealthy_instances([{name: 'a', requests: 0, errors: 0}], 0.5)", "[]" ],
    [ "handles no instances", "unhealthy_instances([], 0.5)", "[]" ],
    [ "uses a strict comparison against the threshold",
      "unhealthy_instances([{name: 'a', requests: 10, errors: 5}], 0.5)", "[]", true ]
  ],
  hints: [
    [ :nudge, "One server failing out of eight — what does the global rate look " \
              "like?", 3 ],
    [ :concept, "Evaluate the rate per instance instead of summing first.", 4 ],
    [ :solution, "`instances.select { |i| i[:requests].positive? && " \
                 "i[:errors].to_f / i[:requests] > threshold }`", 9 ]
  ]
)

question!(
  body: "Checkout failed for 5% of users for six hours while the dashboard " \
        "showed 0.2% errors and 180ms average latency, both green. What was " \
        "wrong with the monitoring?",
  skill_slug: "observability", type: "debugging", band: :staff, difficulty: :expert,
  topic: o1, company_type: "product",
  model: "It measured the system rather than the user journey. Checkout is a " \
         "small share of total requests, so a 5% failure in that flow is a tiny " \
         "number globally, and an average latency hides a slow tail completely. " \
         "I would alert on the business outcome per flow — checkout success rate " \
         "— and on p95 or p99 against an SLO rather than the mean, so the signal " \
         "is proportional to what users actually experience.",
  explanation: "The lesson is that aggregation hides the dimension the fault " \
               "lives in.",
  mistakes: "Adding more system metrics (CPU, memory) rather than measuring the " \
            "user-visible outcome.",
  answer_key: { "keywords" => [ "percentile", "p95", "average", "aggregat",
                                "business", "flow", "slo" ],
                "required" => [ "average" ] },
  related: [ "SLOs", "percentiles", "structured logging" ],
  follow_ups: [
    { body: "Why is an average a poor alerting signal?",
      trigger: "always",
      expects: [ "tail", "hide", "nobody", "percentile" ],
      model: "It describes nobody: a small fraction of very slow requests barely " \
             "moves the mean while being a genuine outage for those users. " \
             "Percentiles describe real experience." },
    { body: "Your health check passed throughout. Why?",
      trigger: "always",
      expects: [ "dependenc", "database", "process", "shallow" ],
      model: "Probably because it only proved the process was alive. A health " \
             "check should exercise its critical dependencies, otherwise it " \
             "passes during a database outage." },
    { body: "How do you avoid alert fatigue while adding these alerts?",
      trigger: "always",
      expects: [ "actionable", "rare", "slo", "dashboard", "page" ],
      model: "Only page on things that are actionable and user-affecting; " \
             "everything else goes on a dashboard. An alert that fires daily and " \
             "is ignored trains people to dismiss the channel, which is worse " \
             "than having no alert." }
  ]
)
