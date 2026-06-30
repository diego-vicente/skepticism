# Reliability (situational reference)

Consult this when the code holds state, does IO, can be retried, or runs
concurrently — where correctness depends on more than the happy-path logic. The
always-on basics (validate at boundaries, never swallow exceptions, fail
loud/graceful) live in `coding-essentials.md`; this expands the rest.

## Error handling (deeper)
- **Validate at trust boundaries**, then trust the value inside. Don't scatter
  defensive re-checks through internal code — that's a sign the boundary leaked.
- **Never swallow exceptions.** No empty `catch`. Handle it meaningfully, or
  propagate it with added context (what you were doing, which input). A
  caught-and-ignored error is a hidden failure that surfaces far away.
- **Fail loudly and early** for programmer errors (bugs, broken invariants);
  **fail gracefully** for expected runtime conditions (bad user input, a network
  blip). The spec's error criteria tell you which is which — follow them.
- Don't catch-all "for robustness" — that converts a visible bug into silent
  data corruption.

## State
- **No hidden mutable state.** Prefer immutability and explicit data flow.
  Hidden global/temporal state (a value mutated somewhere far away, order-
  dependent behavior) is the source of the worst, least-reproducible bugs.
- Make state transitions explicit and few. If an object can be in an invalid
  intermediate state, see "make illegal states unrepresentable" in
  `design-and-abstraction.md`.

## Idempotency & retries
- If an operation may be retried (network calls, queue handlers, webhooks),
  make it **safe to retry** — dedupe by key, use upserts/conditional writes, or
  track applied operations.
- If it genuinely cannot be made idempotent, say so **loudly** in a comment and
  in the API contract.

## Concurrency
- Guard shared mutable state; prefer message-passing or immutable snapshots over
  shared locks where the language makes it natural.
- Beware check-then-act races (TOCTOU); make the check and the action atomic.
- Don't introduce concurrency the spec didn't ask for — it's a top source of
  heisenbugs (YAGNI applies here too).

## Resources
- Clean up files, connections, locks, handles **deterministically** — use the
  language's scope-based mechanism (`with`/`defer`/`try-with-resources`/RAII)
  rather than hoping a manual close runs on every path, including error paths.
