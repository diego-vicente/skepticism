#!/usr/bin/env bash
# test-state.sh — Tier 0. The `state` helper scaffolds the run directory and is
# deliberately tiny, but two properties matter: it must be IDEMPOTENT (re-running
# `init` on an existing run must NOT clobber the controller's edits — the state
# file is the source of truth across compaction), and its path accessors must be
# stable (subagent prompts are built from them).
set -uo pipefail

_ASSERT_NAME="state"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
STATE="$PLUGIN_ROOT/scripts/state"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-state.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

path="$(bash "$STATE" init feat "add login")"; rc=$?
assert_eq            "init exits 0"                     0 "$rc"
assert_eq            "init prints the state path"       "docs/skepticism/feat/state.md" "$path"
assert_file          "init creates state.md"            "$path"
assert_file_contains "template seeds phase: spec"       "$path" "phase: spec"
assert_file_contains "template records the feature"     "$path" "add login"

# Idempotency: a controller edit must survive a second init.
printf '\nCONTROLLER-EDIT\n' >> "$path"
path2="$(bash "$STATE" init feat "add login")"
assert_eq            "re-init returns the same path"    "docs/skepticism/feat/state.md" "$path2"
assert_file_contains "re-init did NOT clobber edits"    "$path" "CONTROLLER-EDIT"
edits=$(grep -c 'phase: spec' "$path")
assert_eq            "re-init did NOT duplicate template" 1 "$edits"

assert_eq "path accessor is stable" "docs/skepticism/feat/state.md" "$(bash "$STATE" path feat)"
assert_eq "dir accessor is stable"  "docs/skepticism/feat"          "$(bash "$STATE" dir feat)"

( bash "$STATE" bogus feat >/dev/null 2>&1 ); assert_eq "unknown command exits 2" 2 "$?"

summary
