#!/usr/bin/env bash
# test-package-diff.sh — Tier 0. package-diff produces the ONE self-contained
# artifact the phase-6 reviewers read instead of re-exploring the repo. It must
# actually capture the changed hunks (a diff missing the change would let a
# reviewer "pass" code it never saw) and handle both working-tree and ref..ref.
set -uo pipefail

_ASSERT_NAME="package-diff"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
PKG="$PLUGIN_ROOT/scripts/package-diff"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-pkgdiff.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

git init -q
git config user.email eval@skepticism.test
git config user.name  "Eval Harness"
printf 'def add(a, b):\n    return a + b\n' > calc.py
git add -A && git commit -q -m "base"
base="$(git rev-parse HEAD)"

# Change against the working tree (head omitted).
printf 'def add(a, b):\n    return a - b  # BUG introduced\n' > calc.py
diff_path="$(bash "$PKG" "$base")"
assert_file          "diff artifact is created"        "$diff_path"
assert_file_contains "artifact has the package header" "$diff_path" "# Diff package"
assert_file_contains "artifact has a full-diff section" "$diff_path" "## Full diff"
assert_file_contains "artifact captures the change"    "$diff_path" "BUG introduced"

# Explicit base..head range.
git add -A && git commit -q -m "change"
head="$(git rev-parse HEAD)"
diff_path2="$(bash "$PKG" "$base" "$head")"
assert_file          "ref..ref diff artifact created"  "$diff_path2"
assert_file_contains "ref..ref captures the change"    "$diff_path2" "BUG introduced"
assert_file_contains "ref..ref header shows the range" "$diff_path2" "$base..$head"

# Untracked files are surfaced (reviewers must know code they can't see in-diff).
printf 'x = 1\n' > brand_new.py
diff_path3="$(bash "$PKG" "$head")"
assert_file_contains "untracked files are listed"      "$diff_path3" "brand_new.py"

summary
