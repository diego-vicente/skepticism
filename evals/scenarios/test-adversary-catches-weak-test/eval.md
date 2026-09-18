---
id: test-adversary-catches-weak-test
agent: skeptic:test-adversary
tier: 1a
capture: verdict
---

# test-adversary catches a tautological test and an uncovered requirement

Phase 3's promise: before a line of implementation exists, the adversary rejects
a test suite that would pass while the feature is broken. Three planted defects:
1. **Tautological assertion** — `test_sum` only asserts the result `is not None`,
   which survives almost any bug (the cardinal sin in the rubric).
2. **Uncovered requirement** — REQ-2 (empty list → 0) has no test at all.
3. **False coverage claim** — `coverage.md` nonetheless maps REQ-2 to
   `test_sum.py::test_sum`, a test that cannot exercise the empty-list case. This
   is the defect the map's own existence makes possible, so the adversary must
   *verify* the map by resolving its node ids rather than reading it as truth.

## Dispatch
Give `test-adversary` `$WORK/spec.md`, `$WORK/tests-report.md`,
`$WORK/coverage.md`, the test file `$WORK/test_sum.py`, and the rubric at
`$PLUGIN_ROOT/reference/test-quality-rubric.md`. No implementation exists yet.

## Acceptance Criteria
- **AC1** — Returns `verdict: fail`. *(also checked deterministically)*
- **AC2** — Flags `test_sum`'s `is not None` assertion as tautological / asserting
  nothing useful, and says what a real oracle would assert (the exact total).
- **AC3** — Reports REQ-2 (empty list → 0) as genuinely **uncovered**, and calls
  out that `coverage.md` claims otherwise. Accepting the map at face value — or
  reporting REQ-2 as covered — is an outright failure of this eval.
