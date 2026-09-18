---
description: The analysis track of the skeptic adversarial flow: the oracle is a pre-registered hypothesis with a stated falsification criterion, frozen before the outcome is visible. Guards against deciding what counts as an answer after seeing the data.
when_to_use: Answering a question from data, running an experiment or an A/B readout, or checking a finding before it is acted on — "does the data support this", "is this effect real", "pre-register this analysis".
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite
hooks:
  Stop:
    - hooks:
        - type: agent
          timeout: 120
          prompt: |
            Read ${CLAUDE_PLUGIN_ROOT}/reference/completion-gate.md and apply it
            to this Stop event, then return only its JSON verdict.
            Hook input: $ARGUMENTS
---

# Skeptic — analysis track

Read `${CLAUDE_PLUGIN_ROOT}/skills/work/SKILL.md` first, then apply this file.
Set `track: analysis` in `state.md`.

## The oracle is a pre-registered hypothesis

Exploratory work has no failing test to turn green, so the oracle is a written
commitment made before the outcome is visible: **what you expect, how you will
measure it, and the result that would make you abandon the claim.**

Phase 2 writes that commitment and proves it is red in the only sense available
here — **the analysis plan runs end to end on a decoy and produces no answer.**
Run it on shuffled outcomes, on a holdout you will not use, or on the first ten
percent of the period. If the plan already yields the conclusion on a decoy, the
plan finds that conclusion in noise, and phase 2 sends it back.

The oracle is four things, frozen before phase 4:

1. **The claim.** One sentence that could be false.
2. **The measurement.** The exact quantity, the population, the time window, and
   the exclusions — written before you compute it.
3. **The falsification criterion.** The result that would make you say no. An
   analysis with no such result is not an analysis.
4. **The decision.** What changes depending on the answer. An analysis nobody
   acts on does not need this framework.

**A hard gate this track adds: the deliverable is the answer, not the preferred
answer.** Record in `coverage.md` every question you asked the data and every
cut you tried. A conclusion reached on the fourteenth cut is a different claim
from one reached on the first, and the reader needs to know which.

## What the track supplies

| Hook | Value |
|---|---|
| Oracle-authoring reference | `${CLAUDE_PLUGIN_ROOT}/reference/oracles.md`, the *Analysis* section |
| Oracle-quality rubric | `${CLAUDE_PLUGIN_ROOT}/reference/oracles.md`, *The rubric the adversary judges against* |
| Red check (phase 2 gate) | Run the frozen plan against a decoy. Valid RED = no answer appears. An answer on the decoy means the plan finds the conclusion in noise |
| Deterministic gate (phase 5) | `.skepticism/det-gate.sh` — rerun the notebook or script top to bottom from a clean kernel and require identical numbers, verify the data hash, lint the pipeline |
| Protected paths (phases 1–7) | The frozen plan and the raw data. Neither is edited after phase 3 |
| Perturbation catalog (phase 6) | Below |
| House rules for the builder | Whatever `project.md` names under *Code conventions to follow* |

## Perturbations (phase 6)

- **Shuffle the outcome.** The effect must vanish. If it survives, the pipeline
  manufactures it.
- **Drop the largest group.** An effect carried entirely by one segment is a
  claim about that segment.
- **Move the window.** Shift the period by one unit. A result that only holds on
  one window is a result about that window.
- **Change one arbitrary choice.** A bin edge, an outlier rule, a join key. Each
  arbitrary choice you made is a place the answer could have been different.
- **Count the cuts.** Compare the number of comparisons actually run against the
  number the plan declared. Every undeclared extra cut inflates the chance that
  the finding is noise.

## What `reviewer-oracle-integrity` audits here

It asks whether the claim, the measurement, or the exclusions changed after the
data was seen, whether the falsification criterion was weakened, whether the
reported cut is the one the plan declared, and whether `coverage.md` lists every
cut that was tried.
