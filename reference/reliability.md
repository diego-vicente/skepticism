# Reliability (situational reference)

Consult this when the code holds state, does IO, can be retried, runs
concurrently, crosses a trust boundary, or has to be operated in production —
where correctness depends on more than the happy-path logic. The always-on
basics (validate at boundaries, never swallow exceptions, fail loud/graceful,
security & dependency essentials) live in `coding-essentials.md`; this expands
the rest.

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

## Observability
- **Structured logs, not prose.** Emit key/value or JSON carrying context — a
  correlation/request id, the operation, the relevant inputs — so logs can be
  sliced during an incident. Concatenated prose can't be aggregated.
- **Actionable errors** (the operator's side of "propagate with context"): the
  line should let whoever is on call reproduce the failure without adding more
  logging.
- For a service, make the failure paths and the golden signals (latency,
  traffic, errors, saturation) observable *before* shipping, not after the first
  outage.
- **Don't log secrets or PII**, and don't "log everything" — verbose/high-
  cardinality logging costs money and leaks data. Log the right fields. (Log4Shell
  was triggered by logging attacker-controlled input.)

## Security defaults
The always-on rules — treat input as hostile, parameterize queries (values, not
identifiers — allowlist those), no secrets in source/logs, least privilege,
don't roll your own crypto/auth/TLS — are the single source in
`coding-essentials.md`. In stateful/production code, add only the depth beyond
them:
- The parameterization gap extends to **LDAP** and `ORDER BY` direction, not just
  SQL/shell/HTML — anywhere untrusted input reaches an interpreter needs the same
  values-parameterize-but-identifiers-must-be-allowlisted treatment.
- **Rotate on exposure.** Treat any secret that ever landed in VCS history or a
  log as compromised and rotate it — deleting the line is not enough.
