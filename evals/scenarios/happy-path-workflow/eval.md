---
id: happy-path-workflow
tier: 1b
capture: transcript
driver: story.md
---

# Full workflow smoke: phases chain, scripts are wired, real code ships green

The one end-to-end proof that the controller actually drives the state machine —
authors a spec, writes failing tests, dispatches the phase-6 panel, and ends
with green code and a clean tree. Deliberately a trivial pure function so the
run stays short; the value is in the *plumbing*, not the feature.

Expensive and slow (several minutes). Not a CI test — run it manually or on an
eval host, ideally 2–3 times (LLM runs vary).

## Acceptance Criteria
- **AC1 (deterministic)** — `docs/skepticism/*/spec.md` exists and contains at
  least one `REQ-` id.
- **AC2 (deterministic)** — a test file for `slugify` exists and the suite passes
  against the final implementation.
- **AC3 (deterministic)** — the transcript shows the `skeptic:coding` skill
  invoked and at least **2** subagents dispatched (Agent/Task calls).
- **AC4 (deterministic)** — the run's `state.md` reached `phase: report` (or
  `done`). (No tree-clean assertion here — a build workflow is meant to add
  `slug.py` and its tests; new files are the expected output, not a leftover.)
- **AC5** — phases ran **in order** (spec approved before tests; tests reviewed
  before implementation; implementation reviewed before report) and the reviewers
  passed against genuinely real code (not tests bent to pass).
