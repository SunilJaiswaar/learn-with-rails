include SeedDSL
# Rails vertical slice 2: Active Record (spec 12).
#
# Deliberately does NOT re-teach the N+1. That already exists with real depth
# in the Database Dungeon — mission `the-n-plus-one` plus the
# `preload-associations` and `count-queries-n-plus-one` challenges — and
# duplicating it is exactly the mixed-content problem the audit flagged. These
# missions cross-reference it instead (spec 63).
#
# The prerequisite edges reach across worlds on purpose: you cannot reason
# about associations without joins, and you cannot reason about transactions
# without concurrency. That is the knowledge graph doing its job rather than a
# tidy per-world tree.
puts "  Rails: Active Record lifecycle, associations, transactions"

v81 = version!("rails", "8.1")
rails = Technology.find_by!(slug: "rails")
citadel = World.find_by!(slug: "rails-citadel")

[
  { slug: "active-record-lifecycle", name: "Model Lifecycle", world: citadel,
    technology: rails, tier: 4, position: 1, grid_x: 1, grid_y: 4,
    summary: "Validations, callbacks, and why save returns false instead of raising.",
    prerequisites: %w[rails-controllers sql-basics] },
  { slug: "active-record-associations", name: "Associations", world: citadel,
    technology: rails, tier: 5, position: 2, grid_x: 2, grid_y: 5,
    summary: "belongs_to, has_many, through — and what dependent: really deletes.",
    prerequisites: %w[active-record-lifecycle sql-joins] },
  { slug: "active-record-transactions", name: "Transactions & Locking", world: citadel,
    technology: rails, tier: 6, position: 3, grid_x: 3, grid_y: 6,
    summary: "Atomicity, rollback, the lost update, and which lock to reach for.",
    prerequisites: %w[active-record-associations concurrency] }
].each do |attrs|
  prerequisites = attrs.delete(:prerequisites)
  skill = Skill.find_or_create_by!(slug: attrs[:slug]) { |s| s.assign_attributes(attrs) }
  prerequisites.each do |slug|
    SkillDependency.find_or_create_by!(skill: skill, prerequisite: Skill.find_by!(slug: slug))
  end
end

persistence = curriculum_module!(
  world_slug: "rails-citadel", slug: "rails-persistence", position: 2,
  name: "Persistence",
  summary: "Getting data in and out without losing any of it."
)

# =============================================================== 1. Lifecycle
m1 = mission!(
  curriculum_module: persistence, slug: "active-record-save-path", position: 1,
  name: "save returns false", skill_slug: "active-record-lifecycle",
  minutes: 11, xp: 30, difficulty: :medium, technology: v81,
  hook: "`user.save` returning `false` is not an error — it is a value. Code " \
        "that ignores it carries on as though the record persisted, and the " \
        "bug surfaces hours later as a missing row nobody can explain.",
  summary: "The save path, validations, callback order, and the two APIs that " \
           "differ only in how they fail.",
  blocks: [
    [ :prose, "Two APIs, one difference",
      { "body" => "`save` runs validations and returns `true` or `false`. " \
                  "`save!` runs the same validations and raises " \
                  "`ActiveRecord::RecordInvalid` instead. Same for " \
                  "`create`/`create!` and `update`/`update!`.\n\n" \
                  "Neither is correct in general. Use the bang version when a " \
                  "failure is a bug — a background job, a seed, a migration — " \
                  "so it is loud. Use the plain version when a failure is " \
                  "expected input, such as a form submission, where you want to " \
                  "re-render with errors. What you must never do is call the " \
                  "plain version and ignore what it returned." } ],
    [ :visual, "The save path",
      { "kind" => "growth_table",
        "sizes" => [ "step", "can stop the save?" ],
        "rows" => [
          { "label" => "before_validation", "values" => [ "yes — throw(:abort)" ] },
          { "label" => "validations", "values" => [ "yes — any error added" ] },
          { "label" => "after_validation", "values" => [ "yes — throw(:abort)" ] },
          { "label" => "before_save", "values" => [ "yes — throw(:abort)" ] },
          { "label" => "before_create / before_update", "values" => [ "yes — throw(:abort)" ] },
          { "label" => "the INSERT or UPDATE", "values" => [ "yes — a database constraint" ] },
          { "label" => "after_create / after_update", "values" => [ "yes — raising rolls back" ] },
          { "label" => "after_save, then after_commit", "values" => [ "after_commit cannot roll back" ] }
        ],
        "caption" => "Everything from before_save to after_save runs inside a " \
                     "transaction. `after_commit` runs outside it, which is why " \
                     "that is where you enqueue a job — a job enqueued in " \
                     "after_save can run before the row is visible." } ],
    [ :prediction, "Does the row exist?",
      { "question" => "def register(email)\n" \
                      "  user = User.new(email: email)\n" \
                      "  user.save\n" \
                      "  send_welcome_email(user)\n" \
                      "  user\n" \
                      "end\n\n" \
                      "`email` is already taken and the model validates " \
                      "uniqueness. What happens?",
        "options" => [ "RecordInvalid is raised before the email is sent",
                       "No row is created, the email is sent anyway, and the " \
                         "method returns an unsaved object",
                       "The row is created without validation",
                       "save returns nil and the method crashes" ],
        "answer" => 1,
        "explanation" => "`save` returned `false` and nobody looked. The record " \
                         "is unsaved and `user.id` is `nil`, but execution " \
                         "continued — so a welcome email goes out for an account " \
                         "that does not exist. Either check the return value or " \
                         "use `save!`." } ],
    [ :interactive, "Which of these persist?",
      { "kind" => "risk_spotter",
        "prompt" => "Validation fails. Decide whether a row ends up in the table.",
        "cases" => [
          { "sql" => "user.save", "risk" => false,
            "why" => "No row. Returns false — which you must check." },
          { "sql" => "user.save!", "risk" => false,
            "why" => "No row. Raises RecordInvalid." },
          { "sql" => "user.save(validate: false)", "risk" => true,
            "why" => "Row is written. Validations skipped entirely — database " \
                     "constraints are the only thing left." },
          { "sql" => "user.update_column(:name, 'x')", "risk" => true,
            "why" => "Row is written. Skips validations *and* callbacks *and* " \
                     "touches no timestamps." },
          { "sql" => "user.update_attribute(:name, 'x')", "risk" => true,
            "why" => "Row is written. Skips validations but still runs callbacks " \
                     "— the confusing middle ground." },
          { "sql" => "User.insert_all([{ name: 'x' }])", "risk" => true,
            "why" => "Row is written. No model instantiated at all, so no " \
                     "validations, no callbacks, no timestamps." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "An importer processes 50,000 rows a night with " \
                       "`Record.create(attrs)` inside a loop and logs " \
                       "\"imported 50,000\". Finance reports that about 300 " \
                       "records are missing every night, with no errors in the " \
                       "log.",
        "question" => "What is happening, and what is the smallest fix?",
        "answer" => "`create` returns the object whether or not it saved, so " \
                    "every iteration looks successful. Roughly 300 rows fail " \
                    "validation and are silently dropped. The smallest fix is " \
                    "`create!`, which turns a silent drop into a loud failure. " \
                    "The better fix also collects the invalid rows and reports " \
                    "them, because an importer that aborts on row altogether " \
                    "299 is its own outage." } ],
    [ :pitfall, "Where after_save bites",
      { "body" => "**Enqueueing a job in `after_save`** — the job can start " \
                  "before the transaction commits and find no row. Use " \
                  "`after_commit`. **Calling `update` inside `after_save`** — " \
                  "re-enters the save path and recurses. **`update_column` to " \
                  "'avoid callbacks'** — it also skips validations and " \
                  "timestamps, so you have silently opted out of three things " \
                  "to avoid one." } ],
    [ :revision, "Recall",
      { "prompt" => "Name the four ways to write a row that skip validations, " \
                    "and say which also skip callbacks.",
        "answer" => "`save(validate: false)` and `update_attribute` skip " \
                    "validations but run callbacks. `update_column`/" \
                    "`update_columns` and `insert_all`/`upsert_all` skip both — " \
                    "and `insert_all` never builds a model at all." } ]
  ]
)

challenge!(
  slug: "ar-save-many", title: "Only the ones that saved",
  topic: m1, skill_slug: "active-record-lifecycle", type: :implement,
  difficulty: :medium, xp: 45,
  prompt: "Implement `save_all(records, validator)`.\n\n" \
          "`records` is an array of Hashes. `validator` is a lambda taking a " \
          "record and returning an array of error Strings — empty means valid.\n\n" \
          "Return a Hash with two keys: `:saved` (the valid records, in order) " \
          "and `:rejected` (an array of `[record, errors]` pairs for the " \
          "invalid ones).\n\n" \
          "This is the importer that does not lose 300 rows a night: nothing " \
          "is dropped silently, and a failure is reported rather than counted " \
          "as a success.",
  starter: "def save_all(records, validator)\n  # Your code here\nend\n",
  solution: "def save_all(records, validator)\n" \
            "  saved = []\n" \
            "  rejected = []\n\n" \
            "  records.each do |record|\n" \
            "    errors = validator.call(record)\n" \
            "    if errors.empty?\n" \
            "      saved << record\n" \
            "    else\n" \
            "      rejected << [ record, errors ]\n" \
            "    end\n" \
            "  end\n\n" \
            "  { saved: saved, rejected: rejected }\n" \
            "end\n",
  explanation: "`partition` gets you most of the way, but you also need each " \
               "rejection's reasons, so the errors have to be captured as you " \
               "go. The shape matters more than the code: an import that " \
               "reports what it dropped is debuggable, and one that returns a " \
               "count is not.",
  tests: [
    [ "keeps a valid record",
      "save_all([{n: 1}], ->(r) { [] })", "{saved: [{n: 1}], rejected: []}" ],
    [ "rejects an invalid record with its reasons",
      "save_all([{n: 1}], ->(r) { ['too small'] })",
      "{saved: [], rejected: [[{n: 1}, [\"too small\"]]]}" ],
    [ "separates a mixed batch",
      "save_all([{n: 1}, {n: 9}], ->(r) { r[:n] > 5 ? [] : ['too small'] })",
      "{saved: [{n: 9}], rejected: [[{n: 1}, [\"too small\"]]]}" ],
    [ "preserves input order among the saved",
      "save_all([{n: 9}, {n: 1}, {n: 7}], ->(r) { r[:n] > 5 ? [] : ['no'] })[:saved]",
      "[{n: 9}, {n: 7}]" ],
    [ "handles an empty batch",
      "save_all([], ->(r) { [] })", "{saved: [], rejected: []}" ],
    [ "keeps every error, not just the first",
      "save_all([{n: 1}], ->(r) { ['a', 'b'] })[:rejected].first.last", '["a", "b"]' ],
    [ "does not drop a record that is neither saved nor reported",
      "(res = save_all([{n: 1}, {n: 9}], ->(r) { r[:n] > 5 ? [] : ['no'] }); res[:saved].size + res[:rejected].size)",
      "2", true ]
  ],
  hints: [
    [ :nudge, "You need two collections and the errors for each rejection. One " \
              "pass is enough.", 3 ],
    [ :concept, "`partition` splits in two but discards the errors it computed. " \
                "Either call the validator twice or accumulate as you iterate.", 4 ],
    [ :solution, "Iterate once, call the validator, and push to `saved` or " \
                 "`rejected << [record, errors]` depending on whether the " \
                 "errors array is empty.", 8 ]
  ]
)

challenge!(
  slug: "ar-debug-ignored-save", title: "The import that lost rows",
  topic: m1, skill_slug: "active-record-lifecycle", type: :debug,
  difficulty: :medium, xp: 55,
  prompt: "`import(records, save)` should return the number of records that " \
          "were actually persisted.\n\n" \
          "`save` is a lambda taking a record and returning `true` or `false`, " \
          "exactly as `ActiveRecord#save` does.\n\n" \
          "It reports 4 for a batch where only 2 saved. Find the cause and fix " \
          "it.",
  starter: "def import(records, save)\n" \
           "  count = 0\n" \
           "  records.each do |record|\n" \
           "    save.call(record)\n" \
           "    count += 1\n" \
           "  end\n" \
           "  count\n" \
           "end\n",
  solution: "def import(records, save)\n" \
            "  count = 0\n" \
            "  records.each do |record|\n" \
            "    count += 1 if save.call(record)\n" \
            "  end\n" \
            "  count\n" \
            "end\n",
  explanation: "The return value of `save` was discarded, so every attempt " \
               "counted as a success. This is the single most common Active " \
               "Record mistake in production code: `save` does not raise, so " \
               "ignoring it is syntactically fine and silently wrong.",
  tests: [
    [ "counts a successful save", "import([1], ->(r) { true })", "1" ],
    [ "does not count a failed save", "import([1], ->(r) { false })", "0" ],
    [ "counts only what saved",
      "import([1, 2, 3, 4], ->(r) { r.even? })", "2" ],
    [ "an empty batch imports nothing", "import([], ->(r) { true })", "0" ],
    [ "still attempts every record",
      "(seen = []; import([1, 2, 3], ->(r) { seen << r; false }); seen)", "[1, 2, 3]" ],
    [ "a nil return does not count as success",
      "import([1], ->(r) { nil })", "0", true ]
  ],
  hints: [
    [ :nudge, "What does `save` give you back, and where does that value go in " \
              "the starter?", 3 ],
    [ :concept, "`save.call(record)` returns true or false and the result is " \
                "thrown away. The counter increments unconditionally.", 4 ],
    [ :solution, "`count += 1 if save.call(record)`", 8 ]
  ]
)

question!(
  body: "What is the difference between save and save!, and how do you choose?",
  skill_slug: "active-record-lifecycle", type: "scenario", band: :junior,
  difficulty: :easy, topic: m1, interview_type: "technical",
  model: "Both run validations. `save` returns true or false; `save!` raises " \
         "ActiveRecord::RecordInvalid. The choice is about whether a failure is " \
         "expected input or a bug. A form submission is expected input, so I " \
         "use `save` and re-render with errors. A background job, a migration " \
         "or a seed should be loud, so I use `save!`. The thing I will not do " \
         "is call `save` and ignore the result — that is how rows go missing " \
         "with nothing in the log.",
  explanation: "A junior question that separates people who have debugged a " \
               "silent data loss from people who have only read the guides.",
  mistakes: "Saying one is 'safer'; claiming save! skips validations; not " \
            "mentioning that ignoring the return value is the actual hazard.",
  related: %w[validations callbacks persistence],
  follow_ups: [
    { body: "Which callback would you enqueue a background job from, and why?",
      trigger: "always",
      expects: %w[after_commit commit transaction],
      model: "after_commit. A job enqueued in after_save can be picked up by a " \
             "worker before the transaction commits, and then it cannot find " \
             "the row." },
    { body: "Name a way to write a row that skips validations entirely.",
      trigger: "always",
      expects: %w[update_column insert_all save validate false update_columns],
      model: "`save(validate: false)`, `update_column`, or `insert_all` — which " \
             "skips callbacks and timestamps too, since no model is built." },
    { body: "You said you would check the return value. How would you catch a " \
            "place that does not?",
      trigger: "keyword", keywords: %w[check return value ignore],
      expects: %w[rubocop lint test constraint],
      model: "A database constraint turns the silent drop into an error " \
             "regardless, and RuboCop has cops for unchecked save. Both beat " \
             "code review for this." }
  ]
)

# ============================================================ 2. Associations
m2 = mission!(
  curriculum_module: persistence, slug: "active-record-associations", position: 2,
  name: "What dependent: actually deletes", skill_slug: "active-record-associations",
  minutes: 12, xp: 30, difficulty: :medium, technology: v81,
  hook: "`has_many :comments, dependent: :destroy` and " \
        "`dependent: :delete_all` look like the same option spelled two ways. " \
        "One runs every callback on every child; the other issues one DELETE " \
        "and runs none. Choosing wrong either times out or leaves orphans.",
  summary: "belongs_to, has_many, through, and the four dependent: options that " \
           "differ in what they run.",
  blocks: [
    [ :prose, "An association is a query, not a field",
      { "body" => "`post.comments` is a **relation**, not an array held on the " \
                  "object. It builds `SELECT * FROM comments WHERE post_id = ?` " \
                  "and runs it when something enumerates it.\n\n" \
                  "That is why `post.comments.count` issues `SELECT COUNT(*)` " \
                  "while `post.comments.size` uses the already-loaded array if " \
                  "there is one — and why calling an association inside a loop " \
                  "produces one query per iteration. You have already met that " \
                  "as the N+1 in **Query Performance**; here the concern is " \
                  "what the association *declares*." } ],
    [ :visual, "has_many :through, resolved",
      { "kind" => "join_result",
        "left" => [ "user 1 Asha", "user 2 Bruno" ],
        "right" => [ "membership(1, p10)", "membership(1, p11)", "membership(2, p10)" ],
        "rows" => [
          { "cells" => [ "Asha", "p10" ] },
          { "cells" => [ "Asha", "p11" ] },
          { "cells" => [ "Bruno", "p10" ] }
        ],
        "caption" => "`has_many :projects, through: :memberships` hides the " \
                     "join table but not the join. Asha appears twice in the " \
                     "intermediate result, which is why `through` associations " \
                     "can return duplicates unless you say `distinct`." } ],
    [ :prediction, "How many queries?",
      { "question" => "`dependent: :destroy` on a post with 10,000 comments, " \
                      "each of which has an `after_destroy` callback. You call " \
                      "`post.destroy`. Roughly how much work is that?",
        "options" => [ "Two statements: delete the comments, delete the post",
                       "10,001 DELETEs plus 10,000 callback runs",
                       "One DELETE with a subquery",
                       "It is batched into chunks of 1,000 automatically" ],
        "answer" => 1,
        "explanation" => "`:destroy` loads every child, instantiates it, runs " \
                         "its callbacks and deletes it one at a time. That is " \
                         "10,000 round trips before the post itself goes. " \
                         "`:delete_all` would be one DELETE — and would skip " \
                         "every callback, including the ones that clean up " \
                         "files or counters." } ],
    [ :interactive, "Pick the right dependent:",
      { "kind" => "pair_matching",
        "prompt" => "Pair each situation with the option that fits it.",
        "left" => [ "Children have after_destroy cleanup",
                    "Millions of rows, no callbacks",
                    "Children must never be orphaned, enforce in the database",
                    "Deleting the parent should be refused while children exist",
                    "Children should survive, pointing at nothing" ],
        "right" => [ "dependent: :destroy",
                     "dependent: :delete_all",
                     "a foreign key with on_delete: :cascade",
                     "dependent: :restrict_with_error",
                     "dependent: :nullify" ],
        "note" => "The database-level cascade is the only one that still holds " \
                  "when rows are deleted by something that is not Rails — a " \
                  "console session, a migration, another service." } ],
    [ :scenario, "In production",
      { "situation" => "A team switches `dependent: :destroy` to " \
                       "`dependent: :delete_all` to fix a timeout when deleting " \
                       "an account. The deploy fixes the timeout. Three weeks " \
                       "later, storage costs are up and a listing page starts " \
                       "throwing nil errors.",
        "question" => "What did the switch break?",
        "answer" => "`:delete_all` issues one DELETE and runs no callbacks, so " \
                    "every `after_destroy` stopped firing: attached files were " \
                    "never purged (storage cost) and counter caches were never " \
                    "decremented (nil errors on a page trusting the count). " \
                    "The timeout was real, but the fix needed batching — " \
                    "`in_batches.destroy_all` or a background job — not the " \
                    "removal of the cleanup." } ],
    [ :pitfall, "inverse_of, and why it matters",
      { "body" => "Without `inverse_of`, `post.comments.first.post` can load a " \
                  "**second copy** of the same post from the database, so " \
                  "changes to one are invisible to the other. Rails infers it " \
                  "automatically for simple associations but not when you pass " \
                  "`:foreign_key`, a scope, or `:through`. The symptom is a " \
                  "validation that passes on an object whose parent was " \
                  "already changed in memory." } ],
    [ :revision, "Recall",
      { "prompt" => "Name the four `dependent:` options and say which run child " \
                    "callbacks.",
        "answer" => "`:destroy` runs them (one query per child). `:delete_all` " \
                    "does not (one query total). `:nullify` does not (one " \
                    "UPDATE). `:restrict_with_error` deletes nothing and adds " \
                    "an error instead." } ]
  ]
)

challenge!(
  slug: "ar-through-association", title: "Resolve a has_many :through",
  topic: m2, skill_slug: "active-record-associations", type: :implement,
  difficulty: :medium, xp: 50,
  prompt: "Implement `through_association(users, memberships, projects)`.\n\n" \
          "Each is an array of Hashes. `users` have `:id` and `:name`. " \
          "`memberships` have `:user_id` and `:project_id`. `projects` have " \
          "`:id` and `:name`.\n\n" \
          "Return a Hash mapping each user's name to a sorted array of the " \
          "project names they reach through their memberships. A user with no " \
          "memberships maps to an empty array.\n\n" \
          "Duplicate memberships must not produce duplicate project names — " \
          "that is what `distinct` is for on a real `through` association.",
  starter: "def through_association(users, memberships, projects)\n  # Your code here\nend\n",
  solution: "def through_association(users, memberships, projects)\n" \
            "  project_names = projects.to_h { |p| [ p[:id], p[:name] ] }\n" \
            "  by_user = memberships.group_by { |m| m[:user_id] }\n\n" \
            "  users.to_h do |user|\n" \
            "    ids = by_user.fetch(user[:id], []).map { |m| m[:project_id] }\n" \
            "    [ user[:name], ids.uniq.map { |id| project_names[id] }.compact.sort ]\n" \
            "  end\n" \
            "end\n",
  explanation: "Two indexes and one grouping — which is exactly what Rails does " \
               "when it preloads a `through` association: one query for the " \
               "join rows, one for the targets, then stitch them in Ruby. " \
               "Noticing that it is three queries rather than one join is the " \
               "difference between `preload` and `eager_load`.",
  tests: [
    [ "resolves one hop",
      "through_association([{id: 1, name: 'Asha'}], [{user_id: 1, project_id: 10}], [{id: 10, name: 'Atlas'}])",
      '{"Asha" => ["Atlas"]}' ],
    [ "a user with no memberships gets an empty array",
      "through_association([{id: 1, name: 'Asha'}], [], [{id: 10, name: 'Atlas'}])",
      '{"Asha" => []}' ],
    [ "resolves several projects, sorted",
      "through_association([{id: 1, name: 'Asha'}], [{user_id: 1, project_id: 11}, {user_id: 1, project_id: 10}], [{id: 10, name: 'Atlas'}, {id: 11, name: 'Beacon'}])",
      '{"Asha" => ["Atlas", "Beacon"]}' ],
    [ "keeps users separate",
      "through_association([{id: 1, name: 'Asha'}, {id: 2, name: 'Bruno'}], [{user_id: 1, project_id: 10}, {user_id: 2, project_id: 11}], [{id: 10, name: 'Atlas'}, {id: 11, name: 'Beacon'}])",
      '{"Asha" => ["Atlas"], "Bruno" => ["Beacon"]}' ],
    [ "a duplicate membership does not duplicate the project",
      "through_association([{id: 1, name: 'Asha'}], [{user_id: 1, project_id: 10}, {user_id: 1, project_id: 10}], [{id: 10, name: 'Atlas'}])",
      '{"Asha" => ["Atlas"]}' ],
    [ "a membership pointing at a missing project is dropped",
      "through_association([{id: 1, name: 'Asha'}], [{user_id: 1, project_id: 99}], [{id: 10, name: 'Atlas'}])",
      '{"Asha" => []}' ],
    [ "no users gives an empty hash",
      "through_association([], [{user_id: 1, project_id: 10}], [{id: 10, name: 'Atlas'}])",
      "{}", true ]
  ],
  hints: [
    [ :nudge, "Index the projects by id first, and group the memberships by " \
              "user_id. Then every user is a lookup rather than a scan.", 3 ],
    [ :concept, "Scanning `memberships` once per user is the N+1 in miniature. " \
                "Group once, outside the loop.", 4 ],
    [ :solution, "Build `projects.to_h { |p| [p[:id], p[:name]] }` and " \
                 "`memberships.group_by { |m| m[:user_id] }`, then map each " \
                 "user through both — `uniq` before the lookup, `compact` " \
                 "after, then `sort`.", 9 ]
  ]
)

challenge!(
  slug: "ar-debug-orphaned-children", title: "The orphans nobody deleted",
  topic: m2, skill_slug: "active-record-associations", type: :debug,
  difficulty: :medium, xp: 55,
  prompt: "`destroy_parent(parents, children, parent_id)` should remove the " \
          "parent **and** every child pointing at it, returning " \
          "`[remaining_parents, remaining_children]`.\n\n" \
          "The parent goes but the children stay, pointing at an id that no " \
          "longer exists. Find the cause and fix it.\n\n" \
          "Children have a `:parent_id` key. Neither input should be mutated.",
  starter: "def destroy_parent(parents, children, parent_id)\n" \
           "  remaining_parents = parents.reject { |p| p[:id] == parent_id }\n" \
           "  [ remaining_parents, children ]\n" \
           "end\n",
  solution: "def destroy_parent(parents, children, parent_id)\n" \
            "  remaining_parents = parents.reject { |p| p[:id] == parent_id }\n" \
            "  remaining_children = children.reject { |c| c[:parent_id] == parent_id }\n" \
            "  [ remaining_parents, remaining_children ]\n" \
            "end\n",
  explanation: "The children were never filtered — this is precisely what " \
               "happens when an association has no `dependent:` option at all. " \
               "Rails does not clean up by default, and nothing complains " \
               "until something reads an orphan's parent and gets `nil`. A " \
               "foreign key constraint would have refused the delete outright, " \
               "which is why the constraint belongs in the database as well as " \
               "the model.",
  tests: [
    [ "removes the parent",
      "destroy_parent([{id: 1}, {id: 2}], [], 1).first", "[{id: 2}]" ],
    [ "removes that parent's children",
      "destroy_parent([{id: 1}], [{parent_id: 1}], 1).last", "[]" ],
    [ "leaves other parents' children alone",
      "destroy_parent([{id: 1}, {id: 2}], [{parent_id: 1}, {parent_id: 2}], 1).last",
      "[{parent_id: 2}]" ],
    [ "removes every child of the parent",
      "destroy_parent([{id: 1}], [{parent_id: 1}, {parent_id: 1}], 1).last", "[]" ],
    [ "deleting an id that does not exist changes nothing",
      "destroy_parent([{id: 1}], [{parent_id: 1}], 99)",
      "[[{id: 1}], [{parent_id: 1}]]" ],
    [ "does not mutate the children it was given",
      "(c = [{parent_id: 1}]; destroy_parent([{id: 1}], c, 1); c)", "[{parent_id: 1}]" ],
    [ "does not mutate the parents it was given",
      "(p = [{id: 1}]; destroy_parent(p, [], 1); p)", "[{id: 1}]", true ]
  ],
  hints: [
    [ :nudge, "Compare what the method returns for the children against what " \
              "you asked for. One of the two collections is untouched.", 3 ],
    [ :concept, "The parents are filtered on `:id`; the children need filtering " \
                "on `:parent_id`. `reject` returns a new array, so nothing is " \
                "mutated either way.", 4 ],
    [ :solution, "`children.reject { |c| c[:parent_id] == parent_id }`", 8 ]
  ]
)

question!(
  body: "A team changes dependent: :destroy to dependent: :delete_all to fix a " \
        "deletion timeout. What might they have broken?",
  skill_slug: "active-record-associations", type: "scenario", band: :mid,
  difficulty: :medium, topic: m2, interview_type: "technical",
  model: "`:delete_all` issues a single DELETE and instantiates nothing, so no " \
         "child callbacks run. Anything that depended on `before_destroy` or " \
         "`after_destroy` silently stops: purging attached files, decrementing " \
         "counter caches, cascading to grandchildren, emitting audit events. " \
         "The timeout is a real problem but the answer is usually batching — " \
         "`in_batches.destroy_all`, or moving the deletion into a background " \
         "job — rather than removing the cleanup. If the children genuinely " \
         "have no callbacks, `:delete_all` is correct, and a database-level " \
         "`on_delete: :cascade` is better still because it also holds when rows " \
         "are deleted by something that is not Rails.",
  explanation: "This finds out whether a candidate reads an option's mechanism " \
               "or just its name, and whether they reach for batching before " \
               "removing safety.",
  mistakes: "Saying delete_all is 'just faster'; forgetting grandchildren; not " \
            "mentioning that a database cascade covers non-Rails deletes.",
  related: %w[associations callbacks foreign-keys],
  follow_ups: [
    { body: "How would you fix the timeout without losing the callbacks?",
      trigger: "always",
      expects: %w[batch in_batches background job],
      model: "`in_batches.destroy_all`, or enqueue the deletion so the request " \
             "returns immediately and the work happens in chunks." },
    { body: "What would a foreign key constraint add here?",
      trigger: "always",
      expects: %w[database cascade integrity constraint],
      model: "It enforces the rule in the database, so orphans cannot exist " \
             "even if rows are deleted from a console, a migration or another " \
             "service. The model option is a convenience; the constraint is " \
             "the guarantee." },
    { body: "You mentioned counter caches. How would you detect they had drifted?",
      trigger: "keyword", keywords: %w[counter cache],
      expects: %w[reset_counters compare recount audit],
      model: "Compare the cached column against a real COUNT in a periodic " \
             "job, and use `reset_counters` to repair. Drift is silent " \
             "otherwise." },
    { body: "Does any of this apply to has_many :through?",
      trigger: "missing_keyword", keywords: %w[through],
      expects: %w[join through membership],
      model: "`dependent:` on a `through` association acts on the join records, " \
             "not the far side — deleting a user's memberships does not delete " \
             "the projects, which is usually what you want and occasionally a " \
             "surprise." }
  ]
)

# =========================================================== 3. Transactions
m3 = mission!(
  curriculum_module: persistence, slug: "active-record-transactions", position: 3,
  name: "The update that vanished", skill_slug: "active-record-transactions",
  minutes: 13, xp: 35, difficulty: :hard, technology: v81,
  hook: "Two requests read a balance of 100, each subtract their own amount, " \
        "and each write the result. Both succeed. One of the two withdrawals " \
        "has disappeared, and the logs show nothing wrong.",
  summary: "Atomicity, what actually rolls back, the lost update, and choosing " \
           "between optimistic and pessimistic locking.",
  blocks: [
    [ :prose, "A transaction rolls back on an exception, not on a false",
      { "body" => "`ActiveRecord::Base.transaction` rolls back when the block " \
                  "raises. It does **not** roll back because something returned " \
                  "`false` — so a bare `record.save` inside a transaction that " \
                  "fails validation leaves the transaction committing " \
                  "everything else.\n\n" \
                  "This is the same hazard as ignoring `save`'s return value, " \
                  "with a larger blast radius: inside a transaction the silent " \
                  "failure is now a partially applied operation." } ],
    [ :visual, "The lost update, step by step",
      { "kind" => "trace_table",
        "prompt" => "Two requests, interleaved. Follow the balance.",
        "steps" => [
          { "line" => "A: reads balance", "a" => "sees 100", "b" => "—" },
          { "line" => "B: reads balance", "a" => "sees 100", "b" => "sees 100" },
          { "line" => "A: writes 100 - 30", "a" => "writes 70", "b" => "holds 100" },
          { "line" => "B: writes 100 - 50", "a" => "—", "b" => "writes 50" },
          { "line" => "final", "a" => "balance is 50", "b" => "30 vanished" }
        ] } ],
    [ :prediction, "Which fix works?",
      { "question" => "Two concurrent requests each withdraw from the same " \
                      "account. Which of these actually prevents the lost " \
                      "update?",
        "options" => [ "Wrapping each read-modify-write in a transaction",
                       "Using balance = balance - amount in a single UPDATE",
                       "Adding a uniqueness validation on the account",
                       "Retrying the write if it fails" ],
        "answer" => 1,
        "explanation" => "A transaction gives atomicity, not isolation from a " \
                         "concurrent reader at the default isolation level — " \
                         "both transactions still read 100 and the last write " \
                         "wins. A single relative UPDATE (`balance = balance - " \
                         "30`) lets the database do the arithmetic while holding " \
                         "the row lock, so neither update is lost. " \
                         "`increment!` and `update_counters` generate exactly " \
                         "that." } ],
    [ :interactive, "Optimistic or pessimistic?",
      { "kind" => "risk_spotter",
        "prompt" => "Decide whether optimistic locking (a lock_version column) " \
                    "is the wrong tool here.",
        "cases" => [
          { "sql" => "A long form a user edits for ten minutes", "risk" => false,
            "why" => "Right tool. You cannot hold a database lock for ten " \
                     "minutes; a StaleObjectError on save is the correct answer." },
          { "sql" => "Two workers racing on the same row, milliseconds apart",
            "risk" => true,
            "why" => "Wrong tool — you will just convert the race into constant " \
                     "retries. `lock!` / SELECT FOR UPDATE serialises them." },
          { "sql" => "Decrementing stock during a flash sale", "risk" => true,
            "why" => "Wrong tool. A relative UPDATE with a CHECK constraint, or " \
                     "a row lock. Optimistic locking here means most requests " \
                     "fail and retry." },
          { "sql" => "Rarely-edited reference data with an audit requirement",
            "risk" => false,
            "why" => "Right tool. Conflicts are rare, and the error tells you a " \
                     "concurrent edit happened, which is what you want recorded." }
        ] } ],
    [ :code_demo, "Three ways, and what each guarantees",
      { "code" => "# 1. Lost update: two readers, last write wins\naccount.update!(balance: account.balance - amount)\n\n" \
                  "# 2. Relative update: the database does the arithmetic\nAccount.where(id: account.id).update_all([ 'balance = balance - ?', amount ])\n\n" \
                  "# 3. Pessimistic lock: serialise the readers\nAccount.transaction do\n  account.lock!                       # SELECT ... FOR UPDATE\n  raise Insufficient if account.balance < amount\n  account.update!(balance: account.balance - amount)\nend",
        "language" => "ruby",
        "annotations" => [
          { "line" => 2, "note" => "Reads in Ruby, writes an absolute value. Loses concurrent updates." },
          { "line" => 5, "note" => "Safe from lost updates, but cannot refuse an overdraft without a CHECK constraint." },
          { "line" => 9, "note" => "Blocks the second reader until the first commits. Correct, and the slowest." }
        ] } ],
    [ :scenario, "In production",
      { "situation" => "A wallet service runs `balance: balance - amount` in " \
                       "Ruby inside a transaction. Reconciliation shows the " \
                       "total of all wallets is £4,200 higher than the sum of " \
                       "the ledger. The discrepancy only appears on days with " \
                       "traffic spikes.",
        "question" => "What is happening, and why does traffic make it worse?",
        "answer" => "Lost updates. Each request reads the balance, subtracts in " \
                    "Ruby and writes an absolute value; when two overlap, the " \
                    "later write silently discards the earlier withdrawal, so " \
                    "balances end up *higher* than the ledger. Concurrency is " \
                    "the trigger, which is why it correlates with traffic and " \
                    "why it never reproduces locally. The transaction gave " \
                    "atomicity and did nothing about isolation." } ],
    [ :pitfall, "What does not roll back",
      { "body" => "**An ignored `save`** — returns false, raises nothing, " \
                  "transaction commits. **An enqueued job** — already in Redis " \
                  "when the transaction rolls back; enqueue from " \
                  "`after_commit`. **An email already delivered**. **A " \
                  "rescued exception** — rescuing inside the block means " \
                  "nothing propagates, so nothing rolls back." } ],
    [ :revision, "Recall",
      { "prompt" => "Name the one thing a transaction guarantees and the one " \
                    "thing people assume it guarantees but it does not.",
        "answer" => "It guarantees atomicity — all or nothing. It does not " \
                    "guarantee isolation from a concurrent reader at the " \
                    "default level, which is why the lost update survives " \
                    "being wrapped in one." } ]
  ]
)

challenge!(
  slug: "ar-atomic-transfer", title: "All or nothing",
  topic: m3, skill_slug: "active-record-transactions", type: :implement,
  difficulty: :hard, xp: 60,
  prompt: "Implement `transfer(balances, from, to, amount)`.\n\n" \
          "`balances` is a Hash of name => Integer. Move `amount` from `from` " \
          "to `to` and return the **new** Hash.\n\n" \
          "The transfer must be atomic. If `from` has less than `amount`, or " \
          "either account is missing, or `amount` is not positive, or `from` " \
          "and `to` are the same account, change nothing and return the " \
          "balances exactly as given.\n\n" \
          "Never mutate the Hash you were passed — a rolled-back transaction " \
          "leaves no trace.",
  starter: "def transfer(balances, from, to, amount)\n  # Your code here\nend\n",
  solution: "def transfer(balances, from, to, amount)\n" \
            "  return balances unless amount.is_a?(Integer) && amount.positive?\n" \
            "  return balances unless balances.key?(from) && balances.key?(to)\n" \
            "  return balances if from == to\n" \
            "  return balances if balances[from] < amount\n\n" \
            "  balances.merge(\n" \
            "    from => balances[from] - amount,\n" \
            "    to => balances[to] + amount\n" \
            "  )\n" \
            "end\n",
  explanation: "Every precondition is checked **before** anything changes, and " \
               "the change is built as a new Hash rather than applied in two " \
               "steps. That is what atomicity buys you: there is no moment at " \
               "which the money has left one account and not arrived at the " \
               "other. Debiting first and then validating is the bug this " \
               "shape prevents.\n\nThe self-transfer guard is not pedantry: " \
               "without it, `merge(from => debit, to => credit)` has the same " \
               "key twice, the credit wins, and the account gains money out of " \
               "nothing. The reference solution had exactly that bug until a " \
               "test caught it.",
  tests: [
    [ "moves the money",
      "transfer({'a' => 100, 'b' => 0}, 'a', 'b', 30)", "{\"a\" => 70, \"b\" => 30}" ],
    [ "conserves the total",
      "transfer({'a' => 100, 'b' => 5}, 'a', 'b', 30).values.sum", "105" ],
    [ "refuses an overdraft and changes nothing",
      "transfer({'a' => 10, 'b' => 0}, 'a', 'b', 30)", "{\"a\" => 10, \"b\" => 0}" ],
    [ "allows transferring the entire balance",
      "transfer({'a' => 30, 'b' => 0}, 'a', 'b', 30)", "{\"a\" => 0, \"b\" => 30}" ],
    [ "refuses a missing destination",
      "transfer({'a' => 100}, 'a', 'z', 10)", "{\"a\" => 100}" ],
    [ "refuses a zero amount",
      "transfer({'a' => 100, 'b' => 0}, 'a', 'b', 0)", "{\"a\" => 100, \"b\" => 0}" ],
    [ "refuses a negative amount, which would be a reverse transfer",
      "transfer({'a' => 100, 'b' => 0}, 'a', 'b', -50)", "{\"a\" => 100, \"b\" => 0}" ],
    [ "does not mutate what it was given",
      "(b = {'a' => 100, 'b' => 0}; transfer(b, 'a', 'b', 30); b)",
      "{\"a\" => 100, \"b\" => 0}" ],
    [ "a self-transfer leaves the balance unchanged",
      "transfer({'a' => 100}, 'a', 'a', 30)", "{\"a\" => 100}", true ]
  ],
  hints: [
    [ :nudge, "Check everything that could fail first, and only then build the " \
              "result. Returning `balances` unchanged is a valid outcome.", 3 ],
    [ :clue, "What does `{'a' => 1}.merge('a' => 2, 'a' => 3)` give you? Now " \
             "think about a transfer where `from` and `to` are the same.", 4 ],
    [ :concept, "If you subtract and then discover the destination is missing, " \
                "you have already lost the money. Validate, then apply.", 4 ],
    [ :solution, "Guard on amount, then on both accounts existing, then on " \
                 "`from == to`, then on sufficient funds — then " \
                 "`balances.merge(from => ..., to => ...)`.", 10 ]
  ]
)

challenge!(
  slug: "ar-debug-lost-update", title: "Where did the withdrawal go?",
  topic: m3, skill_slug: "active-record-transactions", type: :debug,
  difficulty: :hard, xp: 65,
  prompt: "`apply_withdrawals(balance, withdrawals)` should apply every " \
          "withdrawal to the balance and return the result.\n\n" \
          "Each withdrawal is a Hash `{ read_balance:, amount: }` — a record of " \
          "what that request *read* before computing its write, exactly as a " \
          "concurrent request would.\n\n" \
          "With one withdrawal it is right. With two it loses one. Fix it so " \
          "every withdrawal is applied.",
  starter: "def apply_withdrawals(balance, withdrawals)\n" \
           "  withdrawals.each do |w|\n" \
           "    balance = w[:read_balance] - w[:amount]\n" \
           "  end\n" \
           "  balance\n" \
           "end\n",
  solution: "def apply_withdrawals(balance, withdrawals)\n" \
            "  withdrawals.reduce(balance) do |current, w|\n" \
            "    current - w[:amount]\n" \
            "  end\n" \
            "end\n",
  explanation: "The starter writes an **absolute** value computed from a stale " \
               "read, so the last write wins and every earlier withdrawal is " \
               "discarded — the lost update, exactly as it happens in " \
               "production. The fix applies the change **relative** to the " \
               "current balance and ignores `read_balance` entirely. That is " \
               "why `balance = balance - ?` in a single UPDATE, or " \
               "`update_counters`, is safe where read-modify-write is not.",
  tests: [
    [ "one withdrawal is correct either way",
      "apply_withdrawals(100, [{read_balance: 100, amount: 30}])", "70" ],
    [ "two withdrawals both apply",
      "apply_withdrawals(100, [{read_balance: 100, amount: 30}, {read_balance: 100, amount: 50}])",
      "20" ],
    [ "a stale read is ignored",
      "apply_withdrawals(100, [{read_balance: 999, amount: 10}])", "90" ],
    [ "no withdrawals leaves the balance alone",
      "apply_withdrawals(100, [])", "100" ],
    [ "the total withdrawn is conserved",
      "(100 - apply_withdrawals(100, [{read_balance: 100, amount: 30}, {read_balance: 70, amount: 20}]))",
      "50" ],
    [ "three concurrent withdrawals all land",
      "apply_withdrawals(100, [{read_balance: 100, amount: 10}, {read_balance: 100, amount: 20}, {read_balance: 100, amount: 30}])",
      "40" ],
    [ "can go negative, which is a separate problem from losing updates",
      "apply_withdrawals(10, [{read_balance: 10, amount: 30}])", "-20", true ]
  ],
  hints: [
    [ :nudge, "Run it with two withdrawals of 30 and 50 from 100. You get 50, " \
              "not 20. Which of the two did the arithmetic actually use?", 3 ],
    [ :concept, "`read_balance` is a snapshot from before the other request " \
                "wrote. Any calculation starting from it discards whatever " \
                "happened since. You want the *change*, not the result.", 5 ],
    [ :solution, "`withdrawals.reduce(balance) { |current, w| current - w[:amount] }` " \
                 "— never read `read_balance` at all.", 10 ]
  ]
)

question!(
  body: "A wallet service wraps every withdrawal in a transaction, and " \
        "reconciliation still shows balances drifting upward on busy days. " \
        "Why, and how do you fix it?",
  skill_slug: "active-record-transactions", type: "architecture", band: :senior,
  difficulty: :hard, topic: m3, interview_type: "technical",
  model: "A transaction gives atomicity, not isolation from a concurrent reader " \
         "at the default isolation level. If the code reads the balance into " \
         "Ruby, subtracts, and writes an absolute value, two overlapping " \
         "requests both read the same starting figure and the later write " \
         "discards the earlier withdrawal — so balances end up higher than the " \
         "ledger. Traffic is the trigger, which is why it never reproduces " \
         "locally. The fix is to stop computing the new value in Ruby: either a " \
         "relative UPDATE so the database does the arithmetic while holding the " \
         "row lock, or `lock!` to serialise the readers if I need to refuse an " \
         "overdraft. I would also add a CHECK constraint so the balance cannot " \
         "go negative regardless of which path wrote it, and reconcile against " \
         "an append-only ledger rather than trusting the balance column as the " \
         "source of truth.",
  explanation: "A senior question, because the wrong answer — 'wrap it in a " \
               "transaction' — is the thing they already did. It separates " \
               "people who know what ACID's I actually covers.",
  mistakes: "Confusing atomicity with isolation; proposing a retry, which turns " \
            "a correctness bug into a slower correctness bug; reaching for " \
            "SERIALIZABLE without mentioning the cost.",
  related: %w[transactions locking concurrency isolation],
  follow_ups: [
    { body: "You mentioned locking. Optimistic or pessimistic here, and why?",
      trigger: "always",
      expects: %w[pessimistic for update lock serialise],
      model: "Pessimistic. The conflicts are milliseconds apart and frequent, " \
             "so optimistic locking would just convert them into constant " \
             "retries. Optimistic locking is for long human-scale edits." },
    { body: "Would raising the isolation level fix it?",
      trigger: "always",
      expects: %w[serializable repeatable read retry cost],
      model: "SERIALIZABLE would, by making one transaction fail rather than " \
             "lose the write — but you then have to handle the serialisation " \
             "failure and retry, and you pay for it on every transaction. " \
             "Targeted locking is cheaper." },
    { body: "Why an append-only ledger rather than fixing the balance column?",
      trigger: "keyword", keywords: %w[ledger reconcil audit],
      expects: %w[recompute audit source truth],
      model: "A balance can be recomputed from the ledger, so drift becomes " \
             "detectable and repairable. A balance column alone has no way to " \
             "tell you it is wrong." },
    { body: "How would you have caught this before production?",
      trigger: "missing_keyword", keywords: %w[test spec],
      expects: %w[concurrent thread test invariant],
      model: "A test that runs the withdrawal from two threads and asserts the " \
             "conservation invariant. Sequential tests cannot find a lost " \
             "update by construction." }
  ]
)
