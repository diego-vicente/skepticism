---
name: coding
description: "Use when building a feature, fixing a non-trivial bug, or changing behaviour in code and you want the work verified adversarially. The coding track of the skeptic flow: the oracle is a test suite that fails before the code exists. Runs spec → failing tests → adversarial test review → implement → adversarial code review → report."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, TodoWrite
---

# Skeptic — coding track

Read `${CLAUDE_PLUGIN_ROOT}/skills/work/SKILL.md` first. It holds the phases,
the iron rules, the state file, the tiers, and the dispatch contract. This file
only supplies what the coding track fills in. Set `track: coding` in `state.md`.

## The oracle is a failing test suite

A test written from the spec, failing because the implementation is missing.
Nothing else counts. The three oracle conditions land as:

1. **It fails now** — the suite fails on an assertion, not on an import error.
2. **It can be wrong** — a plausible bug in the implementation would make it
   fail. `reference/test-quality-rubric.md` is how the adversary judges that.
3. **It is outside the builder's reach** — the tests are approved in phase 3 and
   committed, so `reviewer-oracle-integrity` can diff what the builder touched.

## What the track supplies

| Hook | Value |
|---|---|
| Oracle-authoring reference | `${CLAUDE_PLUGIN_ROOT}/reference/test-authoring-guide.md` |
| Oracle-quality rubric | `${CLAUDE_PLUGIN_ROOT}/reference/test-quality-rubric.md` |
| Red check (phase 2 gate) | `${CLAUDE_PLUGIN_ROOT}/scripts/red-check <test-path>...` |
| Deterministic gate (phase 5) | `${CLAUDE_PLUGIN_ROOT}/scripts/det-gate <base_ref>` — leak, lint, format, typecheck, suite, docs |
| Protected paths (phases 1–3) | Source files. `scripts/gate-check` allows edits to tests and to `.skepticism/` throughout |
| Perturbation catalog (phase 6) | `${CLAUDE_PLUGIN_ROOT}/reference/mutation-operators.md` |
| House rules for the builder | Whatever `project.md` names under *Code conventions to follow* |

## Track notes

**Prefer a real mutation tester over the `perturbation-adversary`.** Stryker for
JavaScript and TypeScript, mutmut or cosmic-ray for Python, PIT for Java,
cargo-mutants for Rust, go-mutesting for Go. When one is configured, skip the
subagent entirely — it is the language-model approximation of a tool you now
have. Configure it in `.skepticism/det-gate.sh` if you want it enforced.

**Coverage percentage is not a substitute.** A suite can execute every line and
kill no mutants.
