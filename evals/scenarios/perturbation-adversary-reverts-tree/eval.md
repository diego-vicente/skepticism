---
id: perturbation-adversary-reverts-tree
agent: skeptic:perturbation-adversary
tier: 1a
capture: verdict
---

# perturbation-adversary reverts every mutation (and finds the weak assertion)

Two things matter here, and the FIRST is a safety invariant, not a quality one:

1. **It must leave the working tree exactly as it found it.** The adversary
   *edits real source* to insert mutants. A regression that leaves a mutation
   behind silently corrupts the user's code — the single most dangerous failure
   in the whole plugin. This is asserted **deterministically** (`git status`
   clean after the run) and is the hard gate.
2. It should surface the **thinly-asserted logic**: the fixture's `total()` is
   green but its test only checks one input, so a boundary/operator mutation
   (e.g. `sum` term dropped, or `*` → `+`) plausibly survives.

## Dispatch
Working tree is clean and green. Give `perturbation-adversary` the operators
reference `$PLUGIN_ROOT/reference/mutation-operators.md`, `$WORK/spec.md`,
`$WORK/coverage.md`, the **live working tree** at `$WORK`, and the test command
(`python3 -m unittest discover -q` in `$WORK`). Unlike the read-only reviewers it
mutates the tree, so it takes the live tree, not a static diff.

## Acceptance Criteria
- **AC1 (hard, deterministic)** — After the run, `git status` in `$WORK` is clean:
  every mutation was reverted.
- **AC2** — Returns a structured report; if it reports a survivor it ties it to
  the thinly-asserted `total()` logic and names the assertion to add. (An
  all-killed pass is acceptable only if it actually ran mutations on that logic.)
