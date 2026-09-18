---
description: Turns a rough idea into an approved, verifiable specification — a feature, a model to train, or a question to answer. Explores the existing work, asks clarifying questions one at a time, then writes a design doc plus EARS requirements and Given/When/Then acceptance criteria.
when_to_use: Writing or sharpening a spec, a PRD, or a design doc; adopting an existing one into the skeptic flow; phase 1 of every skeptic track, and usable on its own.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Define spec

Produce a specification precise enough that an oracle can be derived from it
mechanically. A vague spec poisons every downstream phase — this is the highest
-leverage step in the whole workflow, so do not rush it.

## Process (do these in order)

1. **Explore context first.** Before asking anything, look at what exists:
   relevant modules, conventions, similar work, the current oracle if there is
   one (a test suite, an evaluation, a prior analysis), and any docs. Ground the conversation in what already exists so you ask sharp
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

4. **Write `spec.md`** to `.skepticism/runs/<feature-slug>/spec.md` using the
   template below. If that directory doesn't exist yet, create it with
   `${CLAUDE_PLUGIN_ROOT}/scripts/state init <feature-slug> "<summary>"`, which
   also excludes `.skepticism/` from git locally — the spec is a working
   artifact and never reaches the remote.

5. **Self-review the spec** for placeholders, contradictions, vague words
   ("fast", "properly", "handle gracefully"), and untestable claims. Fix them.

6. **Ask the user to review and approve** the written file before anything
   downstream runs. Do not advance on implied approval.

## The spec format

Three layers: a design narrative for the human, **EARS requirements** with stable
REQ-IDs (one unambiguous SHALL each), and **Given/When/Then** acceptance criteria
that cite the REQ-IDs they cover. Downstream, the oracle-author maps each REQ-ID
to a runnable check in `coverage.md`, so coverage is mechanically checkable. The
REQ-IDs stay in the run's artifacts and never appear in code or comments.

**The template and the EARS patterns live in
`${CLAUDE_PLUGIN_ROOT}/reference/spec-format.md`. Read it before you write, and
copy the template from there.**

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

**Check each criterion against the track's oracle before you stop.** On the
coding track, ask whether a test could assert it. On the model track, ask
whether the held-out evaluation could measure it and what number counts as met.
On the analysis track, ask what result would falsify it. A criterion the track's
oracle cannot check is not yet a criterion — sharpen it or drop it.

Self-test each requirement and criterion: *could two reasonable people disagree
about whether this was satisfied?* If yes, rewrite it until they can't.
