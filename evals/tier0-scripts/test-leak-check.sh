#!/usr/bin/env bash
# test-leak-check.sh — Tier 0. leak-check is what makes Iron Rule 6 real. Prose
# telling an agent "don't annotate the code with REQ-IDs" is exactly the kind of
# rule that gets rationalised away mid-run; this turns it into a gate.
#
# Four independent leaks, four independent checks — and the false-positive side
# matters as much as the true-positive side, because a gate that fires on a
# project's own pre-existing text would block every run in that repo.
set -uo pipefail

_ASSERT_NAME="leak-check"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
LC="$PLUGIN_ROOT/scripts/leak-check"
STATE="$PLUGIN_ROOT/scripts/state"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-leakcheck.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

new_repo() { # <name> → prints the repo path, already committed and protected
  local d="$WORK/$1"
  mkdir -p "$d"
  ( cd "$d"
    git init -q .
    git config user.email eval@skepticism.test
    git config user.name  "Eval Harness"
    printf 'def total(items):\n    return sum(items)\n' > calc.py
    git add -A && git commit -q -m "base"
    bash "$STATE" protect ) >/dev/null 2>&1
  echo "$d"
}

# ── Clean repo → pass ────────────────────────────────────────────────────────
R="$(new_repo clean)"
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "clean repo exits 0"                 0 "$rc"
assert_contains "says it is clean"                   "$out" "clean"

# ── A REQ-ID in an added code line → fail ────────────────────────────────────
R="$(new_repo reqid)"
printf 'def rate():  # REQ-4: flat rate\n    return 1\n' >> "$R/calc.py"
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "REQ-ID in added line ⇒ exit 1"      1 "$rc"
assert_contains "names the offending file"           "$out" "calc.py"
assert_contains "points at the coverage map instead" "$out" "coverage.md"

# ── The SAME marker, but pre-existing → pass ─────────────────────────────────
# Only added lines are scanned. A project that already writes "REQ-2" in its own
# files must never be blocked by our gate.
R="$(new_repo preexisting)"
( cd "$R"
  printf '# REQ-2 is this project own numbering, not ours\n' >> calc.py
  git add -A && git commit -q -m "project text" ) >/dev/null 2>&1
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "pre-existing marker does NOT fire"  0 "$rc"

# ── Markdown is out of scope → pass ──────────────────────────────────────────
R="$(new_repo prose)"
printf '# Design\n\nREQ-7: the system shall bill monthly.\n' > "$R/DESIGN.md"
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "markers in prose do NOT fire"       0 "$rc"

# ── The allowlist escape hatch ───────────────────────────────────────────────
R="$(new_repo allowed)"
printf 'def rate():  # REQ-4\n    return 1\n' >> "$R/calc.py"
mkdir -p "$R/.skepticism"
printf 'REQ-4\n' > "$R/.skepticism/leak-allow"
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "allowlisted marker is dropped"      0 "$rc"

# ── Tracked run artifacts → fail ─────────────────────────────────────────────
R="$(new_repo tracked)"
( cd "$R"
  mkdir -p .skepticism/runs/feat
  printf '# state\n' > .skepticism/runs/feat/state.md
  git add -f .skepticism && git commit -q -m "oops" ) >/dev/null 2>&1
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "tracked artifacts ⇒ exit 1"         1 "$rc"
assert_contains "names the tracked artifact"         "$out" ".skepticism/runs/feat/state.md"

# ── Missing local exclude → fail (the protection is not in place) ────────────
R="$WORK/unprotected"
mkdir -p "$R"
( cd "$R"
  git init -q .
  git config user.email eval@skepticism.test
  git config user.name  "Eval Harness"
  printf 'x\n' > a.py
  git add -A && git commit -q -m base ) >/dev/null 2>&1
out="$( cd "$R" && bash "$LC" 2>&1 )"; rc=$?
assert_eq       "unprotected repo ⇒ exit 1"          1 "$rc"
assert_contains "tells you how to fix it"            "$out" "state protect"

# ── A framework reference in a commit message → fail ─────────────────────────
# Commit messages push to the remote, so history leaks just as loudly as code.
R="$(new_repo history)"
base="$( cd "$R" && git rev-parse HEAD )"
( cd "$R"
  printf 'y = 2\n' >> calc.py
  git add -A && git commit -q -m "phase 4: implement via skeptic:coding" ) >/dev/null 2>&1
out="$( cd "$R" && bash "$LC" "$base" 2>&1 )"; rc=$?
assert_eq       "leaking commit message ⇒ exit 1"    1 "$rc"
assert_contains "quotes the offending message"       "$out" "skeptic:coding"

# A clean message over the same range must pass.
R="$(new_repo history_ok)"
base="$( cd "$R" && git rev-parse HEAD )"
( cd "$R"
  printf 'y = 2\n' >> calc.py
  git add -A && git commit -q -m "Add flat rate to totals" ) >/dev/null 2>&1
out="$( cd "$R" && bash "$LC" "$base" 2>&1 )"; rc=$?
assert_eq       "ordinary commit message passes"     0 "$rc"

# ── Outside a git repo, there is nothing to leak → pass, never block ─────────
mkdir -p "$WORK/nogit"
( cd "$WORK/nogit" && bash "$LC" >/dev/null 2>&1 ); assert_eq "non-git dir exits 0" 0 "$?"

summary
