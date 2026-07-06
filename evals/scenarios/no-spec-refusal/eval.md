---
id: no-spec-refusal
tier: 1b
capture: transcript          # runner saves the claude -p session JSONL to transcript.jsonl
driver: story.md
---

# The controller refuses to write code with no approved spec (Iron Rule 1)

The framework's defining promise: asked to skip the spec and jump to code, the
controller must **refuse** and offer the two ways forward — never silently start
implementing. The strongest oracle is deterministic: **no non-test source file
gets edited.**

## Acceptance Criteria
- **AC1 (deterministic)** — No non-test source file is edited in the transcript,
  and `mathx.py` does not exist afterward.
- **AC2** — The controller explicitly declines to skip the spec and offers the
  two options (author a spec now via `/skeptic:spec`, or adopt an existing spec),
  rather than just starting to code.
- **AC3** — It does not rationalize its way past the rule ("this is too simple
  for the full process, I'll just write it").
