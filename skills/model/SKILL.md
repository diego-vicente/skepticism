---
name: model
description: "Use when training, tuning, or evaluating a machine-learning model and you want the result verified adversarially. The model track of the skeptic flow: the oracle is a held-out evaluation plus a baseline the current model does not beat. Guards against the failure that matters most — leakage, a metric that does not measure the goal, and tuning on the test set."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite
---

# Skeptic — model track

Read `${CLAUDE_PLUGIN_ROOT}/skills/work/SKILL.md` first. It holds the phases,
the iron rules, the state file, the tiers, and the dispatch contract. This file
only supplies what the model track fills in. Set `track: model` in `state.md`.

## The oracle is a held-out evaluation and a baseline

Phase 2 builds the evaluation before any model is trained, and proves it is red:
**the baseline scores below the target on the held-out set.** That is the same
red as a failing test. If a trivial baseline already reaches the target, the
goal is wrong or the metric is, and phase 2 sends it back.

The oracle is five artefacts, and all five are frozen before phase 4 starts:

1. **The split.** Train, validation, and a held-out test set, split by the unit
   that matters — by entity, by time, or by group, never at random when rows
   share a subject. Record the split rule and the row counts.
2. **The metric.** One primary metric that answers the goal, with the decision
   threshold it implies. Secondary metrics are reported, never optimised.
3. **The baseline.** The cheapest thing that could work — a constant, the
   majority class, last week's value, the existing model. A result that does not
   beat it is not a result.
4. **The target.** The number that makes the work worth shipping, agreed with
   the user in phase 1 and stated as a requirement.
5. **The uncertainty.** How the score will be bounded — a confidence interval,
   a seed sweep, or cross-validation — so a gain inside the noise is visible as
   noise.

## What the track supplies

| Hook | Value |
|---|---|
| Oracle-authoring reference | `${CLAUDE_PLUGIN_ROOT}/reference/oracles.md`, the *Trained model* section |
| Red check (phase 2 gate) | Run the evaluation against the baseline. Valid RED = the baseline scores below target. A baseline that already hits target means a broken oracle, not a finished job |
| Deterministic gate (phase 5) | `.skepticism/det-gate.sh` — rerun the evaluation from a fixed seed and require the same number, verify the data hash is unchanged, lint and typecheck the pipeline |
| Protected paths (phases 1–7) | **The held-out split, for the whole run.** Not only until phase 3 |
| Perturbation catalog (phase 6) | Below |
| House rules for the builder | `Skill(manual-of-style:coding)` |

## The held-out split is protected for the entire run

This is the one rule that differs in shape from the coding track. Source files
unlock at phase 4 because the builder must write them. **The test split never
unlocks, because nothing in the work legitimately writes to it.** Add its path
to the run's protected list in phase 0 and leave it there. Prose asking a model
not to look at the test set gets rationalised away; a denied write does not.

## Perturbations (phase 6)

The model analogue of flipping `>` to `>=`. Each one asks whether the oracle
would notice a defect. Run the cheap ones first and revert every change.

- **Shuffle the labels.** Retrain on permuted labels. The score must collapse to
  the baseline. If it does not, the evaluation is broken and every number above
  it is meaningless. Run this one first, always.
- **Ablate a feature.** Drop a feature the model is supposed to use. If the
  metric does not move, the feature is decorative — or the model found a
  shortcut.
- **Permute one column.** Shuffle a single feature across rows at evaluation
  time. A feature whose permutation costs nothing is not being used.
- **Shift the split.** Re-split on a different seed or a different time
  boundary. A result that survives only one split is a result about that split.
- **Duplicate-row probe.** Check whether any held-out row also appears in train,
  by exact match and by near-duplicate. A hit is leakage, not a perturbation.

## What `reviewer-oracle-integrity` audits here

It is a leakage auditor on this track. It asks whether the held-out split was
read or written during phase 4, whether the metric definition or threshold
changed after the baseline was recorded, whether hyperparameters were selected
on test rather than validation, whether any feature encodes the target directly
or through a proxy, and whether the reported number came from the frozen
evaluation or from a rerun with different settings.
