# The completion gate

The contract for the `Stop` hook that the track skills register. The hook is an
**agent hook**, so unlike a prompt hook it has tool access and can check a claim
against the filesystem rather than believe the transcript.

Its job is one decision, made after every turn: **has this run stopped for a
good reason?**

## Opt in per run

The gate is off unless the run says otherwise. Read
`.skepticism/runs/*/state.md` and look for `autopilot:`.

- **No state file, or no active run** → `{"ok": true}`. The user is not in a
  skeptic run and this gate has no business in their turn.
- **`autopilot: off`, or the field is absent** → `{"ok": true}`. This is the
  default. The controller asks once in phase 0 and records the answer.
- **`autopilot: on`** → continue below.

## Always allow the stop

Return `{"ok": true}` immediately on any of these. Each is a turn that ended for
a reason the gate must not override.

1. **`stop_hook_active` is true.** The turn is already continuing because of this
   hook. Claude Code ends the turn anyway after 8 consecutive blocks; do not
   spend the budget.
2. **`background_tasks` is not empty.** A subagent, a background command, or a
   monitor is still running. The work is waiting, not stalled.
3. **The last assistant message called `AskUserQuestion` or `ExitPlanMode`.**
   The agent needs the user. Pushing it past this makes it answer its own
   question, which is worse than stopping early.
4. **The run is at a hard gate.** `phase: goal` and `phase: oracle-review` both
   end with the user approving. Iron Rule 1 outranks this gate.
5. **`phase: done`.**

## Verify the phase, then decide

For every other phase, check the claim the state file makes against what is on
disk. This is the part a prompt hook cannot do.

| Phase | What must be true to advance | Where to look |
|---|---|---|
| `red-oracle` | The oracle exists and fails for the right reason | `oracle-report.md`, and the track's red check |
| `work` | The oracle passes | The track's test or evaluation command |
| `det-gate` | The gate ran and exited 0 | `det-gate.log` — it must exist, and its last verdict line must say every check passed |
| `review` | Every dispatched reviewer returned, with no open Critical or Important finding | `review.md` |
| `report` | The phase log is complete and `INDEX.md` has the digest | `state.md`, `.skepticism/INDEX.md` |

**Prefer reading an artifact over re-running a command.** The flow writes
`det-gate.log`, `oracle-report.md` and `review.md` precisely so this check is
cheap. Re-run a command only when the artifact is missing or older than the last
commit, and never re-run a full test suite — the point is to catch a phase that
claimed to pass without running, not to run it a second time.

**Return `{"ok": false, "reason": "..."}` when the phase is genuinely
unfinished.** The reason becomes the agent's next instruction, so name the phase,
name what is missing, and name the one command that would produce it. "Phase
det-gate: no det-gate.log exists. Run scripts/det-gate <base_ref> from the repo
root." A vague reason produces a vague next turn.

**Return `{"ok": true}` when the artifact confirms the phase passed** and the
state file simply has not been updated yet. That is bookkeeping, not unfinished
work, and the next turn will write it.

## Know when to give up

An agent hook has no `impossible` field, so it cannot end a run the way `/goal`
can. Approximate it: when the same phase has failed the same check on three
consecutive turns, return `{"ok": true}` with a reason saying the run is stuck
and naming the check. The turn then ends and the user sees it, which is the
outcome they need. Looping until the 8-block cap wastes seven turns to reach the
same place.

## What this gate is not

It does not judge whether the work is good. The adversarial panel does that in
phase 6, in isolated contexts, against a prepared diff. This gate only asks
whether the phase the state file claims is actually finished. Keep it mechanical;
an opinion here duplicates the panel and carries none of its isolation.
