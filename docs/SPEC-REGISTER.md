# Requirement register — brief sections 1–111

**These are summaries, not the original text.** Sections 1–111 arrived in a
message truncated by a 50,000-character limit, so this register records each
section's demand and its current status rather than reproducing wording that
cannot be verified. Sections 112–120 are held verbatim in
`BRIEF-112-120.md`. Where the brief's wording is binding, it is quoted.

Status key: **done** · **partial** · **none** · **n/a** (not yet applicable)

| § | Requirement | Status | Note |
|---|---|---|---|
| 1 | Teach ~57 named technologies | **partial** | 3 `Technology` records; ~20 areas at floor depth; 18 probed names have zero skill |
| 2 | Hierarchy CAREER→ROLE→ROADMAP→WORLD→DOMAIN→SKILL→CONCEPT→MICRO-CONCEPT→…→MASTERY | **partial** | 3 levels of 8; `Career`/`Role`/`Domain`/`Project` absent |
| 3 | Learning loop DISCOVER→SEE→UNDERSTAND→INTERACT→PREDICT→CODE→BREAK→DEBUG→OPTIMIZE→BUILD→EXPLAIN→INTERVIEW→MASTER | **partial** | predict/code/debug/explain/interview exist; BUILD absent |
| 4 | Dashboard showing path, world, mission, XP, level, streak, mastery, weak skills, today's challenge, boss, interview readiness | **partial** | 9 of 12 ivars present; no world, no path, no interview-readiness |
| 5 | Nav: HOME/LEARN/PRACTICE/BUILD/AI LAB/SYSTEM DESIGN/INTERVIEW/COMPETE/PROGRESS | **partial** | flat 4-group sidebar; LEARN landing, BUILD and AI LAB absent |
| 6 | World 1 — Computer Foundation + CPU/instruction simulator | **partial** | `Computer City`, 4 floor-depth skills; no CPU datapath simulator |
| 7 | World 2 — Internet/Networking + browser-request simulator | **partial** | Network Lab exists (DNS/TCP/TLS/packets); not tied to curriculum depth |
| 8 | Programming fundamentals before syntax; multi-language choice | **partial** | `Programming Forest` is Ruby-only; no language switch |
| 9 | Per-language BEGINNER→…→INTERVIEW ladder | **none** | no language has all 7 tiers |
| 10 | Ruby Kingdom as one of the deepest tracks | **partial** | `Ruby Kingdom` has **1** skill (`ruby-blocks`) |
| 11–14 | Rails as flagship: fundamentals, Active Record, advanced, internals | **none** | **zero Rails curriculum** (audit C2) |
| 15 | Hotwire Galaxy (Drive/Frames/Streams/Morph/Stimulus) | **partial** | Hotwire Lab rebuilt with 7 stream actions + 6 prediction challenges; Morph and Stimulus lifecycle not covered |
| 16 | Python world | **none** | |
| 17 | DSA world (18 structures, 20 algorithms) | **partial** | `Algorithm Arena` 6 skills, 12 algorithms |
| 18 | Algorithm visualiser with play/pause/step/reverse/predict | **partial** | `/algorithms/:id/trace` steps; no reverse, no speed control |
| 19 | Big-O arena | **done** | `/big-o`, 6 growth classes with live operation counts |
| 20 | SQL dungeon incl. CTEs, window functions, EXPLAIN, locks, isolation | **partial** | deepest area; 15 SQL challenges, EXPLAIN against a 50k-row table; no locks/isolation/partitioning/replication |
| 21 | Redis world + production failure simulations | **partial** | Redis Vault has 5 challenges, TTL, maxmemory, token bucket; no stampede/penetration/avalanche/hot-key scenarios |
| 22 | Sidekiq world | **partial** | Sidekiq Factory (queues, retries, dead set) |
| 23 | Kafka world | **none** | |
| 24 | ZooKeeper vs KRaft, switchable architecture simulator | **none** | |
| 25 | System Design universe, LLD/HLD/Distributed kept separate | **partial** | one System Design simulator; LLD/HLD not separated |
| 26 | LLD: SOLID + 20 design patterns, each taught problem→pain→pattern→trade-off | **partial** | `design-patterns` and `oop-design` at floor depth |
| 27 | HLD fundamentals and building blocks | **partial** | covered only inside the simulator |
| 28 | Drag-and-drop architecture board with 1K→10M load simulation | **done** | capacity derived per challenge, autoscale headroom, saturation reporting |
| 29 | Failure simulator (12 named failure modes) | **partial** | System Design injects failures; Incidents lab has scripted incidents |
| 30 | 20 real system-design projects | **none** | no project entity |
| 31–40 | AI universe: maths, ML, DL, LLM, RAG, advanced RAG, agents, agent lab, data science, Python AI stack | **none** | **entirely greenfield** (audit X3) |
| 41 | Rails + Python AI architecture, 5 variants | **none** | |
| 42 | Software architecture world (CQRS, event sourcing, hexagonal…) | **partial** | `architecture` skill at floor depth |
| 43 | Security world + attack/defence simulations | **partial** | Security Fortress runs exploits against vulnerable and secured code; 1 skill |
| 44 | DevOps world (Linux, Docker, CI/CD, AWS) | **partial** | `containers`, `ci-cd`, `observability` at floor depth; CI/CD lab exists; no Linux/AWS |
| 45 | Testing world (RSpec + pytest) | **partial** | `testing-rspec` at floor depth |
| 46 | Debugging world — "one of the biggest areas", 18 named scenarios | **partial** | debug challenges exist and are proven to fail before shipping; Incidents lab; far from 18 |
| 47 | Game system where XP represents demonstrated skill | **done** | append-only ledger, idempotency keys, no replay farming |
| 48 | Dynamic skill tree with prerequisite unlocking | **partial** | `TreeBuilder` computes locked/available from prerequisite mastery and the map renders it; not enforced at the controller (audit X1) |
| 49 | Knowledge graph, not isolated lessons | **partial** | `SkillDependency` DAG, 40 edges, skill-level only — no concept-level graph |
| 50 | Prerequisite engine that blocks and offers the missing concept | **partial** | lock state computed correctly; does not block a direct URL, and there is no "learn these first" offer |
| 51 | Adaptive learning on 10 signals | **partial** | `Learning::AdaptiveEngine` exists; narrower signal set |
| 52 | Mastery requires understand+predict+implement+debug+optimize+explain+apply+interview | **done** | six weighted dimensions, gated on the weakest |
| 53 | 8 learning modes (Learn/Practice/Challenge/Exam/Interview/Boss/Sandbox/Debug) | **partial** | challenge, interview, boss, debug present; no exam/sandbox/learn-mode toggle |
| 54 | Interview arena by technology / skill / experience / company type | **partial** | 5 templates with experience bands; no company-type axis |
| 55 | AI interviewer with 10-step probing | **partial** | rubric + keyword/missing-keyword follow-up triggers, 86 follow-ups; no model in the loop |
| 56 | AI tutor that never reveals answers immediately | **done** | `Tutoring::HintLadder`, progressive, 267 hints |
| 57 | AI code reviewer across 11 dimensions | **partial** | heuristic (loop-nesting depth), labelled as heuristic in UI |
| 58 | Safe code execution with CPU/memory/timeout/fs/network/process limits | **done** | bubblewrap + restricted PG role, both CI-verified |
| 59 | Project-based learning, 4 tiers | **none** | |
| 60 | Real-world incident mode | **partial** | Incidents lab with logs/metrics/traces |
| 61 | Daily quest system | **done** | `QuestTemplate` ×5, `Learning::QuestGenerator` |
| 62 | Spaced repetition with varied contexts | **partial** | ladder `[0,1,3,7,14,30,60]`; same item re-asked, not re-contextualised |
| 63 | Cross-concept learning ("where will I use this?") | **partial** | labs now surface on skill pages; no general cross-concept view |
| 64 | Technology comparison lab, 12 comparisons | **none** | |
| 65 | FDE track | **none** | |
| 66 | Career paths (4 named) | **partial** | 3 `LearningPath` records, **no route** |
| 67 | Learning path builder from a stated goal | **none** | |
| 68 | Diagnostic skill assessment | **none** | |
| 69 | UI premium/modern/technical/playful, no walls of text | **partial** | consistent dark design system; 4 `@media` queries |
| 70 | Every screen answers Where am I / Why / What next | **none** | partial breadcrumb only (audit U3) |
| 71 | 20-step concept page template | **partial** | ~11 of 20 elements enforced by `content:definition_of_done` |
| 72 | ~35 structured content entities | **partial** | 40 tables; missing `Domain`, `Concept`/`MicroConcept` split, `Project*`, `Simulation`, `Visual`, `Source`, `DebugScenario` |
| 73 | Dependency graph rather than hardcoded order | **done** | `SkillDependency` + cycle detection |
| 74 | Version-aware learning, content labelled current/legacy/deprecated | **partial** | `TechnologyVersion` ×7 + admin screen; content not labelled |
| 75 | Source registry with URL, version, last-verified, status | **none** | |
| 76 | RAG knowledge engine for the tutor, with citations | **none** | |
| 77 | RAG evaluation (precision, recall, groundedness, cost…) | **none** | |
| 78 | 8 separate agents with orchestration | **none** | |
| 79 | AI safety: tool registry, permissions, sandbox, audit, budgets | **partial** | sandbox and audit log exist; no tool registry or budget layer (no agents to govern) |
| 80 | Multi-dimensional leaderboard, un-farmable | **none** | no leaderboard; the anti-farming property is already in the XP ledger |
| 81 | 10 competition formats | **partial** | boss battles ×5, championships |
| 82 | Final championship capstone | **done** | Developer Championship across boss + challenge + interview |
| 83 | Admin content system for ~22 entity types, reusable content | **partial** | admin covers topics, challenges, questions, technology versions, users, settings, audit logs |
| 84 | Global + natural-language search | **partial** | `/search` keyword over existing records |
| 85 | "Why?" engine (recursive questioning) | **none** | |
| 86 | "What if?" engine (edge cases per concept) | **partial** | prediction blocks and failure injection in labs |
| 87 | "Build it" engine unlocking combined projects | **none** | |
| 88 | Interview answer training (explain→example→failure→compare→scale) | **partial** | follow-up probes do some of this |
| 89 | Explanation scoring on 8 dimensions, not keyword matching | **partial** | rubric scores concept coverage, depth and hedging — **deliberately** not a model, so a score is reproducible and appealable |
| 90 | Project connection graph | **none** | |
| 91 | Personalised learning AI | **partial** | adaptive engine + weakest-skill surfacing |
| 92 | Strict content validation; cannot publish without full mapping | **partial** | `definition_of_done` gate; no world/domain/prereq completeness check |
| 93 | 9-state learning state machine | **partial** | 5 persisted states; `LOCKED`/`AVAILABLE` computed but not persisted, so gating and demonstration share one column (audit X2) |
| 94 | Analytics on 12 signals | **partial** | attempts, hints, mastery, streaks recorded; no drop-off or confusion analytics |
| 95 | Production-quality platform on the named stack | **partial** | Rails/PG/Redis/Sidekiq/Hotwire/Docker/GH Actions in use; no Elasticsearch, no AWS, no Python service |
| 96 | Rails architecture: services, queries, policies, presenters… | **done** | 21 service namespaces, Pundit policies, no gratuitous abstraction |
| 97 | Tests incl. system tests and progression/mastery/AI/sandbox coverage | **partial** | 420 specs; **0 model specs, 0 system specs, no Capybara** (audit X7) |
| 98 | Brakeman, RuboCop, dependency audit, auth, rate limiting, CSRF/XSS/SQLi, audit logging | **done** | all in CI and clean |
| 99 | Observability incl. AI logs, LLM latency/cost, agent tool calls | **partial** | app logs and audit log; no AI telemetry (no AI in the loop) |
| 100 | UI communicating a living engineering universe | **partial** | worlds exist in data, not in the UI (audit U1) |
| 101 | Responsive: desktop/laptop/tablet/mobile, re-designed not shrunk | **partial** | 4 `@media` queries, never browser-tested |
| 102 | Accessibility: keyboard, screen reader, contrast, reduced motion | **partial** | `data-reduced-motion`, some ARIA; never audited |
| 103 | Game-inspired, not childish | **done** | |
| 104 | Learn from other platforms without copying content or branding | **done** | all content original |
| 105 | Differentiator: one concept followed across every level | **partial** | holds for SQL; nowhere else has the levels to follow |
| 106 | Worked example — Database Index across 13 levels | **partial** | `indexing` 1/4/1 with real EXPLAIN; ~4 of 13 levels |
| 107 | Worked example — RAG end to end | **none** | |
| 108 | Worked example — Kafka end to end | **none** | |
| 109 | Worked example — Rails request lifecycle, inspectable at every step | **none** | |
| 110 | Master learning loop (16 stages) | **partial** | missing BUILD and OPTIMIZE stages |
| 111 | Opening screen shows "here is your next mission", not a catalogue | **done** | dashboard leads with `@next_action` |

## Tally

99 rows cover sections 1–111 (some rows group adjacent sections, e.g. 11–14
and 31–40). Counted from the table itself, not asserted:

| Status | Rows |
|---|---|
| done | 14 |
| partial | 60 |
| none | 25 |

The shape of this tally is the audit's main conclusion: **the engines are
built and the curriculum is not.** Almost everything scored *done* is
infrastructure (sandboxes, ledger, DAG, gates, hint ladder, capstone), and
almost everything scored *none* is either content for a technology that has
none, or the AI/RAG/agent layer that has no foundation yet.
