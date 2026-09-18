# Coding essentials (these always apply)

The always-on rules for writing and reviewing code in this workflow. Every
code-writing and code-reviewing agent reads this first. For topics that apply
only sometimes — design patterns, abstraction decisions, reliability/
concurrency, test strategy — consult the situational references listed at the
end *when the work calls for them*.

Favor the smallest change that solves the actual problem. Default to less code,
not more — but readable beats terse. The next reader (human or agent) is the
audience: code is read far more often than it is written.

**Sections:** Simplicity · Readability & organization · Naming · Comments (why,
not what) · Reliability basics · Security & dependencies · Scope & shape of the
change · Don't trim these · Avoid (LLM code smells) · Situational references.

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
- Length matches scope (`i` in a 3-line loop is fine; a field is not). Prefer
  full words; domain-standard abbreviations (`id`, `url`, `ctx`, `req`) are fine
  — the real enemy is single letters and cryptic ad-hoc shortenings. One term
  per concept across the codebase.
- **No magic numbers/strings** — name them as constants with context.

## Comments (why, not what)
- Default to **self-documenting code**. Tempted to comment *what* a block does?
  First try a better name or extracting a well-named function.
- Comment the **why**: rationale, trade-offs, gotchas, invariants, non-obvious
  assumptions.
- **No process references.** No requirement IDs, no phase or workflow names, no
  "as specified in AC3" — in code or in tests. Requirement traceability is kept
  outside the repository; a comment citing it is noise to every future reader
  and leaks how the code was produced. Explain the *why* in its own terms.
- Public API gets a **contract** docstring (purpose, params, return, errors,
  side effects). Internal helpers usually need none.
- **Never:** comments that restate code, commented-out code (delete it — VCS
  remembers), decorative banners. A stale comment is worse than none.

## Reliability basics
- **Validate at boundaries**, trust inside. Better: **parse, don't validate** —
  a checker returning `bool`/void throws away what it learned; return the
  narrowed type (or a `Result`) so the proof travels with the value and inner
  code needn't re-check.
- **Never swallow exceptions** — handle meaningfully or propagate with context.
  An empty `catch` is a hidden bug.
- Fail loud for programmer errors; fail gracefully for expected conditions.
- **Errors must be actionable** — an error/log line should let whoever hits it
  reproduce the failure: what was attempted, with which values, why it failed.
(Deeper: idempotency, hidden state, concurrency, resources, observability,
security → reliability ref.)

## Security & dependencies (always on for input / IO / dependency code)
- **Treat external input as hostile.** Parameterize every query — prepared
  statements for SQL; never string-build SQL, shell, or HTML from input. (Values
  parameterize; identifiers like table/column names do not — allowlist those.)
- **No secrets in source or logs.** Read keys/tokens/passwords from env or a
  secret manager; least privilege by default (narrowest scope the task needs).
- **Dependencies are liabilities.** Prefer stdlib → a dep already in the project
  → (last resort) a new one, vetted for maintenance health and license. A need
  of a few lines rarely justifies a package — but don't reinvent crypto/auth/TLS;
  a well-audited library beats bespoke there.
- **Never import a package you haven't verified exists.** Generated code invents
  plausible-but-fake names (measured ~1 in 5); a made-up name is a supply-chain
  hole (slopsquatting). Verify against the registry or don't add it.

## Scope & shape of the change
- **Don't mix a refactor with a behavior change.** Rename/move/reformat with
  behavior identical and tests still green; change behavior separately. A logic
  change buried in a wall of churn is exactly where bugs slip past review.
- **Keep the change scoped to the spec.** No drive-by cleanups or unrelated
  edits. The reviewer (human or agent) has a hard attention limit; a smaller,
  focused diff is verified far more reliably than a large one.

## Don't trim these
Brevity stops at correctness. Never cut input validation at trust boundaries,
error/edge-case handling that prevents data loss, security, accessibility, or
anything explicitly requested. When clarity and brevity conflict, choose clarity.

## Avoid (LLM code smells)
Speculative generality; config/interfaces/factories for one case;
"manager/helper/util" grab-bags; hallucinated APIs or packages (verify they
exist); copy-paste duplication; silently skipped edge cases; catch-all error
swallowing "for robustness"; string-built SQL/shell; hardcoded or logged
secrets; bundling an unrelated refactor into a behavior change.

---

## Situational references (consult when relevant)
- **Designing modules, types, or abstractions** (SOLID, DRY/rule-of-three,
  composition vs inheritance, deep modules, illegal-states-unrepresentable) →
  `design-and-abstraction.md`
- **Stateful / IO / concurrent / retryable / production code** (idempotency,
  immutability, resource cleanup, concurrency, observability, security defaults)
  → `reliability.md`
- **Choosing what to test and what to assert** (boundary analysis, Right-BICEP,
  oracles, property-based & metamorphic testing) → `test-authoring-guide.md`
