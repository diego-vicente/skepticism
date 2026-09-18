#!/usr/bin/env bash
# test-gate-check.sh — Tier 0. Unit-tests the PreToolUse hook enforcing the
# oracle-first gate — the spine of "no work before the oracle exists". A silent
# regression here (TEST_PATH_RE misclassifying a path, or the fail-open path
# breaking) would gut the framework's guarantee with no visible symptom.
#
# gate-check is pure: (stdin JSON, cwd state) → (exit 0, stdout). ALLOW = empty
# stdout; DENY = a JSON body with "permissionDecision":"deny". Both exit 0 (so a
# buggy hook can't brick editing) — hence we assert on stdout, not the exit code.
#
# Hermetic: builds a throwaway project dir, no language runtime needed.
set -uo pipefail

_ASSERT_NAME="gate-check"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
GATE="$PLUGIN_ROOT/scripts/gate-check"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-gatecheck.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# Set the single active run's phase (or clear it with `clear`).
set_phase() {
  rm -rf .skepticism docs/skepticism
  [[ "$1" == "clear" ]] && return
  mkdir -p .skepticism/runs/feat
  printf '# Skepticism run: feat\n\n- phase: %s\n' "$1" > .skepticism/runs/feat/state.md
}

# Set the phase AND a whole-run protected path list (the model track's
# held-out split). Protection must outlast the pre-work phases.
set_protected() {
  rm -rf .skepticism docs/skepticism
  mkdir -p .skepticism/runs/feat
  printf '# Skepticism run: feat\n\n- phase: %s\n- protected: %s\n' "$1" "$2" \
    > .skepticism/runs/feat/state.md
}

# Same, but under the pre-move layout — a run started before the directory
# unification must still be honoured until it finishes.
set_legacy_phase() {
  rm -rf .skepticism docs/skepticism
  mkdir -p docs/skepticism/feat
  printf '# Skepticism run: feat\n\n- phase: %s\n' "$1" > docs/skepticism/feat/state.md
}

# Send a payload and echo gate-check's stdout.
run_gate() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | python3 "$GATE"; }
run_raw()  { printf '%s' "$1" | python3 "$GATE"; }

# expect_deny <desc> <phase> <path>
expect_deny() { set_phase "$2"; local out; out="$(run_gate "$3")"; assert_contains "$1" "$out" "deny"; }
# expect_allow <desc> <phase> <path>
expect_allow() { set_phase "$2"; local out; out="$(run_gate "$3")"; assert_empty "$1" "$out"; }

# ── The gate BLOCKS source edits in every pre-implementation phase ───────────
expect_deny "spec phase blocks source edit"        spec        src/app.py
expect_deny "red-oracle phase blocks source edit"   red-oracle   lib/core.rs
expect_deny "oracle-review phase blocks source edit" oracle-review src/service.go

# ── The gate ALLOWS the things you MUST edit during those phases ─────────────
expect_allow "test file (tests/ dir) allowed"      oracle-review tests/test_core.py
expect_allow "test file (test_ prefix) allowed"    oracle-review test_core.py
expect_allow "test file (_test suffix) allowed"    oracle-review core_test.go
expect_allow "test file (.test. infix) allowed"    oracle-review src/app.test.ts
expect_allow "test file (.spec. infix) allowed"    oracle-review src/app.spec.js
expect_allow "test file (__tests__/) allowed"      oracle-review src/__tests__/x.js
expect_allow "test file (spec/ dir) allowed"       oracle-review spec/core_behaviour.rb
expect_allow "run's own spec.md allowed"           oracle-review .skepticism/runs/feat/spec.md
expect_allow "run's coverage.md allowed"           oracle-review .skepticism/runs/feat/coverage.md
expect_allow ".skepticism config allowed"          oracle-review .skepticism/red-check.sh

# ── Adversarial: 'test'/'spec' as a substring is NOT a test file → BLOCK ─────
# A naive substring match would wrongly ALLOW these and punch a hole in the gate.
expect_deny "source with 'test' substring blocked" oracle-review src/latest.py
expect_deny "source named contest.py blocked"      oracle-review src/contest.py
expect_deny "source with 'spec' substring blocked" oracle-review src/respect.py

# ── The gate is INACTIVE once past the pre-impl phases ───────────────────────
expect_allow "work phase allows source edit"       work        src/app.py
expect_allow "report phase allows source edit"     report      src/app.py

# ── No active run anywhere → never interfere with normal work ────────────────
expect_allow "no active run allows anything"       clear       src/app.py

# ── A run left under the pre-move layout is still honoured ───────────────────
set_legacy_phase oracle-review
out="$(run_gate src/app.py)"
assert_contains "legacy run dir still blocks source"  "$out" "deny"
out="$(run_gate docs/skepticism/feat/spec.md)"
assert_empty    "legacy run's own artifacts allowed"  "$out"

# ── A protected path stays blocked in EVERY phase, not just the early ones ──
# This is the model track's leakage guard: nothing in the work writes to the
# held-out split, so the denial must survive into phase 4 and beyond.
mkdir -p data
touch data/test.parquet data/train.parquet

set_protected work "data/test.parquet"
out="$(run_gate data/test.parquet)"
assert_contains "protected split blocked during work phase"   "$out" "deny"
out="$(run_gate data/train.parquet)"
assert_empty    "unprotected sibling still allowed"           "$out"

set_protected report "data/test.parquet"
out="$(run_gate data/test.parquet)"
assert_contains "protected split blocked at report phase"     "$out" "deny"

# A directory pattern protects everything under it.
mkdir -p data/holdout/nested
touch data/holdout/nested/rows.parquet
set_protected work "data/holdout"
out="$(run_gate data/holdout/nested/rows.parquet)"
assert_contains "protected directory covers nested files"     "$out" "deny"

# An empty or placeholder `- protected:` must protect nothing.
set_protected work ""
out="$(run_gate data/test.parquet)"
assert_empty    "empty protected list protects nothing"       "$out"

# ── Fail-open: a buggy/absent payload must NEVER block editing ───────────────
set_phase oracle-review
out="$(run_raw 'not valid json')";      assert_empty "malformed JSON fails open" "$out"
out="$(run_raw '{"tool_input":{}}')";   assert_empty "missing file_path fails open" "$out"
out="$(run_raw '{}')";                  assert_empty "empty object fails open" "$out"

summary
