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

If you catch yourself thinking "this is too simple for the full process" or
"I'll just write this one bit myself" — STOP. That is the rationalization this
framework exists to prevent. Pick a lighter tier instead (see Risk Tiers).

## The state machine

```
0  ROUTE        read state.md → determine phase → act
1  SPEC         [main context, interactive]  explore codebase → Socratic Q&A
                → write spec.md (design doc + Given/When/Then)  → USER APPROVES
                ─────────────────────── HARD GATE ───────────────────────
2  RED TESTS    [test-author subagent]  write failing tests ONLY, no impl;
                prove each fails because code is MISSING (not a typo/error)
3  TEST REVIEW  [test-adversary panel]  are tests meaningful, non-tautological,
                behavior-not-implementation, spec-faithful, edge-covering?
                ─────────────────────── HARD GATE ───────────────────────
                (PreToolUse hook blocks edits to source until this passes)
4  IMPLEMENT    [implementer subagent]  code to green against quality rules;
                ANY test change must be flagged with justification
5  DET GATE     [scripts/det-gate]  lint + format + typecheck + tests + docs;
                cheap deterministic checks BEFORE any LLM reviewer
6  IMPL REVIEW  [reviewer panel]  test-integrity + correctness + quality
                (+ docs in paranoid tier); each defaults to FAIL if uncertain
7  REPORT       [main context]  summarize verdicts → which phases to repeat →
                hand back to the user
```

## State file

Location: `docs/skepticism/<feature-slug>/state.md` (relative to the repo root
of the project being worked on — NOT this plugin's repo).

Create the directory on first run. Format:

```markdown
# Skepticism run: <feature-slug>

- feature: <one-line summary>
- tier: quick | standard | paranoid
- phase: spec | red-tests | test-review | implement | det-gate | impl-review | report | done
- updated: <ISO timestamp>

## Phase log
- [x] spec          → spec.md (approved by user)
- [x] red-tests     → tests-report.md (N tests, all failing correctly)
- [ ] test-review   → test-review.md
- [ ] implement     → (in progress)
- [ ] det-gate      → det-gate.log
- [ ] impl-review   → impl-review.md
- [ ] report

## Notes
<carry-forward context: open questions, deferred items, why a phase was repeated>
```

Artifacts for the run live beside it:
`docs/skepticism/<feature-slug>/{spec.md, tests-report.md, test-review.md, det-gate.log, impl-review.md}`

## Phase 0 — Route

At the start of every invocation:
1. Ask the user for (or infer) the feature slug. Look for an existing
   `docs/skepticism/<slug>/state.md`.
2. If it exists: read it, announce the current phase, and resume there.
3. If not: this is a new run. **Confirm a spec exists or will exist before doing
   anything else** (Iron Rule 1), then go to Phase 1 after picking a tier.

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

For context on prior work, read `docs/skepticism/INDEX.md` (a one-page ledger of
completed runs) — NOT the full artifacts of every past run. Finished runs are
consolidated there and archived (see Phase 7), so context stays bounded as the
project accumulates runs. Only open an archived run's artifacts if this feature
genuinely depends on it.

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

## Phase 1 — Spec (interactive, main context)

This phase MUST run in your context, not a subagent — it needs back-and-forth
with the user, and subagents cannot ask the user questions.

Invoke the `spec` skill (`/skeptic:spec`). It will: explore the codebase/docs, ask
clarifying questions one at a time, and produce `spec.md` containing a design
narrative, **EARS requirements** (each with a `REQ-ID`), and **Given/When/Then**
acceptance criteria that cite those REQ-IDs. The REQ-IDs carry through into test
comments so coverage is checkable mechanically downstream. Do not advance until
the user explicitly approves `spec.md`.

GATE: `spec.md` exists and user approved. Write phase log, set `phase: red-tests`.

## Phase 2 — Red tests (test-author subagent)

Dispatch the `test-author` subagent. Pass it, in the prompt:
- absolute path to `spec.md`
- absolute path to `${CLAUDE_PLUGIN_ROOT}/reference/test-authoring-guide.md`
- where to write tests + the report (`tests-report.md`)
- the project's test command and conventions (discover these first)

It writes failing tests ONLY — zero production code. It must prove each test
fails *because the implementation is missing*, not from an import error or
typo. If any test errors instead of failing cleanly, it fixes the test.

GATE (deterministic): run `${CLAUDE_PLUGIN_ROOT}/scripts/red-check`. It runs the
suite and requires a *valid RED* — exit 0 means tests fail on assertions (good);
exit 1 means the suite PASSES with no implementation (the tests don't exercise
the missing behavior — send back to test-author); exit 2 means BROKEN RED
(import/syntax/collection error — the tests are broken, not the feature — send
back). Only advance on exit 0. Then set `phase: test-review`.

## Phase 3 — Test review (adversarial)

Dispatch `test-adversary` with the absolute paths to `spec.md`,
`tests-report.md`, and `reference/test-quality-rubric.md` (under this plugin's
root, `${CLAUDE_PLUGIN_ROOT}/reference/test-quality-rubric.md`).

It returns a structured verdict: `{ verdict: pass|fail, issues: [...] }`.
On fail → loop back to `test-author` with the issues. Hard-cap at 3 loops; if
still failing, surface to the user.

GATE: verdict pass. Write `test-review.md`, set `phase: implement`. From here
the PreToolUse hook will permit edits to source.

## Phase 4 — Implement (implementer subagent)

Dispatch `implementer`. Pass it: `spec.md`, the now-approved test files, and the
resolved plugin root. It always reads `reference/coding-essentials.md` first,
and pulls in `reference/design-and-abstraction.md` or `reference/reliability.md`
only when the change calls for them. It writes code until the tests pass, and
MUST flag any modification to a test (with justification) in its report —
silently changing a test to pass is a reportable offense the test-integrity
reviewer will hunt for.

Set `phase: det-gate`.

## Phase 5 — Deterministic gate

Run `${CLAUDE_PLUGIN_ROOT}/scripts/det-gate` from the project root (it
auto-detects the stack). It runs lint, format check, typecheck, the test
suite, and a docs-presence check. Capture output to `det-gate.log`.

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
mutants. Configure it via `.skepticism/det-gate.sh` if you want it enforced.

## Phase 6 — Implementation review (adversarial panel)

First, prepare ONE shared diff so reviewers don't each re-explore the repo:
`${CLAUDE_PLUGIN_ROOT}/scripts/package-diff <base> <head>` → prints a path.

Dispatch the tier's panel **in parallel** (multiple Agent calls in one
message). The read-only reviewers each read the prepared diff file + `spec.md`;
pass them the resolved plugin root so they can reach their rubric files:
- `reviewer-correctness` — hunt bugs, edge cases, error handling. Default FAIL.
- `reviewer-quality` — simplicity/design/readability against
  `reference/coding-essentials.md` (+ the situational refs when relevant).
- `reviewer-test-integrity` (paranoid) — were tests weakened/deleted/hardcoded
  to pass? Cross-check against the version approved in phase 3.

Also dispatch the `mutation-adversary` (standard+ tiers). It is NOT a read-only
reviewer: it needs the **live working tree** (to insert mutations and run
tests), not the prepared diff. Pass it the operators reference
(`${CLAUDE_PLUGIN_ROOT}/reference/mutation-operators.md`), `spec.md`, and the
test command. It surgically inserts a few plausible bugs, checks the suite
catches them, and **reverts every change** — a surviving mutant is a weak/
missing assertion. (The read-only reviewers read the static diff artifact, so
they don't conflict with its mutate-and-revert on the working tree.) Confirm the
tree is clean after it returns.

Collect verdicts. Critical/Important issues — including surviving mutants — loop
back to `implementer` (or `test-author` for a missing-assertion finding) with
the consolidated findings, then re-run phases 5–6. Hard-cap loops (default 3,
configurable). In `paranoid` tier, confirm any Critical finding with a second
independent reviewer before acting on it.

GATE: all reviewers pass (no open Critical/Important). Write `impl-review.md`,
set `phase: report`.

## Phase 7 — Report

Summarize to the user: what was built, the verdict trail, any deferred Minor
issues, total loops per phase, and a rough token note. Then ask which phases
(if any) to repeat. Set `phase: done` only when the user is satisfied.

**Consolidate (memory hygiene).** Once the run is `done`, fold it away so it
stops costing context on future runs:
1. Append a one-line digest to `docs/skepticism/INDEX.md` — feature, outcome,
   and the *key decisions / REQ coverage* worth remembering (you know these;
   write them, don't leave the stub).
2. Run `${CLAUDE_PLUGIN_ROOT}/scripts/consolidate <slug>` to archive the run's
   artifacts under `docs/skepticism/archive/<slug>/` and seed the index entry.
Future runs read the one-page INDEX, not every past run's full artifacts.

## Resolving plugin paths

Reference docs and scripts live inside this plugin at `reference/` and
`scripts/`, addressed below as `${CLAUDE_PLUGIN_ROOT}/…`. Claude Code expands
that variable to an absolute path inline before you read this, so use the paths
as-is and pass the resolved absolute paths to subagents. (Fallback, only if you
ever see the literal `${CLAUDE_PLUGIN_ROOT}` unexpanded on a very old Claude
Code: resolve it once by `Glob`-ing for this plugin's `reference/spec-format.md`
and substitute the real path.)

## Dispatch contract (cost discipline)

- Subagents return ONLY their final message to you — you do not pay for their
  internal transcript. Keep their *return* short and structured.
- Always hand subagents **file paths**, never paste large content into prompts.
- Reviewers read the **prepared diff artifact**, not the live repo.
- Run the deterministic gate before any LLM reviewer.
- All subagents default to `model: inherit` — a reviewer must be at least as
  capable as the generator, or it can't catch the generator's mistakes. The
  verification value comes from fresh context + adversarial framing, NOT from
  swapping in a cheaper model. Scale cost with the *tier* (how many reviewers)
  and your session model, not by weakening the reviewers. Override an individual
  agent to a cheaper model only deliberately, never as the default.
- Track every phase in TodoWrite so the user sees live progress.
