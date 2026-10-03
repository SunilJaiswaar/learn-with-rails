# Phase 1 — Existing Application Audit

Required by brief §112. Produced 2026-10-03 against commit `da98f8c`.

Every number below was measured from the running application and its database,
not estimated. Commands are reproducible from `docs/audit-queries.rb`.

---

## 1. CURRENT ARCHITECTURE

A single Rails 8.1.4 / Ruby 3.4.5 application. PostgreSQL, Redis, Sidekiq,
Hotwire (Turbo + Stimulus), Propshaft, importmap. No JavaScript build step.

| Layer | Count |
|---|---|
| Models | 45 |
| Tables | 40 |
| Controllers | 40 (9 under `Admin::`) |
| Service namespaces | 21 |
| Views | 109 ERB templates |
| Application Ruby | 10,216 lines |
| Public routes | 76 |
| Specs | 420 examples |

**Service namespaces:** `admin`, `algorithms`, `boss_battles`, `challenges`,
`championships`, `cicd`, `code_execution`, `code_review`, `gamification`,
`hotwire`, `incidents`, `interviews`, `labs`, `learning`, `mastery`,
`redis_vault`, `search`, `skills`, `sql_execution`, `system_design`,
`tutoring`.

### What is genuinely solid

These are the load-bearing parts worth preserving without change:

- **Two isolated execution sandboxes.** `CodeExecution::Sandbox::Bubblewrap`
  (unprivileged user namespaces, allow-list mounts, `RLIMIT_CPU/AS/FSIZE`,
  `--unshare-all`, `--die-with-parent`) and a restricted PostgreSQL role on a
  separate connection pool for SQL. Availability is established by a real
  probe sharing its command prefix with production, and both are verified in
  CI by `code_sandbox:verify` / `sql_sandbox:verify`. This satisfies §58 and
  is the hardest thing in the codebase to get right.
- **Six-dimension mastery model.** `understanding / prediction /
  implementation / debugging / explanation / application`, weighted, on a
  moving average, with the level gated on the *weakest* dimension. Satisfies
  §52 and §118's "concepts genuinely mastered" rule at the model level.
- **Append-only XP ledger** with idempotency keys; `users.xp_total` is a
  recomputable cache. No fake progress is reachable by replaying a request.
- **Skill graph as a verified DAG** with `Skills::CycleDetector`.
- **Spaced repetition** on an expanding ladder `[0,1,3,7,14,30,60]` (§62).
- **Content quality gates as CI-failing rake tasks** —
  `content:definition_of_done`, `content:validate_solutions`,
  `content:validate_debug_starters`. Reference solutions are *executed*, and
  debug starters are proven to fail before they ship.
- **Security posture.** Pundit, Rack::Attack, CSP without
  `script-src 'unsafe-inline'`, audit logging, Brakeman and RuboCop clean,
  `bundle-audit` in CI.

---

## 2. CURRENT CONTENT STRUCTURE

### The hierarchy that exists

```text
World (9)
  ├── CurriculumModule (29) ──┐
  └── Skill (33) ─────────────┤
                              └──> Topic (38)   ["mission"]
                                     └── Lesson (38, strict 1:1)
                                           └── LessonBlock (353)
                                     ├── Challenge (89)
                                     ├── Question (41) ── QuestionFollowUp (86)
                                     └── Algorithm (12)
```

### The hierarchy the brief requires (§2)

```text
CAREER → ROLE → ROADMAP → WORLD → DOMAIN → SKILL → CONCEPT →
MICRO-CONCEPT → INTERACTIVE EXPERIENCE → CHALLENGE → DEBUGGING →
PROJECT → INTERVIEW → MASTERY
```

**Existing depth: 3 meaningful levels. Required: 8.**
Missing entities entirely: `Career`, `Role`, `Domain`, `Project`.
`Roadmap` exists as `LearningPath` (3 records) but has no route.

### Content inventory

| Entity | Count |
|---|---|
| Worlds | 9 |
| Skills | 33 |
| Topics (missions) | 38 |
| LessonBlocks | 353 |
| Challenges | 89 (74 Ruby, 15 SQL) |
| Questions | 41 |
| QuestionFollowUps | 86 |
| Algorithms | 12 |
| BossBattles | 5 |
| InterviewTemplates | 5 |
| QuestTemplates | 5 |
| Achievements | 14 |
| Technologies | **3** (Ruby, SQL, PostgreSQL) |
| TechnologyVersions | 7 |
| LearningPaths | 3 |
| Projects | **0** |

### Finding C1 — content sits exactly on the quality floor

**23 of 33 skills have precisely 1 mission, 2 challenges, 1 question.** The
other 10 are barely deeper, and only the SQL cluster is meaningfully so:

| Skill | missions / challenges / questions |
|---|---|
| `sql-joins` | 4 / 9 / 5 |
| `sql-aggregation` | 2 / 6 / 2 |
| `sql-basics` | 2 / 5 / 2 |
| `indexing` | 1 / 4 / 1 |
| `hash-maps` | 1 / 4 / 2 |
| `ruby-blocks` | 1 / 3 / 2 |
| `query-performance`, `event-loop`, `dom-rendering`, `containers` | 1 / 3 / 1 |

Seven of those ten exceed the floor by a single challenge or question.

**Root cause:** `content:definition_of_done` enforces a *minimum* per topic.
Content was authored to pass the gate, and the gate's floor became the
ceiling. This is §118 inverted — the build optimised for breadth of coverage
rather than depth of mastery, because breadth is what the gate measured.

### Finding C2 — Rails has zero curriculum

```text
Skills matching "rails":            0
Topics mentioning Rails:            0
Challenges on Rails/ActiveRecord:   0
Interview questions mentioning Rails: 2 (incidental)
```

The brief makes Rails the flagship specialisation (§11–§14, three full
sections). A Rails teaching platform, written in Rails, teaches no Rails.
Rails concepts appear only *implicitly* inside labs (Sidekiq Factory, Hotwire
Lab) and SQL/N+1 challenges.

### Finding C3 — technology coverage is 3 of ~57

Of the technologies named in §1, these have **no skill at all**: Python,
Kafka, ZooKeeper/KRaft, Machine Learning, LLM, RAG, Agents, Elasticsearch,
Docker, AWS, Linux, TypeScript, React, Angular, MySQL, Statistics, Pandas,
NumPy — plus HTML/CSS, GitHub, SOLID, LLD, HLD, OS, Computer Architecture,
NLP, Deep Learning, Prompt Engineering, Embeddings, Vector DBs, Multi-Agent,
AI Evaluation, MLOps, Data Science.

Roughly 20 named areas are touched at floor depth by the 33 existing skills.
The **entire AI/ML/LLM/RAG/agent block (§30–§40, ~20 technologies) is zero.**

---

## 3. CURRENT UX PROBLEMS

### U1 — the organising metaphor is invisible

`World` has **9 records and no route**. There is no `/worlds`, no world map,
no world page. The brief's primary `LEARN` entry (§5) and the central visual
metaphor (§6, §100, §120) exist in the database and not in the product. The
only way into content is `/map` (skill map) or a direct `/skills/:id`.

### U2 — navigation does not match the brief and is missing two whole areas

Current sidebar: a flat list — Dashboard, Challenges, Algorithms, Big-O lab,
Skill map, System design, Boss battles, Championships, Interviews, Incidents,
Progress, Revision, Achievements, Settings — grouped only as *Labs &
Simulators* / *Arena & War Room* / *You* / *Staff*.

Required (§5): `HOME / LEARN / PRACTICE / BUILD / AI LAB / SYSTEM DESIGN /
INTERVIEW / COMPETE / PROGRESS`.

`BUILD` and `AI LAB` have no content and no route. `LEARN` has no landing
page. Worlds, Roadmaps and Technologies are absent from navigation.

### U3 — no screen answers the brief's three questions (§70)

Of *Where am I? / Why am I learning this? / What happens next?*, only a
partial breadcrumb exists (`topics/show` prints
`curriculum_module.name`). Nothing tells a learner why a skill matters or
what it unlocks next, beyond a bare prerequisite list.

### U4 — mobile and accessibility are unverified

**4 `@media` queries** in the entire stylesheet, for a platform required to
work on desktop, laptop, tablet and mobile with re-designed interactions
rather than a shrunken desktop (§101). No Capybara, no browser-based test,
so no responsive or accessibility claim (§102) has ever been checked.
ARIA/role attributes appear 9 times in the sidebar and once in the layout.

### U5 — dead CSS classes

`text-success`, `text-danger` and `card--subtle` were referenced across a
dozen lab views and defined in neither `application.css` nor `components.css`,
so all pass/fail colour-coding was inert. Fixed in `092b88c`.
`card--interactive` was the same: used by eight views, defined nowhere, so
every card meant to read as clickable read as inert. Fixed while building the
world pages.

The underlying problem is that no test renders a page and inspects style, so
this class of bug is invisible to CI — see X7.

---

## 4. DUPLICATED CONTENT

### D1 — `CurriculumModule` and `Skill` are near-isomorphic (severity: high)

Both `belongs_to :world`. Both parent `Topic`. There are **29 modules and 33
skills, forming 33 distinct `(module, skill)` pairs across 38 topics** — a
near 1:1 mapping. 23 of 29 modules contain exactly one topic.

Two tables express the same grouping. `Skill` carries progression
(`SkillProgress`, dependencies, mastery); `CurriculumModule` carries only a
display label used on `topics/show` and in admin.

### D2 — `Lesson` is a vestigial 1:1 pass-through (severity: medium)

38 topics, 38 lessons, **exactly 1 lesson per topic**, and all 353
`LessonBlock`s hang off `Lesson`. The table and its join add a level of
indirection and no information.

### D3 — three routes from World to Topic

`World → CurriculumModule → Topic`, `World → Skill → Topic`, and
`Topic.world` as a `has_one :through`. Ambiguous ownership; the UI picks
different paths in different places.

---

## 5. MIXED CONTENT

### M1 — the 11 labs are a parallel taxonomy, not content

System Design, Network, Redis Vault, Sidekiq Factory, Git Time Machine,
CI/CD, Security Fortress, CPU Scheduler, Hotwire, Incidents, Championships
are **hardcoded in controllers and service constants, not database records.**
They sit in the sidebar as a flat sibling list of the curriculum.

Partially addressed in `9dfbf76`: `Labs::Catalogue` now maps each lab to a
skill and a mastery dimension, and labs render on their skill's page. But
they remain code rather than content — they cannot be authored in admin,
cannot be reordered, cannot carry prerequisites, and do not appear in search.

### M2 — Big-O lab, Algorithms and Complexity overlap

`/big-o`, `/algorithms`, `/algorithms/:id/trace` and the `complexity` skill
cover adjacent ground through three separate controllers with no cross-link.

### M3 — labs teach technologies the curriculum does not have

Redis Vault, Sidekiq Factory and Hotwire Lab teach Redis, Sidekiq and Hotwire
interactively, but none of the three exists as a `Technology`, and only
`redis-caching` and `background-jobs` exist as floor-depth skills. The
hands-on layer is ahead of the conceptual layer — the reverse of §3's
DISCOVER → SEE → UNDERSTAND → INTERACT ordering.

---

## 6. MISSING DEPENDENCIES

### X1 — ~~prerequisites are a soft gate, bypassable by URL~~ **Fixed**

**Corrected once, then fixed.** An earlier draft said prerequisites gate
nothing and that `LOCKED`/`AVAILABLE` do not exist. Both were too strong:
`Skills::TreeBuilder#state_for` already computed `:locked` and `:available`
from prerequisite mastery, and the skill map already rendered a locked skill
as a dashed, non-clickable node. The real gap was enforcement.

Enforced in the commit following this audit. `Skills::Availability` answers
the question for one skill in two queries, `GatesContent` renders §50's
"learn these first" page with a `403`, and the rule itself now lives in
`Skills::UnlockRule` so the map and the gate cannot drift apart.

Gated: skills, missions (including `#complete`), challenges (including
submission), boss battles (including `#start`). Not gated: the engineering
labs and the interview arena — see the concern's own comment for why.

Still outstanding from this finding: nothing *recommends* a path, and
availability is still computed per request rather than queryable in bulk
without building the tree. See X2 for why it was not denormalised.


### X2 — mastery state machine is 5 persisted states, not 9

Persisted on `SkillProgress`: `untested / weak / developing / strong /
mastered`.
Required (§93): `LOCKED / AVAILABLE / STARTED / PRACTICING / UNDERSTOOD /
APPLIED / VALIDATED / MASTERED / REVIEW_REQUIRED`.

`LOCKED` and `AVAILABLE` exist as computed values (X1) but are not part of
the persisted enum, so two separate concerns — "has this learner demonstrated
it" and "is this learner allowed to start it" — share one column. That
conflation is the substantive gap, not the label count.

**Deliberately not denormalised.** An earlier version of this audit
recommended persisting availability on `SkillProgress`. That was the wrong
call and is withdrawn: availability is derived entirely from prerequisite
mastery, so a stored copy goes stale the moment any prerequisite moves, and
every dependent skill would need invalidating on every mastery change. A
locked skill also has no `SkillProgress` row to store it on. `SkillProgress`
keeps one job — what the learner has demonstrated — and availability is
computed, cheaply, by `Skills::Availability`.

### X3 — no AI, RAG or agent layer

| Required | Status |
|---|---|
| AI tutor (§56) | Rule-based hint ladder only |
| Model-backed tutor | `Tutoring::AnthropicProvider` written, **never executed** (no key, no gem) |
| AI code reviewer (§57) | `CodeReview::Analyzer`, heuristic (loop-nesting depth) |
| AI interviewer (§55) | Rubric + keyword follow-up triggers, no model |
| Embeddings / vector store (§35) | **absent** |
| RAG pipeline (§76) | **absent** |
| RAG evaluation (§77) | **absent** |
| Agent architecture (§78) | **absent** |
| Tool registry / permission layer (§79) | **absent** |

Sections 30–40 and 76–79 are entirely greenfield.

### X4 — execution engine covers 2 of 6+ languages

Ruby and SQL only. §115 lists Python fundamentals in the MVP; §8 offers the
learner a choice of Ruby / Python / JavaScript / Java / Go / C++. The
sandbox architecture generalises (the harness is language-agnostic in shape),
but no Python or JS runner exists.

### X5 — no project layer

**Zero project entities.** §59 (four tiers of projects), §87 (BUILD IT
engine), §90 (project connection graph) and the `BUILD` nav area have nothing
to build on. §113's "preserve existing projects" has nothing to preserve.

### X6 — no source registry

§75 requires every concept to carry official-documentation provenance
(source URL, version, last verified, status). No such table or field exists.
§74's version-awareness is partially present (`TechnologyVersion`, 7 records,
and an admin screen) but content is not labelled current/legacy/deprecated.

### X7 — test coverage has two structural holes

| Spec type | Files |
|---|---|
| requests | 13 |
| services | 21 |
| content | 2 |
| **models** | **0** |
| **system** | **0** |

45 models have no direct specs. More seriously, **no browser-based test
exists** (no Capybara, no Selenium). Every interactive simulator — the whole
differentiator — is verified only by asserting substrings in returned HTML.
Nothing has confirmed that a Turbo Stream actually mutates a DOM, that a
drag-and-drop board works, or that any page survives phone width.

---

## 7. BROKEN FLOWS

| # | Flow | Status |
|---|---|---|
| B1 | World → Domain → Skill browse | **Fixed.** `/worlds` and `/worlds/:slug`. |
| B2 | Choose a career/role → get a roadmap (§66–§67) | **Partly fixed.** `/roadmaps` renders the 3 paths with per-step state; `Career`/`Role` still absent, and nothing recommends a path. |
| B3 | Skill assessment → personalised path (§68) | Absent. |
| B4 | Blocked by prerequisite → learn missing concept (§50) | **Fixed.** 403 with the missing prerequisites, their current mastery, a time estimate from their own missions, and a link to start. |
| B5 | Browse technologies / versions as a learner | **Fixed.** `/technologies` shows which version is taught and flags legacy ones. |
| B6 | Build a project (§59) | No entity, no route. |
| B7 | AI Lab (§30–§40) | No entity, no route. |
| B8 | Ask the AI tutor a question with citations (§76) | Rule-based only, no retrieval, no citations. |
| B9 | Author a lab in admin | Labs are code, not content (M1). |
| B10 | Natural-language search "why is my Rails app slow?" (§84) | `/search` exists; keyword over existing records only, and there is no Rails content to find. |

---

## 8. MIGRATION PLAN (§113)

No existing content is destroyed. The mapping below preserves all 420 specs'
subjects, all user progress tables (`SkillProgress`, `ChallengeAttempt`,
`QuestionAttempt`, `TopicCompletion`, `XpTransaction`, `UserAchievement`,
`ReviewSchedule`, `Streak`, `BossAttempt`) untouched, because none of them
reference `CurriculumModule` or `Lesson`.

| Brief entity | Source | Action |
|---|---|---|
| `World` | `World` (9) | Keep. Add route + map page. |
| `Domain` | **`CurriculumModule` (29)** | **Rename and re-parent.** It is already a World-level grouping; promote it to sit *above* `Skill` instead of beside it. |
| `Technology` | `Technology` (3) | Keep. Expand. |
| `Skill` | `Skill` (33) | Keep. Re-parent under `Domain`. |
| `Concept` | **`Topic` (38)** | Rename. `Topic` already plays this role. |
| `Lesson` | `Lesson` (38) | **Collapse.** Re-parent 353 `LessonBlock`s directly onto `Concept`; drop the 1:1 table. |
| `Challenge` | `Challenge` (89) | Keep unchanged. |
| `Project` | — | **New.** |
| `Interview` | `Question` (41) + `QuestionFollowUp` (86) + `InterviewTemplate` (5) | Keep unchanged. |
| `Roadmap` | `LearningPath` (3) + `LearningPathStep` | Keep; add `Career` / `Role` above; add routes. |

### Migration sequencing

Each step is independently shippable and reversible.

1. ~~**Route what already exists.**~~ **Done** in the commit following this
   audit. `/worlds`, `/worlds/:slug`, `/roadmaps`, `/roadmaps/:slug`,
   `/technologies`, `/technologies/:slug`, plus `Learn` and `Practice` nav
   groups. Zero schema change, zero content change; 9 worlds, 3 roadmaps and
   3 technologies became reachable. Closes B1, B2, B5, U1; U3 is closed for
   the new pages only (breadcrumbs plus a "next in this world" card).
2. **Collapse `Lesson`** (D2). One migration moving `lesson_blocks.lesson_id`
   to `concept_id`. No progress table touches it.
3. **Promote `CurriculumModule` → `Domain`** above `Skill` (D1). This is the
   only genuinely invasive change; it is detailed below in §119 format.
4. ~~**Enforce the gate that is already computed.**~~ **Done** (X1).
   `Skills::Availability` plus a `GatesContent` concern across skills,
   missions, challenges and boss battles, with the shared rule extracted to
   `Skills::UnlockRule`.
5. **Then** vertical slices per §114.

### The one invasive change, in §119's required format

```text
CURRENT PROBLEM
  CurriculumModule and Skill are near-isomorphic (29 vs 33, 33 distinct
  pairs). Topic has two parents rooted at the same World, so there are three
  paths from World to Topic and the UI picks different ones in different
  places.

ROOT CAUSE
  Two groupings were introduced for two different jobs — display labelling
  and progression tracking — and were never reconciled. Neither was given
  the Domain layer's job, so both drifted into being it.

PROPOSED SOLUTION
  Rename CurriculumModule to Domain and move it above Skill:
      World → Domain → Skill → Concept
  Topic (→ Concept) keeps exactly one parent: Skill. Domain's display label
  is derived through Skill rather than stored on Concept.

WHY
  It is the brief's required layer (§2), it already exists under another
  name, and it removes the ambiguity rather than adding a fifth table. The
  alternative — adding a separate Domain and keeping CurriculumModule —
  would make the duplication worse.

IMPACT
  Schema: drop topics.curriculum_module_id, add skills.domain_id.
  Code: topics/show breadcrumb, admin topic form, SkillsController include.
  No user-progress table references either column, so no progress is at risk.
  Specs affected: 2 request specs asserting the breadcrumb.

MIGRATION
  1. Add skills.domain_id, nullable.
  2. Backfill from each skill's topics' existing curriculum_module_id
     (the mapping is 1:1 for 33 of 33 skills; assert this in the migration
     and abort if any skill maps to more than one module).
  3. Switch reads to skill.domain.
  4. Drop topics.curriculum_module_id in a later deploy.
```

---

## 9. RECOMMENDED SCOPE — AND AN HONEST WARNING

The brief names ~57 technologies, 9+ worlds, a full AI/ML/RAG/agent universe,
Kafka with ZooKeeper-vs-KRaft comparison, Elasticsearch, AWS, React/Angular,
a multi-language execution engine, a drag-and-drop system-design simulator
with capacity modelling, a RAG pipeline with its own evaluation harness, and
an agent platform with a permission layer. **That is multi-team, multi-year
scope.** Section 114 says so itself: do not build 100 worlds simultaneously.

The existing application is a *good foundation and a thin product*: the
engines (sandboxes, mastery, XP, DAG, spaced repetition, quality gates) are
production-grade; the content is one mission deep almost everywhere, and the
flagship technology has no curriculum at all.

Therefore the highest-value next work, in order:

1. **Route the invisible** (step 1 above) — hours, not days, and it converts
   existing unreachable content into a usable product.
2. ~~**Enforce the prerequisite gate.**~~ **Done.** Enforced at the
   controller with §50's "learn these first" page. Not persisted on
   `SkillProgress` — see X2 for why that recommendation was withdrawn.
3. **One excellent vertical slice, per §114.** Given C2, that slice should be
   **Rails**, not Python: it is the brief's flagship, it has zero content, and
   the platform is itself a Rails application, so every lesson can inspect
   real running code. Taking Rails from zero to the §116 definition of done —
   roadmap, prerequisites, concepts, visuals, simulations, coding and
   debugging challenges, a project, production scenarios, interview questions
   with follow-ups, a boss battle, revision and mastery assessment — is the
   single most valuable deliverable available.
4. **Deepen SQL to §116**, since it is already closest.
5. **Then** replicate the slice shape for Python → DSA → AI.

Deferred deliberately, with reasons: Kafka/ZooKeeper/Elasticsearch/AWS
(require real infrastructure to teach honestly, or simulators of a size
comparable to the whole current app); the RAG and agent universe (needs an
embedding store, a model budget, and an evaluation harness before any lesson
can be written); React/Angular/TypeScript (need a JS build step and a JS
sandbox that does not exist).

### Two quality-bar gaps worth fixing early, independent of content

- **Add Capybara and a system-spec layer** (X7). The interactive
  simulators are the product's differentiator and nothing verifies them in a
  browser. Every lab bug found this session — the dead CSS classes, the
  missing turbo_stream template, the 4KB cookie overflow — was invisible to
  420 passing specs.
- **Raise the content gate from a floor to a ladder** (C1). Today
  `definition_of_done` asks "does this topic have one of each?". It should
  ask "is this *technology* complete?" per §116, so that passing the gate
  means depth rather than presence.
