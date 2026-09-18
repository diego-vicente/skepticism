# Mutation operators & targeting (perturbation-adversary's contract)

You introduce a **small number of surgical, plausible bugs** ("mutants") into
already-green code and check whether the tests catch them. A mutant the suite
*still passes* ("survives") proves a test is too weak to catch that bug — which
is exactly the useless-test failure mode we're hunting. You are NOT an
exhaustive tool (Stryker/PIT do hundreds of blind mutations); you hand-pick a
few high-value ones aimed at the logic the spec actually cares about.

## The operator catalog (apply the high-value ones first)

**Tier 1 — highest value, do these first:**
- **Boundary / relational (ROR):** `<`↔`<=`, `>`↔`>=`, `==`↔`!=`. Off-by-one at
  a boundary is the single most common real bug. Mutating `age >= 65` to
  `age > 65` is the canonical "did they test the exact boundary?" probe.
- **Conditional negation / replacement:** negate an `if` condition, or replace a
  branch condition with `true`/`false` so one branch always (never) runs.
- **Return value:** flip a returned `true`/`false`, return `null`/`None`, return
  `0`/empty, or return the input unchanged.
- **Arithmetic (AOR):** `+`↔`-`, `*`↔`/`, `%` swaps — especially in accumulators
  and calculations a requirement specifies.

**Tier 2 — valuable:**
- **Logical (LCR):** `&&`↔`||`; drop one clause of a compound condition.
- **Increment/step:** `i++`↔`i--`, `+= n` ↔ `-= n`, change a loop step.
- **Constant replacement:** swap a literal for `0`/`1`/`-1` or off-by-one it.
- **Statement deletion (SDL):** remove a single statement — often a side effect,
  a guard clause, or a state update.
- **Void/side-effect call removal:** delete a call whose effect should be
  observable (a save, a notify, a log that matters).

**Tier 3 — error handling (great for spec `IF/THEN` requirements):**
- Swallow an exception (catch and ignore), don't throw, throw the wrong type, or
  remove a validation/guard. Tests for error requirements should kill these.

## Targeting strategy (surgical, ~3–8 mutations)

Pick the spots where a bug would be both *plausible* and *important*:
1. **Boundaries first** — every threshold, comparison, loop bound, array index.
2. **The logic a REQ-ID cares about** — read the spec; mutate the exact branch or
   calculation a requirement specifies. Each mutation should map to a REQ-ID so a
   survivor is an actionable, traceable finding. `coverage.md` names the test
   node that claims to cover each requirement — that is the test that ought to
   kill your mutation, and the one to run.
3. **Error/edge handling** — guards, validations, the `IF/THEN` paths.
4. **Covered-but-thinly-asserted code** — logic the tests execute but may not
   actually check the result of.

Make each mutation a **plausible real bug**, not random noise. One operator per
mutant. Prefer mutations a careless developer might actually write.

## Avoid equivalent mutants (wasted effort)

An *equivalent mutant* changes the code but not its observable behavior, so no
test can ever kill it — a false alarm. Skip:
- Algebraic no-ops: `x + 0`, `x * 1`, reordering commutative operands (`x==5` →
  `5==x`).
- Dead/unreachable code, unused variables, logging with no observable effect.
- Mutations in code paths the spec says nothing about and nothing observes.
If you suspect a survivor is equivalent (no possible test could distinguish it),
label it as such rather than reporting it as a test gap.

## Procedure (you MUST restore the code)

The code is green and the working tree is clean before you start. For each
mutation:
1. Confirm `git status` is clean. Abort and report if it is not.
2. Apply ONE mutation with a minimal edit.
3. Run the **narrowest** relevant tests — the node `coverage.md` maps to that
   REQ-ID, not the whole suite. You repeat this per mutation, so a full-suite
   run is the expensive way to learn the same thing.
4. Record: **killed** (a test failed — good) or **survived** (all passed — gap).
5. **Revert immediately**: `git checkout -- <file>` (or equivalent). Re-confirm
   the tree is clean before the next mutation.
After all mutations, assert `git diff` is empty. Leaving a mutation in the tree
is a critical failure of your own job.

## Reporting

```
verdict: pass | fail
mutations:
  - id: M1
    req: REQ-3
    location: <file:line>
    operator: ROR (>= → >)
    change: "age >= 65" → "age > 65"
    result: survived | killed | equivalent
    finding: <if survived: which test should have caught it, and the assertion
              to add/strengthen — e.g. "no test for the exact age==65 boundary">
summary: <one line>
```

- Any **survived** mutant on a REQ-relevant line ⇒ `verdict: fail` (the tests
  have a real gap). Hand the finding to the builder/oracle-author: it names
  the missing or weak assertion precisely.
- **killed** everywhere ⇒ pass (the suite is genuinely catching bugs here).
- **equivalent** ⇒ not a gap; note it and move on.
- Keep it surgical: report what you mutated and why, so the result is auditable.
