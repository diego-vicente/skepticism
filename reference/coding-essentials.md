# Coding essentials (these always apply)

The always-on rules for writing and reviewing code in this workflow. Every
code-writing and code-reviewing agent reads this first. For topics that apply
only sometimes — design patterns, abstraction decisions, reliability/
concurrency, test strategy — consult the situational references listed at the
end *when the work calls for them*.

Favor the smallest change that solves the actual problem. Default to less code,
not more — but readable beats terse. The next reader (human or agent) is the
audience: code is read far more often than it is written.

## Simplicity (the prime directive)
- **YAGNI.** Build what was asked, not hypothetical futures. Over-engineering
  dressed as good practice is the #1 failure mode of generated code.
- **Reach for what exists** — the language/stdlib, then a dependency already in
  the project — before writing custom code or adding a new dependency.
- **Shortest clear diff wins.** Prefer editing over adding, deleting over
  editing, fewer moving parts — when the result reads just as well.
- **Boring over clever.** A plain solution readable at a glance beats a dense
  one-liner that needs a comment to decode.
- **Match the surrounding code** — its idioms, naming, structure — over imposing
  a "cleaner" pattern.

## Readability & organization
- **Guard clauses / early returns** for preconditions and errors; keep the main
  path at the lowest indentation, not buried in nested `if`s.
- **One level of abstraction per function.** Don't mix orchestration with
  low-level fiddling in one body.
- **Don't over-decompose.** Shattering a coherent flow into many tiny functions
  forces the reader to jump around and hurts readability as much as a giant
  function. Extract when a genuinely reusable, nameable unit emerges.
- **Order top-down** (newspaper rule): high-level entry points first, helpers
  below, each function near the ones it calls. Keep related code together.
- Soft limits, a second look when exceeded: function ≲ 40 lines, nesting ≤ 3,
  params ≤ 4 (else pass an object), line ≲ 100 cols.

## Naming
- Names reveal intent — infer purpose without reading the body.
- Verbs for functions (`calculateTax`), nouns for values (`taxRate`),
  affirmative booleans (`isValid`, not `notInvalid`).
- Length matches scope (`i` in a 3-line loop is fine; a field is not). No
  unexplained abbreviations. One term per concept across the codebase.
- **No magic numbers/strings** — name them as constants with context.

## Comments (why, not what)
- Default to **self-documenting code**. Tempted to comment *what* a block does?
  First try a better name or extracting a well-named function.
- Comment the **why**: rationale, trade-offs, gotchas, invariants, non-obvious
  assumptions, links to the spec/issue/REQ-ID.
- Public API gets a **contract** docstring (purpose, params, return, errors,
  side effects). Internal helpers usually need none.
- **Never:** comments that restate code, commented-out code (delete it — VCS
  remembers), decorative banners. A stale comment is worse than none.

## Reliability basics
- **Validate at boundaries**, trust inside.
- **Never swallow exceptions** — handle meaningfully or propagate with context.
  An empty `catch` is a hidden bug.
- Fail loud for programmer errors; fail gracefully for expected conditions.
(Deeper: idempotency, hidden state, concurrency, resources → reliability ref.)

## Don't trim these
Brevity stops at correctness. Never cut input validation at trust boundaries,
error/edge-case handling that prevents data loss, security, accessibility, or
anything explicitly requested. When clarity and brevity conflict, choose clarity.

## Avoid (LLM code smells)
Speculative generality; config/interfaces/factories for one case;
"manager/helper/util" grab-bags; hallucinated APIs (verify a call exists);
copy-paste duplication; silently skipped edge cases; catch-all error swallowing
"for robustness".

---

## Situational references (consult when relevant)
- **Designing modules, types, or abstractions** (SOLID, DRY/rule-of-three,
  composition vs inheritance, deep modules, illegal-states-unrepresentable) →
  `design-and-abstraction.md`
- **Stateful / IO / concurrent / retryable code** (idempotency, immutability,
  resource cleanup, concurrency) → `reliability.md`
- **Choosing what to test and what to assert** (boundary analysis, Right-BICEP,
  oracles, property-based & metamorphic testing) → `test-authoring-guide.md`
