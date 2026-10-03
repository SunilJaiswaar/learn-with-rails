# CodeQuest

A gamified software-engineering mastery platform built as a Rails 8 monolith.
Learners progress by solving, breaking, debugging and explaining — not by
reading. Mastery is measured from demonstrated performance across six
dimensions, never from pages viewed.

**Working name.** "CodeQuest" is a placeholder; the product name, tagline,
accent colour and support address are editable at **Admin → Settings** and take
effect without a deploy.

---

## What is built

This is **Phase 1 of a phased plan**, deliberately scoped to a complete vertical
slice rather than a wide set of empty pages. Every feature listed here is
working end to end and covered by specs.

| Area | State |
|---|---|
| Authentication, sessions, RBAC | Database-backed sessions, account lockout, role policies |
| Dashboard, daily quest | Adaptive recommendations, production-alert framing |
| Skill tree | 17 skills, prerequisite DAG with cycle detection, mastery-gated unlocks |
| Lesson player | 10 typed block renderers; prose is one of ten, never the whole lesson |
| Code runner | Sandboxed Ruby execution (bubblewrap + rlimits) |
| Challenges | 23 challenges, 114 assertions, 67-step hint ladders, automated code review |
| Interview arena | 4 tracks, pressure modes, follow-up probe engine, competency feedback |
| Algorithm visualiser | 11 step-through visualisers driven by real traces |
| Big-O lab | Live operation counts across six growth classes |
| Boss battles | 2 multi-stage, multi-discipline fights |
| XP, levels, achievements, streaks | Append-only ledger, 14 achievements, idempotent awards |
| Mastery + spaced repetition | Six-dimension evidence model, expanding review ladder |
| Progress reporting | Per-category interview readiness with explicit "not tested" |
| Admin panel | CRUD, content analytics, version management, audit log, branding |

### Not built yet

Phases 2–9 from the plan are **not** implemented: Rails/Hotwire/frontend
curriculum worlds, system design simulator, DevOps and CI/CD games, Redis and
Sidekiq teaching worlds, capstone projects, and the LLM-backed tutor. The
interview evaluator and code reviewer currently use a transparent rubric engine
(see [Honest limitations](#honest-limitations)).

---

## Requirements

- Ruby 3.4.5
- PostgreSQL 12+
- Redis 6+
- `bubblewrap` (for code execution) on a host with unprivileged user namespaces

## Getting started

```bash
bin/setup                 # installs gems, prepares the database, seeds content
bin/rails server          # http://localhost:3000
bundle exec sidekiq       # background jobs (optional in development)
```

Seeded development accounts:

| Account | Email | Password |
|---|---|---|
| Admin | `admin@example.com` | `admin-password-123` |
| Learner | `learner@example.com` | `learner-password-123` |

Override with `SEED_ADMIN_PASSWORD` / `SEED_LEARNER_PASSWORD`. The seed task
refuses to create demo accounts in production.

The learner account ships with history so the dashboard, progress charts,
adaptive recommendations and revision queue are populated immediately.

---

## Code execution security

Learner code is **never** evaluated in the Rails process. Submissions take this
path:

```
Rails → Challenges::Submission → CodeExecution::Runner
      → StaticGuard (reject obvious abuse early)
      → Sandbox::Bubblewrap (namespaces, allow-list mounts)
      → lib/sandbox/harness.rb (rlimits, then evaluate)
      → result.json → Result
```

What the sandbox enforces, each covered by a spec in
`spec/services/code_execution/runner_spec.rb`:

| Control | Mechanism |
|---|---|
| No network | `--unshare-all`; connections fail with `ENETUNREACH` |
| No host filesystem | Allow-list mounts: the Ruby prefix and `/lib` only. `/etc`, `/home` and the app's own source are **not** mounted |
| Single writable path | A per-run temp directory bound at `/tmp/work` |
| CPU limit | `RLIMIT_CPU`, applied inside the sandbox |
| Memory limit | `RLIMIT_AS` |
| File size limit | `RLIMIT_FSIZE` |
| No env leakage | `unsetenv_others` on spawn; only `SBX_*` injected |
| No orphans | `--die-with-parent`, plus process-group kill on timeout |
| No tty tricks | `--new-session` |

The isolation specs deliberately **bypass `StaticGuard`** so they prove the
sandbox holds on its own rather than testing the pattern blocklist.

Four non-obvious constraints, each found by testing:

1. `RLIMIT_NPROC` must not be set on the `bwrap` process — user-namespace
   creation then fails with `EAGAIN`, because NPROC counts every process for the
   uid. Limits are applied inside the sandbox instead.
2. `RLIMIT_AS` below 512MB stops CRuby 3.4 booting at all. It is a floor.
3. bubblewrap 0.4 has no `--clearenv`; the environment is cleared at spawn.
4. bubblewrap reports a signalled child as exit code `128+signal`, not via
   `termsig`, so CPU kills are detected from the exit status.

> **Deployment note.** `CODE_SANDBOX=disabled` makes the runner refuse to
> execute rather than fall back to running code in-process. If no sandbox
> backend is available, code execution is unavailable by design. Prefer running
> the runner as its own service rather than granting the web container
> user-namespace capabilities.

---

## Architecture

```
app/
  controllers/     thin; one action per verb
  models/          validations, associations, enums, DB constraints
  policies/        Pundit authorisation
  services/
    algorithms/    step-through tracers for the visualiser
    boss_battles/  multi-stage grading
    challenges/    submission orchestration
    code_execution/ sandbox, limits, static guard, harness staging
    code_review/   heuristic automated review
    gamification/  XP ledger, level curve, achievements, streaks
    interviews/    builder, rubric evaluator, follow-up planner, feedback
    learning/      adaptive engine, spaced repetition, quests, topic progress
    mastery/       six-dimension recorder and reporting
    search/        global cross-content search
    skills/        prerequisite DAG, unlock resolution
  jobs/            nightly housekeeping
lib/sandbox/       standalone harness; never autoloaded
db/seeds/          authored content, with a small DSL in support.rb
```

### Design decisions worth knowing

**Mastery is multi-dimensional.** `SkillProgress` tracks understanding,
prediction, implementation, debugging, explanation and application separately,
weighted so building and debugging count for more than reading. A skill is only
"mastered" when *every* dimension clears its bar — so finishing lessons can
never mint mastery. A challenge's *shape* decides which dimension it proves: a
`debug` challenge records debugging, not implementation.

**XP is an append-only ledger.** `users.xp_total` is a cache of
`sum(xp_transactions.amount)`, repairable by `RecalculateXpTotalsJob`. Awards
carry an idempotency key, so re-solving a challenge never pays twice.

**The skill tree is a verified DAG.** `Skills::CycleDetector` runs before any
dependency edge is saved, because a cycle would make unlock resolution
non-terminating.

**Interview follow-ups are driven by the answer.** A probe fires `always`, on a
`keyword` the learner used, or on a `missing_keyword` they omitted — which is
what stops a memorised answer scoring well.

**Content quality is enforced, not hoped for.** `Topic#definition_of_done`
checks all eleven elements of the learning loop. The admin dashboard lists
incomplete missions, and `rails content:definition_of_done` fails CI if any
mission is missing a piece.

**Front end is Hotwire plus hand-written CSS.** No build step and no CSS
framework: design tokens in `app/assets/stylesheets/application.css`, dark and
light themes, and seven Stimulus controllers. The code editor is a real
`<textarea>` with a gutter, keeping keyboard and screen-reader behaviour intact.

---

## Content authoring

Content lives in `db/seeds/` and is written with a small DSL
(`db/seeds/support.rb`) whose call sites read as the learning loop. Seeds are
idempotent — every record is found-or-created by a stable slug.

```bash
bin/rails db:seed                          # idempotent
bin/rails content:definition_of_done       # every mission carries the full loop
bin/rails content:validate_solutions       # reference solutions pass their own tests
bin/rails content:validate_debug_starters  # debug starters genuinely fail first
```

All three tasks run in CI. The last one matters more than it looks: a debugging
challenge whose starter already passes teaches nothing.

---

## Testing and quality

```bash
bundle exec rspec        # 148 examples
bin/rubocop              # rubocop-rails-omakase
bin/brakeman -i config/brakeman.ignore
```

The two Brakeman findings are the `eval` calls in `lib/sandbox/harness.rb`.
They are ignored with a documented rationale in `config/brakeman.ignore`:
evaluating the submission is that file's entire purpose, it runs inside the
sandbox in a separate interpreter, and it is excluded from autoloading.

Rack::Attack is disabled under test so throttle counters cannot leak between
examples; `spec/requests/rate_limiting_spec.rb` enables it explicitly.

---

## Application security

- Database-backed sessions, revocable server-side; signed, `httponly`,
  `same_site=lax` cookies
- Account lockout after 10 failed sign-ins
- Identical error message for unknown email and wrong password
- Per-form CSRF tokens (Rails default, left on)
- Rack::Attack throttles requests, sign-ins (by IP *and* by email), sign-ups and
  sandbox submissions; sandbox runs are additionally throttled per user
- Pundit policies; roles are never assignable from a form
- Security headers and a CSP with no `script-src 'unsafe-inline'`
- Audit log for administrative actions
- Foreign keys, unique indexes and check constraints at the database level
- `bundle-audit` in CI

### Honest limitations

- **The interview evaluator is a rubric, not a model.** It grades on concept
  coverage, answer depth and hedging, and shows the learner exactly which
  concepts were recognised or missed. It is transparent and dependency-free, but
  it cannot judge a well-argued answer phrased in unexpected terms.
  `Tutoring::Provider` is the seam where a model-backed evaluator would go.
- **The code reviewer is heuristic.** Complexity is inferred from loop nesting
  depth. Findings are labelled as heuristics in the UI.
- **`StaticGuard` is not a security boundary.** It is an early-rejection
  convenience; the sandbox is the control.
- **Fork bombs are contained by wall-clock timeout and process-group kill**,
  not by `RLIMIT_NPROC` (see constraint 1 above). A cgroup pid limit would be
  stronger and is the right next step for multi-tenant use.
- **CSP still allows `style-src 'unsafe-inline'`**, because meters and bars set
  data-driven widths via style attributes. Scripts are not exempted.
- Level titles describe progress through this curriculum. They are not a claim
  about job readiness, and completing them guarantees nothing about any real
  hiring process.

---

## Operations

```bash
bin/rails db:prepare                 # create and migrate
bundle exec sidekiq -C config/sidekiq.yml
```

Recurring jobs (`config/schedule.yml`, via sidekiq-cron): daily quest
generation, stale quest expiry, expired session pruning, weekly XP
reconciliation.

- Health check: `GET /up`
- Sidekiq dashboard: `/admin/sidekiq` (admins only)
- Docker: `docker compose up --build`, then
  `docker compose exec web bin/rails db:prepare db:seed`

---

## Roadmap

Phase 2 onward, in the order the plan sets out: SQL depth and Git; Rails,
PostgreSQL, Redis, Sidekiq, RSpec and Hotwire worlds; the frontend universe;
computer science and networking; design patterns and system design; DevOps and
observability; the LLM-backed tutor and interviewer; and the capstone projects
and final championship.

The foundations those phases need — skill graph, mastery model, sandbox,
spaced repetition, quest engine, interview engine, authoring DSL and the
definition-of-done gate — are in place and exercised by the slice above.
