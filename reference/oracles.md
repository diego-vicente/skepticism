# Designing an oracle

An **oracle** is the thing that can say *not yet* before the work exists.

## The test every oracle must pass

Before phase 2 can close, the oracle satisfies all three:

1. **It fails now**, and for the right reason. A red that comes from a broken
   harness is not a red. You must be able to say which line of the goal it is
   failing against.
2. **It can be wrong.** Name one plausible outcome of the work that this oracle
   would reject. If you cannot, the oracle measures nothing. This is the single
   most common failure, and it is why phase 3 exists.
3. **It is outside the builder's reach.** The builder must not be able to pass
   it by editing it. Freeze it, commit it, or protect its path with the hook.

A fourth property is not required but is worth buying when it is cheap: **the
oracle should be cheap to run**, because one you run once is a gate and one you
run a hundred times is a feedback loop.

## The two failure modes

**The vacuous oracle** passes before the work starts. A test that asserts
`result is not None`, an evaluation whose baseline already beats target, an
analysis plan that yields its conclusion on shuffled data. Phase 2's red check
exists to catch this and nothing else.

**The captured oracle** is one the builder can move. A test the builder
rewrote, a threshold lowered after the first disappointing run, a hypothesis
restated once the data was seen. Phase 3 approves the oracle and
`reviewer-oracle-integrity` checks afterwards that it did not move.

## The rubric the adversary judges against

Phase 3 scores the oracle on five questions. The coding track has a fuller rubric
in `test-quality-rubric.md`; every other track uses these.

1. **Does it fail now, for the stated reason?** Name the line of the goal it
   fails against. A red from a broken harness is not a red.
2. **Name one plausible outcome it would reject.** If you cannot, the oracle
   measures nothing. This question catches more bad oracles than the other four
   together.
3. **Does it measure behaviour or mechanism?** An oracle tied to how the work is
   built breaks on every refactor and passes on a wrong result.
4. **Where did each expected value come from?** The goal, a reference
   implementation, or an invariant — never from the same logic as the work.
5. **Is every acceptance criterion covered or declared?** An accepted gap in
   `coverage.md` is fine. An undeclared one is critical.

## Worked examples

### Code — a feature or a bug fix

**Oracle:** a test suite written from the spec, failing on assertions because
the implementation is missing. **Red:** the suite fails; it does not error.
**Captured if:** the builder edits a test. **Use the `skeptic:coding` track.**

### A trained model

**Oracle:** a held-out split, one primary metric, a cheap baseline, an agreed
target, and a stated way to bound the uncertainty. **Red:** the baseline scores
below target. **Captured if:** the split is touched, the metric is redefined, or
hyperparameters are tuned on test. **Use the `skeptic:model` track.**

### An analysis or an experiment

**Oracle:** a pre-registered claim, its measurement, the result that would
falsify it, and the decision that depends on it. **Red:** the frozen plan run
against shuffled outcomes produces no answer. **Captured if:** the claim or the
exclusions change after the data is seen. **Use the `skeptic:analysis` track.**

### A data migration or a backfill

**Oracle:** a reconciliation query that compares source and destination on row
count, on the sum of every numeric column, on a sample of primary keys fetched
from both, and on referential integrity. **Red:** it reports the destination as
empty or mismatched. **Captured if:** the tolerance is widened after the first
run. Add an untouchable frozen sample of source rows so a re-extract cannot
quietly redefine the source of truth.

### A performance target

**Oracle:** a benchmark on a fixed input, with a stated percentile, a stated
number of runs, and a stated environment. **Red:** the current code misses the
target on that benchmark. **Captured if:** the input, the percentile, or the
warm-up count changes. Record the machine — a benchmark without one compares two
different questions.

### An infrastructure change

**Oracle:** a plan diff that shows exactly the resources you intend, plus a
smoke check that the service answers after apply. **Red:** the smoke check fails
against the current state. **Captured if:** the plan is regenerated with
different variables than the one reviewed. For Terraform the plan file itself is
the artefact to freeze.

### A document, a specification, or a report

**Oracle:** the questions a reader must be able to answer after reading it,
written before the document is written, plus the reader who will be asked.
**Red:** the current draft, or its absence, fails to answer them. **Captured
if:** a question is dropped because the draft did not answer it. This is the
weakest oracle on the list, because the check is a judgement. Keep it anyway:
a written list of questions is much harder to rationalise past than a general
sense that the document reads well.

### A prompt or an agent behaviour

**Oracle:** a fixed set of inputs with expected behaviours, including the
adversarial ones, scored by a rule where a rule works and by a judge where it
does not. **Red:** the current prompt fails a stated fraction of them.
**Captured if:** a failing case is deleted, or the judge's rubric is softened.
Keep the case set append-only, and record why each case was added.

## When no oracle is possible

Some work genuinely cannot be checked in advance — a first exploration, a
throwaway spike, a question whose shape you do not know yet. **Say so and do not
run this framework.** A ceremonial oracle written to satisfy a process is worse
than none, because it converts an honest "we do not know" into a false green.
The right move is a spike with a time box, followed by a real run once you know
what you are building.
