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

STATE_PATH=".skepticism/runs/feat/state.md"

WORK="$(mktemp -d -t skeptic-state.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

path="$(bash "$STATE" init feat "add login")"; rc=$?
assert_eq            "init exits 0"                     0 "$rc"
assert_eq            "init prints the state path"       "$STATE_PATH" "$path"
assert_file          "init creates state.md"            "$path"
assert_file_contains "template seeds phase: goal"       "$path" "phase: goal"
assert_file_contains "template records the feature"     "$path" "add login"
assert_file_contains "template carries base_ref"        "$path" "base_ref:"
assert_file_contains "template carries plugin_root"     "$path" "plugin_root:"

# Idempotency: a controller edit must survive a second init.
printf '\nCONTROLLER-EDIT\n' >> "$path"
path2="$(bash "$STATE" init feat "add login")"
assert_eq            "re-init returns the same path"    "$STATE_PATH" "$path2"
assert_file_contains "re-init did NOT clobber edits"    "$path" "CONTROLLER-EDIT"
edits=$(grep -c 'phase: goal' "$path")
assert_eq            "re-init did NOT duplicate template" 1 "$edits"

assert_eq "path accessor is stable" "$STATE_PATH"     "$(bash "$STATE" path feat)"
assert_eq "dir accessor is stable"  ".skepticism/runs/feat" "$(bash "$STATE" dir feat)"

( bash "$STATE" bogus feat >/dev/null 2>&1 ); assert_eq "unknown command exits 2" 2 "$?"

# ── protect: the run dir must be excluded LOCALLY, never via .gitignore ───────
# Writing `.skepticism/` into .gitignore would commit a reference to the
# framework — the exact thing Iron Rule 6 forbids — so it goes in
# .git/info/exclude, which is per-clone and never pushed.
GITREPO="$WORK/repo"
mkdir -p "$GITREPO" && cd "$GITREPO"
git init -q .
git config user.email eval@skepticism.test
git config user.name  "Eval Harness"

bash "$STATE" init feat "add login" >/dev/null 2>&1
assert_file          "exclude file is written"          ".git/info/exclude"
assert_file_contains "run dir excluded locally"         ".git/info/exclude" "/.skepticism/"
assert_absent        "no .gitignore was created"        ".gitignore"
( git check-ignore -q ".skepticism/runs/feat/state.md" ); assert_eq "artifacts are actually ignored" 0 "$?"

# Idempotent: protect must not append a duplicate line on every run.
bash "$STATE" protect >/dev/null 2>&1
bash "$STATE" protect >/dev/null 2>&1
lines=$(grep -c '^/\.skepticism/$' .git/info/exclude)
assert_eq            "exclude line written only once"   1 "$lines"

# Outside a git repo, protect is a harmless no-op rather than an error.
mkdir -p "$WORK/nogit" && cd "$WORK/nogit"
( bash "$STATE" protect >/dev/null 2>&1 ); assert_eq "protect outside git exits 0" 0 "$?"

summary
