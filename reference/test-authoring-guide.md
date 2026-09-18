# Test authoring guide (test-author's contract)

How to write tests that are *insightful* — that would actually catch a bug — not
the shallow, tautological tests that pass while the feature is broken. This is
the positive counterpart to `test-quality-rubric.md` (which the adversary uses
to judge you). Internalize both: you will be reviewed against the rubric.

The mental model for every test you write: **"If I introduced an obvious bug
here — flipped a `>` to `>=`, returned a constant, dropped an element — would
this test fail?"** If not, the test asserts nothing useful. Strengthen it.

**Sections:** 1. Test behavior, not implementation · 2. Choosing WHAT to test
(partitioning, boundaries, risk, integration bias) · 3. Choosing WHAT to assert
(Right-BICEP) · 4. Oracle discipline · 5. Properties · 6. FIRST · 7. Structure
(AAA, DAMP) · 8. AI test anti-patterns · 9. Test cost and scaffolding.

---

## 1. Prime directive: test behavior, not implementation

- A good test **survives refactoring**. If renaming a private method or
  reorganizing internals breaks the test, it was testing the wrong thing.
- Assert on **observable outcomes**: return values, visible side effects, API
  responses, persisted state that callers care about.
- Do NOT assert on internal call sequences ("mock called 3 times"), private
  fields, or exact log strings. Verifying *that a mock was called* proves the
  mock works, not the code.

## 2. Choosing WHAT to test — pick inputs deliberately

### Equivalence partitioning + boundary value analysis (highest yield)
Divide inputs into classes that should behave the same, then test a
representative of each — and especially the **boundaries**, where bugs cluster.
For any bounded input test: `min-1, min, min+1, max-1, max, max+1`. Always also
consider: **empty, zero, negative, null/None, very large, duplicates, unicode,
whitespace**. For collections: empty, single element, many.

### Risk-based prioritization
Spend the most test effort where a bug is most likely or most costly:
complex/branchy logic, state machines, money/auth/data-integrity paths, and
integration points (where your code meets a DB, API, or filesystem).

### Bias toward integration (the testing trophy)
Heavily-mocked unit tests prove "this works *if* its dependencies do." Prefer
tests that exercise real collaborators. **Mock only at genuine boundaries** —
network, clock, randomness, external services — never at every call site.

### What NOT to test
Trivial getters/setters, the language/framework/stdlib, third-party libraries,
and anything that just recomputes the implementation. These add maintenance and
false confidence without catching bugs.

## 3. Choosing WHAT to assert — Right-BICEP

For each unit, ask whether you've covered:
- **Right** — correct result on the normal path.
- **Boundary** — the edge inputs from §2 (this is where most defects hide).
- **Inverse** — if a paired operation exists (encode/decode, push/pop,
  serialize/parse), assert the round-trip returns the original.
- **Cross-check** — verify the result another way: a reference implementation,
  a simpler (slower) algorithm, or an independent computation.
- **Error** — force failures: invalid input, missing dependency, timeout. Assert
  the *exact* error behavior the spec's `IF/THEN` requirements demand.
- **Performance** — only when the spec states a bound; otherwise skip.

For boundary correctness specifically, the **CORRECT** checklist: Conformance
(format), Ordering, Range, Reference (valid external refs), Existence
(null/missing), Cardinality (counts/length), Time (expiry, ordering of events).

## 4. Oracle discipline (the anti-tautology rule)

Every assertion needs an **oracle** — a trustworthy source for the expected
value. In order of preference:
1. **Hardcoded from the spec** — `assert total == 30` because the spec says so.
2. **Reference implementation** — compare against a known-good library or a
   deliberately simple alternative.
3. **Property** — assert an invariant that must hold (see §5).

**NEVER** compute the expected value using the same logic as the code under
test. `expected = items.reduce(sum)` to test a `sum()` that does the same thing
passes even when both are wrong. If you can't state where the expected value
came from without reading the implementation, the test is worthless.

## 5. Go deeper with properties (when applicable)

When a function has invariants, prefer **property-based tests** (Hypothesis,
fast-check, QuickCheck, proptest…) that generate many inputs:
- **Round-trip / inverse:** `decode(encode(x)) == x` for all `x`.
- **Idempotence:** `f(f(x)) == f(x)`.
- **Commutativity / associativity** where they should hold.
- **Monotonicity:** more input → predictably more/less output.
- **Oracle equivalence:** fast impl agrees with a slow reference.
For functions with no obvious oracle (ranking, ML, rendering), use
**metamorphic relations**: assert how the output *changes* when the input is
perturbed (e.g. swapping synonyms shouldn't change a classification).

## 6. FIRST — keep the suite healthy

- **Fast** — runs in milliseconds; slow suites get skipped. When a criterion
  genuinely cannot be tested fast, that is a trade-off to surface, not to
  resolve on your own — see §9.
- **Independent** — no test depends on another or on execution order.
- **Repeatable** — deterministic; no real clock/network/randomness.
- **Self-validating** — a real assertion decides pass/fail; never "eyeball the
  output".
- **Timely** — written before the implementation (that is the whole point here).

## 7. Structure

- **Arrange-Act-Assert** (= Given-When-Then). One **behavior** per test; if you
  assert two unrelated things, split it.
- **Descriptive names**: `returns_401_when_password_invalid`, not `test_2`.
- **No REQ-IDs, no process commentary.** Requirement traceability lives in the
  run's `coverage.md` as runnable node IDs, never in a comment. Someone reading
  this repo should not be able to tell how the tests were produced.
- **No logic in a test body** — no loops, conditionals, or computed expected
  values. Logic in a test can be wrong the same way the code is; a reader must
  verify the expectation by eye. If you'd need a test to check your test,
  it's wrong.
- **DAMP over DRY.** Unlike production code, tests favor *Descriptive And
  Meaningful Phrases* over deduplication: a little inlined, repeated setup that
  keeps each test readable top-to-bottom beats a shared helper that hides what's
  under test. Complete (body has everything needed to understand the result) and
  concise (nothing else). The readability bar is high; the abstraction bar is low.
- **Tests are code too.** They follow the same readability and comment policy as
  production code (the coding essentials): no commented-out code, comment only
  the non-obvious *why* (e.g. why an edge case matters), and match the
  surrounding test conventions.

## 8. AI test anti-patterns — do NOT do these

- Asserting trivialities (`assert result is not None` as the only check).
- Over-mocking until no real logic runs.
- Mirroring the implementation to compute the expected value.
- Happy-path only; skipping boundaries and errors.
- Chasing line-coverage % by testing trivial code.
- Asserting on mock call counts instead of observable behavior.
- Pinning exact log/error *strings* the spec doesn't mandate (brittle).

## 9. Test cost and scaffolding

Some criteria cannot be tested both faithfully and cheaply. Training a model,
standing up a database, building a search index, exercising a real integration —
these take real time, and mocking them away removes exactly the behavior the
test existed to check. Both halves of that tension are legitimate, which is why
**you do not resolve it yourself.** You classify, you cost it, you recommend,
and the user decides.

### Classify every acceptance criterion
- **Fits the suite** — writable now with the fixtures, helpers and conventions
  that already exist, and fast. Write it and move on.
- **Needs scaffolding** — needs infrastructure that doesn't exist yet, or a mock
  that costs real fidelity. Write the test, mark it skipped with the project's
  own marker, and report it.

Report per item: what building it would take, roughly how slow it runs, **what a
mocked version would stop catching**, and your recommendation. That last one is
the part the user can't work out for themselves.

### Making an expensive test affordable (once the user says yes)
- **Scope the fixture up.** Pay the setup once per session, not once per test:
  `@pytest.fixture(scope="session")`, jest `globalSetup`, Go `TestMain`, JUnit
  `@BeforeAll`. This is the first thing to reach for and often the whole answer.
- **Persist the artifact.** Build the expensive thing once and save it — a
  trained model file, a golden dataset, a recorded HTTP cassette — then load it.
  Cheap forever after. The cost is staleness: add a way to regenerate it, and
  say in your report what drift it could hide.
- **Mock at the boundary, and name what you gave up.** Treating a model as
  "already trained" is legitimate when the test is about the code *around* the
  model. It is not legitimate when the test is about the training. State which
  one this is.
- **Marker-based slow tests.** `@pytest.mark.slow`, `testing.Short()`, a
  separate jest project. The inner loop runs the fast subset; the full set runs
  before merge. This keeps a genuinely slow test *in the suite* instead of
  deleting it — the outcome the framework wants.

### The line you don't cross
Never silently weaken an assertion to make a test fast. A fast test that proves
nothing is strictly worse than a slow test that proves something: it costs the
same to maintain and it actively misleads. If the only cheap version would be
vacuous, say so and let it be deferred explicitly — an accepted gap is honest,
a hollow test is not.
