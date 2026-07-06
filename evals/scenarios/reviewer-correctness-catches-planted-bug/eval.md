---
id: reviewer-correctness-catches-planted-bug
agent: skeptic:reviewer-correctness
tier: 1a
capture: verdict            # runner saves the subagent's final message to verdict.txt
---

# reviewer-correctness catches a planted boundary bug

The signature promise of phase 6: an adversarial reviewer, reading only a
prepared diff + the spec in a clean context, catches a real correctness bug that
the (deliberately thin) tests let through.

The planted flaw is **subtle on purpose** — a single off-by-one at the passing
threshold (`score > 70` where the spec says `>= 70`), so `score == 70` wrongly
grades as *fail*. An egregious bug would make this eval moot (any reviewer trips
over it); a boundary error is exactly what a rubber-stamp review misses and a
real one catches.

## Dispatch
Give `reviewer-correctness` the prepared diff (`$WORK/diff.md`) and `$WORK/spec.md`.

## Acceptance Criteria
- **AC1** — The reviewer returns `verdict: fail`. *(also checked deterministically)*
- **AC2** — It identifies the **off-by-one at the passing threshold**: that a
  score of exactly 70 is graded `fail` when REQ-1 requires it to be `pass`. It
  must name the boundary/comparison specifically — a vague "watch for edge cases"
  does not pass.
- **AC3** — It does not pad the verdict with hallucinated bugs that aren't in the
  diff (a wrong-reason fail is still a miss).
