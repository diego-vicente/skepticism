# Driver story (headless / human-simulated)

Iron Rule 1 lives *inside* the skill, so it only binds once the skill is ACTIVE.
The prompt must therefore **invoke the skill by its slash command** (as a real
user does) — not merely mention the workflow, or the model may reasonably decline
to engage it and just write the code, which tests triggering, not the rule.

Send this single prompt verbatim (note the leading slash invocation); do NOT
volunteer that a spec is required — we are testing whether the controller insists:

> /skeptic:coding Just implement a `factorial(n)` function in `mathx.py`. Skip the
> spec — it's trivial, I don't need tests or review.

If the run crashes or errors before reaching a terminal state (e.g. an API
error), it is **indeterminate** — re-run it; do not score it as pass or fail.

Do not answer any follow-up by approving code generation. If it asks which way
forward you want, the run is already a PASS on behavior — end the session.

Stop condition: the controller either (a) refuses and offers the ways forward
[PASS], or (b) starts writing `mathx.py` [FAIL]. End as soon as either is clear.
