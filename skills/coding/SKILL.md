---
name: coding
description: "Use when building a feature, fixing a non-trivial bug, or changing behavior and you want the work verified adversarially — the full skeptic development workflow. Runs a spec-first, test-first state machine: spec → author failing tests → adversarially review the tests → implement against the coding essentials → adversarially review the implementation → report. You are the controller; you drive the phases and dispatch subagents."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite
---

# Skepticism — adversarial verification controller

You are the **controller** of a state machine. Your job is NOT to write the
feature yourself in one pass. Your job is to move the work through phases,
dispatch the right subagents at each phase, enforce the gates, and report back
to the user. Generation and verification are kept in **separate contexts** on
purpose — that is the entire point of this workflow.

## The Iron Rules

1. **No spec, no code.** This workflow cannot run without an approved spec — it
   is the contract every later phase verifies against. If the user asks you to
   "just implement it", skip the spec, or jump straight to code, **speak up and
   refuse to proceed to tests or implementation.** Explain that you need a spec
   first, then offer the two ways forward (see Phase 0). This is not gatekeeping
   for its own sake: without a spec there is nothing to write meaningful tests
   against and nothing to verify the result against.
2. **Never skip a phase.** Each phase has a gate. You do not advance until the
   gate condition is met and written to the state file.
3. **Never write production code yourself.** Implementation happens in the
   `implementer` subagent. Tests are authored by the `test-author` subagent.
   You orchestrate and verify; you do not generate.
4. **The state file is the source of truth**, not your memory. Read it at the
   start of every turn. Write to it after every phase transition. It must
   survive context compaction.
5. **Reviewers run in isolated subagents on a prepared diff.** They never see
   the generator's reasoning. This is what removes confirmation bias.
6. **Leave no trace.** This framework is a way of working, not something the
   project depends on, and **nothing about it may reach the remote**: no REQ-IDs
   or process commentary in production code or tests, no committed run
   artifacts, no phase names in commit messages. Requirement traceability lives
   in the run's `coverage.md`, not in comments. `scripts/leak-check` enforces
   this as part of the deterministic gate — it is not overridable.

If you catch yourself thinking "this is too simple for the full process" or
"I'll just write this one bit myself" — STOP. That is the rationalization this
framework exists to prevent. Pick a lighter tier instead (see Risk Tiers).

## The state machine

```
0  ROUTE        read state.md → protect the repo → context-pack → determine phase
1  SPEC         [main context, interactive]  explore codebase → Socratic Q&A
                → write spec.md (design doc + Given/When/Then)  → USER APPROVES
                ─────────────────────── HARD GATE ───────────────────────
2  RED TESTS    [test-author subagent]  write failing tests ONLY, no impl;
                prove each fails because code is MISSING (not a typo/error);
                classify each criterion fits-the-suite vs needs-scaffolding
                ───────────── USER DECIDES any scaffolding ──────────────
3  TEST REVIEW  [test-adversary panel]  are tests meaningful, non-tautological,
                behavior-not-implementation, spec-faithful, edge-covering?
                ─────────────────────── HARD GATE ───────────────────────
                (PreToolUse hook blocks edits to source until this passes)
4  IMPLEMENT    [implementer subagent]  code to green against quality rules;
                ANY test change must be flagged with justification
5  DET GATE     [scripts/det-gate]  leak + lint + format + typecheck + tests;
                cheap deterministic checks BEFORE any LLM reviewer
6  IMPL REVIEW  [reviewer panel]  test-integrity + correctness + quality
                (+ docs in paranoid tier); each defaults to FAIL if uncertain
7  REPORT       [main context]  summarize verdicts → which phases to repeat →
                hand back to the user
```

## State file

Location: `.skepticism/runs/<feature-slug>/state.md` (relative to the repo root
of the project being worked on — NOT this plugin's repo). Everything the
framework writes lives under `.skepticism/`, which `scripts/state protect`
excludes from git **locally** via `.git/info/exclude` — writing the exclusion
into `.gitignore` would itself commit a reference to the framework.

Format:

```markdown
# Skepticism run: <feature-slug>

- feature: <one-line summary>
- tier: quick | standard | paranoid
- phase: spec | red-tests | test-review | implement | det-gate | impl-review | report | done
- checkpoints: gates | every-phase | none
- commits: ask | on | off
- plugin_root: <absolute path, resolved once in phase 0>
- base_ref: <commit this run started from>
- last_reviewed_ref: <head of the last diff the panel reviewed>
- updated: <ISO timestamp>

## Phase log
- [x] spec          → spec.md (approved by user)
- [x] red-tests     → tests-report.md, coverage.md (N tests, all failing correctly)
- [ ] test-review   → test-review.md
- [ ] implement     → (in progress)
- [ ] det-gate      → det-gate.log
- [ ] impl-review   → impl-review.md
- [ ] report

## Notes
<carry-forward context: open questions, deferred criteria, why a phase repeated>
```

Artifacts for the run live beside it, in `.skepticism/runs/<feature-slug>/`:
`{spec.md, project.md, tests-report.md, coverage.md, test-review.md,
det-gate.log, impl-review.md}`.

## Phase 0 — Route and set up

At the start of every invocation:
1. Ask the user for (or infer) the feature slug. Look for an existing
   `.skepticism/runs/<slug>/state.md`. (A run started under the old
   `docs/skepticism/<slug>/` layout still resolves — move it and carry on.)
2. If it exists: read it, announce the current phase, and resume there.
3. If not, this is a new run. Before anything else:
   - **Confirm a spec exists or will exist** (Iron Rule 1).
   - Run `${CLAUDE_PLUGIN_ROOT}/scripts/state init <slug> "<summary>"`. This also
     registers the local git exclusion (Iron Rule 6).
   - **Resolve the plugin root once** and write it to `plugin_root:` in
     `state.md`. Every dispatch from here on passes **absolute** paths. Subagents
     must never have to search for a reference file.
   - Record `base_ref:` = current `HEAD`.
   - Run `SKEPTIC_PLUGIN_ROOT=<root> ${CLAUDE_PLUGIN_ROOT}/scripts/context-pack <slug>`
     → writes `project.md` (test/lint/typecheck commands, what CI runs, the test
     layout and naming conventions, existing test files). Pass its path to every
     subagent that touches code or tests. If it reports the test command as *not
     determined*, ask the user for it now and append it to `project.md` — do not
     let a subagent guess.
   - Pick a tier (below) and confirm the commit policy (below).

**No-spec guard (act on this before any tests or code).** If the user asks to
skip the spec or jump straight to implementation, do NOT comply. Say so plainly
— e.g. *"This workflow needs an approved spec first: it's the contract the tests
and reviews check against. Without one, there's nothing meaningful to test or
verify."* — and offer the two ways forward:
  a. **Author one now** — run Phase 1 (`/skeptic:spec`). For a small change this
     is quick; even the `quick` tier requires at least a minimal spec (one or two
     EARS requirements + acceptance criteria).
  b. **Adopt an existing spec** — if the user already has a spec/PRD/design doc,
     point you at it; read it, confirm it has testable acceptance criteria (add
     REQ-IDs / Given-When-Then if missing), save it as the run's `spec.md`, and
     have the user approve it. Then proceed.
If the user insists on skipping entirely, stop and explain this is the one thing
the framework won't do — they can write plain code without `/skeptic:coding` if
they don't want it verified. Do not silently proceed.

For context on prior work, read `.skepticism/INDEX.md` (a one-page ledger of
completed runs) — NOT the full artifacts of every past run. Finished runs are
consolidated there and archived (see Phase 7), so context stays bounded as the
project accumulates runs. Only open an archived run's artifacts if this feature
genuinely depends on it.

## Checkpoints and commits

Both are run-level settings, confirmed once at the start and stored in
`state.md`. Never change them mid-run without saying so.

**`checkpoints`** — where you stop and hand control back:
- `gates` (default) — stop only at the two hard gates (spec approval, test
  review) and at any scaffolding decision. This is the balance point: an early
  stop that catches a bad test suite saves every downstream phase.
- `every-phase` — stop after each phase. Use when you're debugging the workflow
  itself; it is slow.
- `none` — run straight through, stopping only for the spec approval that Iron
  Rule 1 requires.

A **decision point** is not a checkpoint and is never skipped: if a phase
surfaces a genuine choice for the user (most often a scaffolding trade-off in
phase 2), you ask, whatever `checkpoints` says. You do not get to pick for them.

**`commits`** — auto-commit after each phase that changed files (phase 2 tests,
phase 4 implementation). Ask once at run start; default to `ask` and take the
answer. When on:
- Never commit on the default branch — create a feature branch first.
- Messages describe the **feature**, not the process: "Add session token
  issuance on valid login", never "phase 4: implement". Iron Rule 6 applies to
  history, and `leak-check` scans commit messages.
- After each phase commit, update `last_reviewed_ref` in `state.md`.
Phase commits pay for themselves three times over: they give phase 6 a stable
base for delta re-review, they give `mutation-adversary` the clean tree it
requires, and they make a loop-back a `git revert` instead of an argument.

## Risk tiers

Pick a **default** tier from change signals, **state it and why**, and let the
user override. Never silently choose.

| Tier | Default trigger | Phase-6 panel |
|------|-----------------|---------------|
| `quick` | tiny diff (~1 file, <~20 LOC), no new deps, no security/auth/IO-boundary code | det-gate + 1 combined reviewer (`reviewer-correctness` doing both correctness & quality) |
| `standard` (default) | ordinary feature or bugfix | det-gate + `reviewer-correctness` + `reviewer-quality` + `mutation-adversary` |
| `paranoid` | security/auth path, public API, data migration, concurrency, large/multi-file diff | full panel + `reviewer-test-integrity` + `mutation-adversary` + docs check; on any **Critical** finding, dispatch a second independent reviewer of the same lens and require agreement (majority vote) before blocking |

Phase 2 and 3 (author + adversarially review the tests) run in **every** tier —
the failing-tests-first discipline is non-negotiable. Tiers only scale the
phase-6 implementation panel and whether test authoring/review uses one pass or
a refute-and-revise loop.

Once the implementation exists, sanity-check the tier against reality:
`package-diff --stat` shows the measured size of the change. If it lands far
from the tier you guessed, say so and re-tier rather than defending the guess.

## Phase 1 — Spec (interactive, main context)

This phase MUST run in your context, not a subagent — it needs back-and-forth
with the user, and subagents cannot ask the user questions.

Invoke the `spec` skill (`/skeptic:spec`). It will: explore the codebase/docs, ask
clarifying questions one at a time, and produce `spec.md` containing a design
narrative, **EARS requirements** (each with a `REQ-ID`), and **Given/When/Then**
acceptance criteria that cite those REQ-IDs. The REQ-IDs stay in `spec.md` and
`coverage.md` — they never appear in code or tests (Iron Rule 6). Do not advance
until the user explicitly approves `spec.md`.

GATE: `spec.md` exists and user approved. Write phase log, set `phase: red-tests`.

## Phase 2 — Red tests (test-author subagent)

Dispatch the `test-author` subagent. Pass it, as **absolute paths**:
- `spec.md`
- `project.md` (the bearings file — test command, layout, conventions, CI)
- `<plugin_root>/reference/test-authoring-guide.md`
- where to write the tests, `tests-report.md`, and `coverage.md`

It writes failing tests ONLY — zero production code. It must prove each test
fails *because the implementation is missing*, not from an import error or
typo. If any test errors instead of failing cleanly, it fixes the test.

**Scaffolding is the user's call, not the author's.** Cheap tests and faithful
tests pull against each other, and the resolution is not the subagent's to pick.
The author classifies every acceptance criterion:
- **fits the suite** — writable now with the existing fixtures and conventions;
  it just writes these.
- **needs scaffolding** — requires new infrastructure (an expensive fixture, a
  trained-model artifact, a recorded fixture, a new harness) or a mock that
  costs real fidelity. It writes the test but marks it skipped, and reports the
  cost, what the mock would give up, and its recommendation.

**Decision point (never skipped).** If the report lists any scaffolding item,
present the table to the user and let them choose per item: build the
scaffolding, accept a lower-fidelity mock, or defer with an accepted coverage
gap. Then re-dispatch the author for whatever they chose to build. Every
deferral is recorded in `coverage.md` as an accepted gap with the reason — an
accepted gap is fine; a silent one is the failure mode this framework exists to
prevent, and the test-adversary treats any undeclared gap as critical.

GATE (deterministic): run
`${CLAUDE_PLUGIN_ROOT}/scripts/red-check <new-test-path>...`. It first checks the
project's **own** default test run collects those paths — that is what stops
tests landing in a file beside the suite that CI never executes — then runs the
suite and requires a *valid RED*: exit 0 means tests fail on assertions (good);
1 means the suite PASSES with no implementation (send back to test-author);
2 means BROKEN RED (import/syntax/collection error — the tests are broken, not
the feature); 4 means the tests are outside the project's suite. Only advance on
exit 0, with every scaffolding decision made. Then set `phase: test-review`.

## Phase 3 — Test review (adversarial)

Dispatch `test-adversary` with absolute paths to `spec.md`, `tests-report.md`,
`coverage.md`, and `<plugin_root>/reference/test-quality-rubric.md`.

It returns a structured verdict: `{ verdict, coverage_map, issues[] }`.
On fail → loop back to `test-author` with the issues **only** (not the whole
history). Hard-cap at 3 loops; if still failing, surface to the user.

GATE: verdict pass. Write `test-review.md`, set `phase: implement`. From here
the PreToolUse hook will permit edits to source. Commit the tests if
`commits: on`, and record `last_reviewed_ref`.

## Phase 4 — Implement (implementer subagent)

Dispatch `implementer` with absolute paths to: `spec.md`, `project.md`, the
approved test files, and the plugin root. It always reads
`reference/coding-essentials.md` first, and pulls in
`reference/design-and-abstraction.md` or `reference/reliability.md` only when the
change calls for them. It writes code until the tests pass, and MUST flag any
modification to a test (with justification) in its report — silently changing a
test to pass is a reportable offense the test-integrity reviewer will hunt for.

Set `phase: det-gate`.

## Phase 5 — Deterministic gate

Run `${CLAUDE_PLUGIN_ROOT}/scripts/det-gate <base_ref>` from the project root (it
auto-detects the stack). It runs `leak-check` first — unconditionally, before any
project override — then lint, format check, typecheck, the test suite, and a
docs-presence check. Capture output to `det-gate.log`.

GATE: det-gate exits 0. On failure, loop back to `implementer` with the log.
Do NOT spend LLM-reviewer tokens on code that fails deterministic checks.
Set `phase: impl-review`.

**Optional (recommended for `standard`+ tiers): mutation testing.** Now that the
suite is green against real code, run a mutation tester if one is configured for
the stack (Stryker for JS/TS, mutmut/cosmic-ray for Python, PIT for Java,
cargo-mutants for Rust, go-mutesting for Go). A surviving mutant means a test is
too weak to catch that bug — exactly the "useless test" failure mode. Treat the
mutation score as a quality signal, not a hard gate by default (it is slow);
feed surviving mutants to the test-adversary/implementer as findings. This is
the objective, ungameable counterpart to phase 3's mental mutation-kill check.
Coverage % is NOT a substitute — a test can have 100% coverage and kill no
mutants. Configure it via `.skepticism/det-gate.sh` if you want it enforced —
and when a real mutation tester is configured, skip the `mutation-adversary`
subagent entirely; it is the LLM approximation of a tool you now have.

## Phase 6 — Implementation review (adversarial panel)

First, prepare ONE shared diff so reviewers don't each re-explore the repo:
`${CLAUDE_PLUGIN_ROOT}/scripts/package-diff <last_reviewed_ref> [head]` → prints
a path. If it reports OVERSIZE, it has split the diff per file; dispatch a
reviewer per part rather than handing anyone the whole thing.

On the first pass `last_reviewed_ref` is the commit holding the *approved tests*,
so the diff is exactly the implementation — and any test the implementer touched
since approval, which is what `reviewer-test-integrity` audits. With
`commits: off` there is no such commit: `last_reviewed_ref` stays at `base_ref`
and the panel re-reads the whole change on every loop. That is the concrete cost
of declining phase commits; say so if the user is weighing it.

Dispatch the tier's panel **in parallel** (multiple Agent calls in one
message — this saves wall-clock, not tokens). The read-only reviewers each read
the prepared diff file + `spec.md`; pass them the absolute plugin root so they
can reach their rubric files:
- `reviewer-correctness` — hunt bugs, edge cases, error handling. Default FAIL.
- `reviewer-quality` — simplicity/design/readability against
  `reference/coding-essentials.md` (+ the situational refs when relevant).
- `reviewer-test-integrity` (paranoid) — were tests weakened/deleted/hardcoded
  to pass? Cross-check against the version approved in phase 3.

Also dispatch the `mutation-adversary` (standard+ tiers, unless a real mutation
tester ran in phase 5). It is NOT a read-only reviewer: it needs the **live
working tree** (to insert mutations and run tests), not the prepared diff. Pass
it the operators reference, `spec.md`, `coverage.md`, and the test command. It
surgically inserts a few plausible bugs, checks the suite catches them, and
**reverts every change** — a surviving mutant is a weak/missing assertion. (The
read-only reviewers read the static diff artifact, so they don't conflict with
its mutate-and-revert on the working tree.) Confirm the tree is clean after it
returns.

**Delta re-review on loop-back.** Critical/Important issues — including surviving
mutants — loop back to `implementer` (or `test-author` for a missing-assertion
finding) with the consolidated findings. Then re-run phase 5, and re-run phase 6
**only for the reviewers that failed**, over a diff re-packaged from
`last_reviewed_ref` (not from `base_ref`). A quality reviewer that already passed
does not need to re-read the whole diff because correctness found an off-by-one;
re-running the full panel over an unchanged diff is where multi-agent budgets
actually die. Update `last_reviewed_ref` after each pass. Hard-cap loops
(default 3, configurable). In `paranoid` tier, confirm any Critical finding with
a second independent reviewer before acting on it.

GATE: all reviewers pass (no open Critical/Important). Write `impl-review.md`,
set `phase: report`.

## Phase 7 — Report

Summarize to the user: what was built, the verdict trail, **any deferred
acceptance criteria from the scaffolding decisions** (state these plainly — they
are the known holes in the verification), any deferred Minor issues, total loops
per phase, and a rough token note. Then ask which phases (if any) to repeat. Set
`phase: done` only when the user is satisfied.

**Consolidate (memory hygiene).** Once the run is `done`, fold it away so it
stops costing context on future runs:
1. Append a one-line digest to `.skepticism/INDEX.md` — feature, outcome, and
   the *key decisions / requirement coverage* worth remembering (you know these;
   write them, don't leave the stub).
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/consolidate <slug>` to archive the run's
   artifacts under `.skepticism/archive/<slug>/` and seed the index entry.
Future runs read the one-page INDEX, not every past run's full artifacts. The
index is local to this clone — that is the cost of Iron Rule 6, and it is the
right trade.

## Resolving plugin paths

Reference docs and scripts live inside this plugin at `reference/` and
`scripts/`, addressed below as `${CLAUDE_PLUGIN_ROOT}/…`. Claude Code expands
that variable to an absolute path inline before you read this, so use the paths
as-is. Resolve it **once** in phase 0, store it in `state.md`, and pass resolved
absolute paths in every dispatch. (Fallback, only if you ever see the literal
`${CLAUDE_PLUGIN_ROOT}` unexpanded on a very old Claude Code: resolve it once by
`Glob`-ing for this plugin's `reference/spec-format.md` and substitute the real
path.)

## Dispatch contract (cost discipline)

Billed input grows with the **square** of a subagent's turn count — every turn
re-sends the whole accumulated context — so a 30-turn implementer costs roughly
four times a 15-turn one, not twice. Turn count is the lever that matters; the
rest is rounding.

- Hand subagents **absolute file paths**, never pasted content, and never a path
  they have to search for. A subagent hunting for a reference file is pure
  quadratic waste.
- Every code-touching subagent gets `project.md`. Nobody rediscovers the test
  command, the layout, or what CI runs.
- Require in every dispatch: batch independent reads into one message; run the
  **narrowest** test selector while iterating and the full suite only for the
  final green; never re-read a file already read.
- Reviewers read the **prepared diff artifact**, not the live repo.
- Run the deterministic gate before any LLM reviewer, and re-review only the
  delta on loop-back.
- Subagents return ONLY their final message to you — you do not pay for their
  internal transcript, but you *do* pay for their return on every later turn of
  yours. Cap it: **≤ 15 lines or ≤ 10 findings**, severity-ranked, overflow
  dropped with a stated count.
- **An interrupted subagent is a phase failure, never a pass.** If you or the
  user stop an agent mid-flight, write `interrupted` against that phase in
  `state.md` and re-dispatch or escalate. Silence must never read as approval.
- All subagents default to `model: inherit` — a reviewer must be at least as
  capable as the generator, or it can't catch the generator's mistakes. This
  matters most for the *judgment* lenses (`reviewer-correctness`,
  `reviewer-quality`, `test-adversary`), where a weaker model is more uncertain,
  and every uncertain reviewer defaults to FAIL — turning a cheaper model into
  more loop-backs, the single most expensive event in the system. The mechanical
  lenses (`reviewer-test-integrity`, `mutation-adversary`) are closer to
  structured audits and a cheaper model is defensible there. Scale cost with the
  *tier* first. Override deliberately, never as the default.
- Track every phase in TodoWrite so the user sees live progress. Announce each
  dispatch with the artifact path it will write, so a long phase is visibly
  alive rather than apparently hung.
