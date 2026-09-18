#!/usr/bin/env bash
# test-consolidate.sh — Tier 0. Consolidation is the memory-hygiene lever: a
# finished run must be archived (so it stops costing routing context) and its
# summary folded into a one-line INDEX entry. If this silently fails, the live
# .skepticism/ dir grows unbounded and every future run pays for it.
set -uo pipefail

_ASSERT_NAME="consolidate"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
CONSOL="$PLUGIN_ROOT/scripts/consolidate"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-consolidate.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

seed_run() { # <slug> <feature> <tier>
  mkdir -p ".skepticism/runs/$1"
  printf '# Skepticism run: %s\n\n- feature: %s\n- tier: %s\n- phase: done\n' "$1" "$2" "$3" \
    > ".skepticism/runs/$1/state.md"
}

seed_run login "add login" standard
out="$(bash "$CONSOL" login 2>&1)"; rc=$?
assert_eq            "consolidate exits 0"              0 "$rc"
assert_file          "index is created"                ".skepticism/INDEX.md"
assert_file_contains "index names the run"             ".skepticism/INDEX.md" "login"
assert_file_contains "index carries the feature"       ".skepticism/INDEX.md" "add login"
assert_file_contains "index carries the tier"          ".skepticism/INDEX.md" "standard"
assert_file          "artifacts moved into archive"    ".skepticism/archive/login/state.md"
assert_absent        "live run dir is gone"            ".skepticism/runs/login"

# A second run appends to the existing index (header written only once).
seed_run logout "add logout" quick
bash "$CONSOL" logout >/dev/null 2>&1
assert_file_contains "second run appended to index"    ".skepticism/INDEX.md" "logout"
assert_file_contains "first run still indexed"         ".skepticism/INDEX.md" "login"
headers=$(grep -c 'completed runs index' ".skepticism/INDEX.md")
assert_eq            "index header written only once"  1 "$headers"

( bash "$CONSOL" nonexistent >/dev/null 2>&1 ); assert_eq "missing run exits 1" 1 "$?"

summary
