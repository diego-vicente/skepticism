# Harness provenance

**When you need a fact the agent cannot bend, take it from the harness or from
git, never from a file the agent wrote.**

This note records why the completion gate shipped in 2.2.0 and was reverted, and
what to build instead. It is a design note, not a specification. Nothing here is
implemented.

## What 2.2.0 tried to do

The controller stops between phases when nothing blocks it — a nine-phase run
ends at step three with a summary that reads like completion. Claude Code has a
built-in answer, `/goal`, which runs a small evaluator after every turn and
starts another turn when a condition is not met.

`/goal` was rejected for one reason: its evaluator "doesn't run commands or read
files independently", so it judges the transcript. A framework built on
deterministic gates should not accept an evaluator that a *claim* about a gate
can satisfy. So 2.2.0 used a `Stop` hook of `type: "agent"`, which has tool
access, and had it verify the run's state file against artifacts on disk.

## Why it was wrong

Four defects made it inert, and three adversarial reviews found them
independently. The two that decided it:

- **`${CLAUDE_PLUGIN_ROOT}` does not expand in a `hooks:` frontmatter block.**
  The skills documentation substitutes it "in two places: the skill's markdown
  content, and Bash rules in the `allowed-tools` frontmatter." A hook prompt is
  neither, so the gate was handed a literal path and ran with no contract.
- **The gate allowed the stop in exactly the case it existed for.** Its contract
  said to allow a stop when the artifact confirms the phase passed and the state
  file has not caught up. A run that finishes phase 5 and stops *is* that case.
  It asked "is the claimed phase finished" when the failure is "the run ended
  before phase 7".

Two more worth recording. `stop_hook_active` stays true from the first block
until the user types again, so gating on it made the hook a one-shot that
rubber-stamped every later turn. And `last_assistant_message` is "the text
content" of the response, with no `tool_calls` field on `Stop`, so the rule that
protected an `AskUserQuestion` could never evaluate.

**The deeper error was the premise.** The gate read `det-gate.log`, `review.md`
and `state.md` — all written by the controller it was auditing. It converted a
claim in the transcript into a claim in a file and added no independent
measurement. `scripts/det-gate` ends with the literal line
`det-gate: all checks passed ✓`, which one `printf` reproduces.

**Worse, the gate created the incentive it could not detect.** Before it existed
the controller had no reason to produce a green log. A hook whose reason reads
"no det-gate.log exists, run scripts/det-gate" names the file to produce and the
string that satisfies the check. The measure became a target.

## The threat is confabulation, not deception

This distinction decides what is worth building. No agent forges a log out of
malice. What happens is a skipped step recorded as done, a stale run counted as
fresh, a subagent's "Critical" softened while summarising, and a gate run before
the last edit.

**A receipt defeats every one of those**, because an agent that did not run the
thing cannot produce an exit code and a matching `git rev-parse HEAD`. Against a
genuinely deceptive agent nothing local works, and the independent executor that
does work already exists: CI runs on a sha, on a machine the agent does not
control, and it is what actually blocks a merge.

## Three channels the controller cannot write

Each is populated by Claude Code or by git, before the controller sees it.

**`SubagentStop`.** Its input carries `agent_type`, `last_assistant_message` —
"the text content of the subagent's final response" — and
`agent_transcript_path`, the subagent's own transcript in a nested `subagents/`
folder. `agent_type` is the matcher field, so a hook can match
`reviewer-correctness` or `oracle-adversary` specifically. This is the strongest
channel available, and it covers the adversarial panel completely.

**`PostToolUse` on `Bash`.** The tool response comes from the harness rather
than from the agent's account of it, so a real exit code is readable. It covers
commands the controller runs directly, including `det-gate`. It is fiddlier,
because it means matching a command line to decide which calls matter.

**Git.** A sha cannot be faked without actually committing. Pairing any record
with `git rev-parse HEAD` turns "this passed" into "this passed on this tree",
which is the claim that matters after the next edit.

## What to build

**1. A verdict ledger, and nothing else at first.**

A `SubagentStop` command hook appends one line per adversary to
`.skepticism/runs/<slug>/verdicts.log`: the timestamp, `agent_type`, `agent_id`,
and the verdict from `last_assistant_message`. The controller never writes this
file. `review.md` then becomes checkable against it by string comparison — no
second model, no judgement, nothing to fool.

**This makes a forged review verdict structurally impossible rather than merely
detectable**, which is a better place to be than any amount of auditing.

Two things it must handle. Under `SubagentHandback`, which auto mode uses on
v2.1.271 or later, `last_assistant_message` holds closing text and the report
arrives as `tool_input.message` on a `PostToolUse` hook matched on
`SubagentHandback` — the ledger needs both paths. And the hook must fail open and
exit 0 on every error, like `gate-check` does, because a ledger that blocks a
turn is worse than a missing line.

**2. A sidecar for the deterministic gate.**

`scripts/det-gate` writes `det-gate.status` beside its log: the exit code, the
head sha, an ISO timestamp, and the per-check results. Treat a sha that is not
current `HEAD` as a stale run rather than a pass. Three lines in a script that
already exists, and it defeats confabulation, which is the real threat.

**3. Then, if the ledger shows it is needed, a `command` Stop hook.**

Every condition the 2.2.0 gate evaluated is a string in `state.md`, a field in
the hook input, or now a line in the ledger. A deterministic script is cheaper by
two orders of magnitude, adds no latency, survives agent hooks being withdrawn,
and is testable by the tier 0 harness this plugin already ships. **The completion
gate was the only component here with no deterministic test, and its contract was
81 lines of prose interpreted by a fast model — in a plugin whose thesis is that
prose gets rationalised away.**

Its rule should be the inverse of 2.2.0's: allow the stop only at `phase: done`,
at a hard gate, when `background_tasks` is not empty, or when the phase log
records a capped loop. Otherwise block with the next phase's first command as the
reason. Advancement is the product; verification is a bonus on top.

## What not to build

**Do not have the adversaries define the gate yet.** There is a real hole — the
controller both chooses what "passing" means and reports whether it passed — and
an elegant fix, where `oracle-adversary` names the passing command at approval
time and a `SubagentStop` hook records it. `red-check` already half-closes it by
verifying the project's own test run collects the new paths. Build it when the
ledger shows the hole being used, not before.

**Do not reproduce CI locally.** A local gate that re-verifies what CI verifies
on a sha is a weaker copy of a stronger system.

**Do not put this in user settings.** A settings-file hook fires in every session
on the machine. A plugin hook in `hooks/hooks.json` is registered on install,
survives a resumed run, and is scoped to projects using the plugin — which the
frontmatter route was not, because a skill hook registers only when the skill is
invoked and never re-registers on resume.
