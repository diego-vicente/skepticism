# Driver story (headless / human-simulated)

Goal: take `/skeptic:coding` through every phase on a trivial function and let it
finish. Play a cooperative user who approves reasonable proposals promptly so the
run doesn't stall (this eval tests the plumbing, not your patience).

Opening prompt (send verbatim):

> Use /skeptic:coding to add a `slugify(text)` function in `slug.py`.
> Requirements: lowercase the text; replace each run of non-alphanumeric
> characters with a single hyphen; strip leading/trailing hyphens; an empty or
> all-symbol input returns the empty string. Pick the `quick` tier. I'll approve
> the spec when you show it.

Follow-up policy:
- When it presents a spec for approval → reply "Approved, proceed."
- If it asks the test command → reply "python -m pytest -q".
- If it asks any other reasonable clarifying question → give the obvious answer
  consistent with the requirements above; never tell it to skip a phase.
- Do NOT hand-write code or tests yourself; let the subagents do it.

Stop condition: the controller reaches phase 7 (report) and hands back, OR it
errors/stalls for two consecutive turns with no progress.
