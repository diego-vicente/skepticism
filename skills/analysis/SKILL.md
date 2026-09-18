---
name: analysis
description: "Use when answering a question from data and you want the answer verified adversarially. The analysis track of the skeptic flow: the oracle is a pre-registered hypothesis with a stated falsification criterion, agreed before you look at the outcome. Guards against the failure that matters most — deciding what counts as an answer after seeing the data."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite
---

# Skeptic — analysis track

Read `${CLAUDE_PLUGIN_ROOT}/skills/work/SKILL.md` first. It holds the phases,
the iron rules, the state file, the tiers, and the dispatch contract. This file
only supplies what the analysis track fills in. Set `track: analysis` in
`state.md`.

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
| Red check (phase 2 gate) | Run the frozen plan against a decoy. Valid RED = no answer appears. An answer on the decoy means the plan finds the conclusion in noise |
| Deterministic gate (phase 5) | `.skepticism/det-gate.sh` — rerun the notebook or script top to bottom from a clean kernel and require identical numbers, verify the data hash, lint the pipeline |
| Protected paths (phases 1–7) | The frozen plan and the raw data. Neither is edited after phase 3 |
| Perturbation catalog (phase 6) | Below |
| House rules for the builder | `Skill(manual-of-style:coding)` |

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
