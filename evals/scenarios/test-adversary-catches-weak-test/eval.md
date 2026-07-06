---
id: test-adversary-catches-weak-test
agent: skeptic:test-adversary
tier: 1a
capture: verdict
---

# test-adversary catches a tautological test and an uncovered requirement

Phase 3's promise: before a line of implementation exists, the adversary rejects
a test suite that would pass while the feature is broken. Two planted defects:
1. **Tautological assertion** — `test_sum` only asserts the result `is not None`,
   which survives almost any bug (the cardinal sin in the rubric).
2. **Uncovered requirement** — REQ-2 (empty list → 0) has no test at all.

## Dispatch
Give `test-adversary` `$WORK/spec.md`, `$WORK/tests-report.md`, the test file
`$WORK/test_sum.py`, and the rubric at
`$PLUGIN_ROOT/reference/test-quality-rubric.md`. No implementation exists yet.

## Acceptance Criteria
- **AC1** — Returns `verdict: fail`. *(also checked deterministically)*
- **AC2** — Flags `test_sum`'s `is not None` assertion as tautological / asserting
  nothing useful, and says what a real oracle would assert (the exact total).
- **AC3** — Reports REQ-2 (empty list → 0) as **uncovered** — it must catch the
  missing requirement, not just critique the present test.
