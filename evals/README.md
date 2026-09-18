# `skepticism` evaluation harness

This directory verifies the plugin itself — applying the plugin's own doctrine to
its own machinery: **deterministic and ungameable first, expensive LLM judgment
second, and never a moot assertion.** The design is adapted from Anthropic's
`skill-creator` (trigger evals + A/B grading) and obra/`superpowers`' `quorum`
(scenario dirs + dual-witness grading of a real agent run).

## The three tiers

| Tier | What it proves | How | Cost / CI |
|------|----------------|-----|-----------|
| **0 — script tests** | The deterministic scripts (`gate-check`, `red-check`, `det-gate`, `leak-check`, `context-pack`, `state`, `consolidate`, `package-diff`) behave exactly as the phases depend on | `bash`+`python3` unit tests with fixtures & fake runners — no language runtimes needed | **CI-safe, fast, ~100% solid** |
| **1a — per-agent behavioral** | Each adversarial subagent catches the flaw it exists to catch, in isolation | Dispatch one subagent at a planted-flaw fixture; dual-witness grade | Needs API; **not CI** |
| **1b — full-workflow** | The controller chains the phases, wires the scripts, and holds Iron Rule 1 | Drive `/skeptic:coding` headlessly; assert on the session transcript | Needs API; slow; **not CI** |
| **2 — triggering** | Each skill fires on the right prompts and not on near-misses | Headless `claude -p`, inspect whether the skill was invoked | Needs API; **not CI** |

**Why the split:** Tier 0 is the ungameable spine and runs on every commit. The
LLM tiers are non-deterministic and cost real money, so — exactly like both
reference harnesses — they stay out of public CI and are run by hand or on an
eval host. Public CI must never carry API keys or live agent runs.

## Dual-witness grading (Tiers 1a/1b)

A scenario passes only if **both** witnesses agree:
1. **Deterministic** (`checks.sh` → `pre()`/`post()`): mechanical facts — verdict
   parsed as `fail`, working tree clean, files present, no source edited. Uses
   `lib/checks-lib.sh`.
2. **Semantic** (`lib/grade.md`, an LLM judge): the part grep can't judge — did it
   name the *right* flaw for the *right* reason? A `fail` verdict for the wrong
   reason still fails the eval.

`pre()` guards against a **moot eval**: it asserts the planted flaw is actually
present in the fixture, so a green result on a broken fixture can't sneak through.

## Layout

```
evals/
  run.sh                     # --tier0 | --validate | --ci | --scenarios | --triggering
  lib/
    assert.sh                # Tier-0 assertions
    checks-lib.sh            # deterministic check verbs for scenarios
    grade.md                 # the LLM-judge prompt (semantic witness)
  tier0-scripts/             # one test-*.sh per script; hermetic
                             #   leak-check's tests weigh false positives as
                             #   heavily as true ones — a transparency gate that
                             #   fires on a project's own prose would block
                             #   every run in that repo
  scenarios/<name>/
    eval.md                  # metadata + ## Acceptance Criteria (LLM-judged)
    story.md                 # (1b only) the scripted human-driver prompt
    setup.sh                 # builds the fixture in $SKEPTIC_WORKDIR
    checks.sh                # pre()/post() deterministic witnesses (sourced)
  triggering/
    coding-trigger-eval.json # 20 queries: should / should-not trigger
    spec-trigger-eval.json
    run-triggering.py        # headless claude -p classifier
```

## Running

### Tier 0 + validation (CI)
```sh
bash evals/run.sh --ci          # tier0 tests + static/fixture validation of the rest
bash evals/run.sh --tier0       # just the deterministic script tests
bash evals/run.sh --validate    # structure, bash -n, pre/post defined, fixtures build, JSON valid
```

## Running the behavioral evals (Tiers 1a / 1b — needs API)

These run a real agent and grade the result; run them from a Claude Code session
(so the controller can dispatch subagents) or an eval host. For one scenario:

1. Build the fixture:
   ```sh
   export PLUGIN_ROOT="$PWD" SKEPTIC_WORKDIR="$(mktemp -d)"
   bash evals/scenarios/<name>/setup.sh
   ```
2. Assert the fixture is sound: source `lib/checks-lib.sh` and the scenario's
   `checks.sh`, then run `pre` (must pass — the planted flaw is present).
3. **Run the subject.**
   - *1a:* dispatch the `agent:` named in `eval.md` at the fixture paths; save its
     final message to `$SKEPTIC_WORKDIR/verdict.txt`.
   - *1b:* drive `/skeptic:coding` with `story.md` headlessly, capturing the
     session transcript to `$SKEPTIC_WORKDIR/transcript.jsonl`:
     ```sh
     claude -p "$(cat evals/scenarios/<name>/story.md)" \
       --plugin-dir "$PWD" --output-format stream-json --verbose \
       --permission-mode bypassPermissions | tee "$SKEPTIC_WORKDIR/transcript.jsonl"
     ```
4. Grade: run `post` (deterministic witness) **and** grade the `## Acceptance
   Criteria` with `lib/grade.md` (semantic witness). Pass = both agree.

Because LLM runs vary, run each scenario a few times and treat the result as a
rate; `indeterminate` (fixture failed to build / empty transcript) is distinct
from `fail`.

## Running the triggering evals (Tier 2 — needs API + `claude` CLI)

```sh
python3 evals/triggering/run-triggering.py \
  --eval-set evals/triggering/coding-trigger-eval.json \
  --skill skeptic:coding --plugin-dir . --runs 3
python3 evals/triggering/run-triggering.py \
  --eval-set evals/triggering/spec-trigger-eval.json \
  --skill skeptic:spec --plugin-dir . --runs 3
```
Each query is fired `--runs` times; a query passes if its trigger-rate lands on
the correct side of `--threshold` (default 0.5). Reports precision/recall.

## CI

CI runs only the hermetic subset:
```sh
bash evals/run.sh --ci
```
It needs just `bash`, `python3`, and `git`. A GitHub Actions workflow is in
`.github/workflows/evals.yml`; on other hosts (e.g. tangled.org), wire that one
command into your CI. Keep the LLM tiers out of public CI.
