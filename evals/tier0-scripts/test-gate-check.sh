#!/usr/bin/env bash
# test-gate-check.sh — Tier 0. Unit-tests the PreToolUse hook enforcing the
# test-first gate — the spine of "no code before the tests exist". A silent
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
  if [[ "$1" == "clear" ]]; then rm -rf docs/skepticism; return; fi
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
expect_deny "red-tests phase blocks source edit"   red-tests   lib/core.rs
expect_deny "test-review phase blocks source edit" test-review src/service.go

# ── The gate ALLOWS the things you MUST edit during those phases ─────────────
expect_allow "test file (tests/ dir) allowed"      test-review tests/test_core.py
expect_allow "test file (test_ prefix) allowed"    test-review test_core.py
expect_allow "test file (_test suffix) allowed"    test-review core_test.go
expect_allow "test file (.test. infix) allowed"    test-review src/app.test.ts
expect_allow "test file (.spec. infix) allowed"    test-review src/app.spec.js
expect_allow "test file (__tests__/) allowed"      test-review src/__tests__/x.js
expect_allow "test file (spec/ dir) allowed"       test-review spec/core_behaviour.rb
expect_allow "run's own spec.md allowed"           test-review docs/skepticism/feat/spec.md
expect_allow ".skepticism config allowed"          test-review .skepticism/red-check.sh

# ── Adversarial: 'test'/'spec' as a substring is NOT a test file → BLOCK ─────
# A naive substring match would wrongly ALLOW these and punch a hole in the gate.
expect_deny "source with 'test' substring blocked" test-review src/latest.py
expect_deny "source named contest.py blocked"      test-review src/contest.py
expect_deny "source with 'spec' substring blocked" test-review src/respect.py

# ── The gate is INACTIVE once past the pre-impl phases ───────────────────────
expect_allow "implement phase allows source edit"  implement   src/app.py
expect_allow "report phase allows source edit"     report      src/app.py

# ── No active run anywhere → never interfere with normal work ────────────────
expect_allow "no active run allows anything"       clear       src/app.py

# ── Fail-open: a buggy/absent payload must NEVER block editing ───────────────
set_phase test-review
out="$(run_raw 'not valid json')";      assert_empty "malformed JSON fails open" "$out"
out="$(run_raw '{"tool_input":{}}')";   assert_empty "missing file_path fails open" "$out"
out="$(run_raw '{}')";                  assert_empty "empty object fails open" "$out"

summary
