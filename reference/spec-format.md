# Spec format reference

The canonical artifact produced by the `spec` skill and consumed by every
downstream phase. Three layers, each feeding the next:

1. **Requirements** in **EARS** notation, each with a stable `REQ-ID`.
2. **Acceptance criteria** as **Given/When/Then** scenarios, each citing the
   `REQ-ID`s it exercises.
3. **Traceability**: a `coverage.md` artifact maps each `REQ-ID` and criterion to
   a runnable **test node ID**, so coverage (requirement → scenario → test) is
   *mechanically* checkable, not a judgment call. This is what lets the
   oracle-adversary verify completeness objectively.

REQ-IDs live in `spec.md` and `coverage.md` — both inside the run directory,
which never reaches the remote. They must **not** appear in production code or
test files (Iron Rule 6); a repo carries its own history, not the process that
produced it.

Why these choices: **EARS** forces each requirement into one unambiguous,
testable claim (the same notation AWS Kiro uses), removing the drift that lets an
agent "technically satisfy" a vague spec; **Given/When/Then** is the
human-readable scenario layer. Do **not** use full Gherkin/Cucumber — its
step-definition glue rots; derive runnable acceptance tests from the REQ-IDs
instead.

## EARS patterns (use the one that fits)

- **Ubiquitous** (always true): `The <system> SHALL <response>.`
- **Event-driven**: `WHEN <trigger>, the <system> SHALL <response>.`
- **State-driven**: `WHILE <in some state>, the <system> SHALL <response>.`
- **Optional feature**: `WHERE <feature is included>, the <system> SHALL <response>.`
- **Unwanted behavior**: `IF <unwanted condition>, THEN the <system> SHALL <response>.`
- **Complex**: combine the above, e.g. `WHILE <state>, WHEN <trigger>, the
  <system> SHALL <response>.`

Keep each requirement to a single SHALL. Split compound requirements.

## Template

```markdown
# Spec: <feature name>

## Summary
One paragraph: what this is and why it exists.

## Context
What already exists, what this touches, links to relevant code/docs.

## Design
The chosen approach and key decisions (and what was rejected, briefly).
Data shapes, interfaces, module responsibilities.

## Out of scope
Explicit non-goals — what we are deliberately NOT building (YAGNI boundary).

## Requirements (EARS)
- **REQ-1** — WHEN a user submits valid credentials, the system SHALL issue a
  session token and redirect to /dashboard.
- **REQ-2** — IF the password is invalid, THEN the system SHALL return HTTP 401
  with message "invalid credentials" and SHALL NOT issue a token.
- **REQ-3** — WHILE an account is locked, the system SHALL reject all login
  attempts with HTTP 423.
- **REQ-4** — The system SHALL store password hashes using <algorithm>; it
  SHALL NOT store plaintext passwords.

## Acceptance criteria (Given/When/Then)
- **AC1 — successful login** — covers REQ-1
  - Given a registered user with a valid password
  - When they submit correct credentials
  - Then the response is 200 with a session token AND a redirect to /dashboard
- **AC2 — wrong password** — covers REQ-2
  - Given a registered user
  - When they submit an incorrect password
  - Then the response is 401 "invalid credentials" AND no token is issued
- **AC3 — locked account (edge)** — covers REQ-3
  - Given an account in the locked state
  - When any login is attempted
  - Then the response is 423 regardless of credential correctness

## Open questions
Should be empty before approval.
```

## The coverage map (`coverage.md`)

Written by the oracle-author in phase 2, verified by the oracle-adversary in phase 3,
re-checked by `reviewer-oracle-integrity` in phase 6. It is the only place
requirement traceability is recorded.

```markdown
# Coverage map: <slug>

| REQ / AC | Test node ID | Status |
|---|---|---|
| REQ-1 | tests/test_login.py::test_issues_token_on_valid_credentials | covered |
| REQ-2 | tests/test_login.py::test_rejects_invalid_password | covered |
| AC3   | tests/test_login.py::test_rejects_when_locked | deferred |

## Deferred (accepted coverage gaps)
- AC3 — needs a seeded locked-account fixture (~40s per run) — we lose the
  lockout-path assertion entirely — accepted by user on 2026-07-27
```

Two properties make this stronger than the comments it replaces:
- **Node IDs are runnable.** A claim of coverage can be executed, not just read.
  A reviewer resolves `path::test_name` and checks what it actually asserts.
- **Gaps are explicit.** A criterion may be deferred *only* by a user decision
  recorded here. An undeclared gap is a critical finding, and moving a criterion
  to `deferred` after phase 3 approval is an integrity violation.

## Quality bar
- **Requirements:** one SHALL each; an EARS pattern chosen deliberately; every
  requirement has a REQ-ID; covers happy path, edges, errors, and security/
  data constraints.
- **Criteria:** specific & measurable (no "fast"/"properly"/"gracefully");
  pass-or-fail; one concern each; every AC cites the REQ-ID(s) it covers.
- **Coverage:** every REQ-ID is referenced by at least one AC. An EARS
  requirement with no covering scenario is an incomplete spec.

Self-test each requirement and criterion: *could two reasonable people disagree
about whether this was satisfied?* If yes, rewrite it.
