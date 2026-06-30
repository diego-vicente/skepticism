---
name: spec
description: "Use to turn a rough feature idea into an approved, verifiable specification. Explores the existing codebase and docs, asks the user clarifying questions one at a time, then writes a design doc plus EARS requirements and Given/When/Then acceptance criteria. Phase 1 of the skeptic coding workflow, but usable on its own."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Define spec

Produce a specification precise enough that tests can be derived from it
mechanically. A vague spec poisons every downstream phase — this is the highest
-leverage step in the whole workflow, so do not rush it.

## Process (do these in order)

1. **Explore context first.** Before asking anything, look at the codebase:
   relevant modules, existing conventions, similar features, tests, and any
   docs. Ground the conversation in what already exists so you ask sharp
   questions, not generic ones.

2. **Ask clarifying questions ONE AT A TIME.** Cover, as needed:
   - Purpose & the user/problem it serves
   - Exact behavior, including inputs, outputs, and state changes
   - Edge cases and failure modes (this is where agents under-specify)
   - Error handling: what should happen when things go wrong?
   - Boundaries: what is explicitly OUT of scope (YAGNI)?
   - Success criteria: how do we know it works?
   Stop asking once you can write criteria that two people could not reasonably
   disagree about. If you can't, you have more questions to ask.

3. **Propose 2–3 approaches** with trade-offs and a recommendation, when there
   is a real design choice. Let the user pick before you write the spec.

4. **Write `spec.md`** to `docs/skepticism/<feature-slug>/spec.md` using the
   template below.

5. **Self-review the spec** for placeholders, contradictions, vague words
   ("fast", "properly", "handle gracefully"), and untestable claims. Fix them.

6. **Ask the user to review and approve** the written file before anything
   downstream runs. Do not advance on implied approval.

## The spec format

Three layers: a design narrative (human-friendly), **EARS requirements** with
stable REQ-IDs (one unambiguous SHALL each), and **Given/When/Then** acceptance
criteria that cite the REQ-IDs they cover. The REQ-IDs flow downstream into test
comments, so coverage becomes mechanically checkable. See
`reference/spec-format.md` for the full notation; the template:

```markdown
# Spec: <feature name>

## Summary
One paragraph: what this is and why it exists.

## Context
What already exists, what this touches, links to relevant code/docs.

## Design
The chosen approach and the key decisions (and what was rejected, briefly).
Data shapes, interfaces, and module responsibilities.

## Out of scope
Explicit non-goals. What we are deliberately NOT building.

## Requirements (EARS)
One SHALL per requirement; pick the EARS pattern that fits:
- **REQ-1** — WHEN <trigger>, the system SHALL <response>.
- **REQ-2** — IF <unwanted condition>, THEN the system SHALL <response>.
- **REQ-3** — WHILE <state>, the system SHALL <response>.
- **REQ-4** — The system SHALL <always-true response>.  (ubiquitous)

## Acceptance criteria (Given/When/Then)
Each cites the REQ-ID(s) it covers. Cover happy paths, edges, AND errors.
- **AC1 — <name>** — covers REQ-1
  - Given <preconditions>
  - When <action / trigger>
  - Then <observable, specific result — exact values, messages, states>
- **AC2 — <edge case>** — covers REQ-3
  - Given … / When … / Then …
- **AC3 — <error / failure mode>** — covers REQ-2
  - Given … / When … / Then <exact error behavior: message, code, no-op, rollback>

## Open questions
Anything still unresolved (should be empty before approval).
```

## Rules for good requirements & criteria

- **One SHALL per requirement.** Split compound requirements; each REQ-ID is a
  single testable claim in an EARS pattern.
- **Specific & measurable.** Name exact values, messages, states. Ban "quickly",
  "properly", "as expected".
- **Pass-or-fail.** No middle ground; two independent reviewers reach the same
  verdict.
- **Cover failure first.** Agents get happy paths right on their own; the value
  is in pinning down edges and errors (the `IF/THEN` unwanted-behavior pattern).
- **Full coverage.** Every REQ-ID is cited by at least one AC. A requirement
  with no covering scenario is an incomplete spec.

Self-test each requirement and criterion: *could two reasonable people disagree
about whether this was satisfied?* If yes, rewrite it until they can't.
