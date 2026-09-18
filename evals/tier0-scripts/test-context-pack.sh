#!/usr/bin/env bash
# test-context-pack.sh — Tier 0. The bearings file is what stops six subagents
# each rediscovering the same project in six separate contexts, and what stops
# the test-author guessing a test location. Its value is entirely in being
# *correct*: a pack that omits the test command, or reports one the project
# doesn't use, is worse than no pack at all, because every agent trusts it.
set -uo pipefail

_ASSERT_NAME="context-pack"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
CP="$PLUGIN_ROOT/scripts/context-pack"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-ctxpack.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# ── A Python project with CI, an existing suite, and no runner on PATH ───────
PROJ="$WORK/proj"
mkdir -p "$PROJ/tests" "$PROJ/src" "$PROJ/.github/workflows"
printf '[tool.pytest.ini_options]\ntestpaths = ["tests"]\n' > "$PROJ/pyproject.toml"
printf 'def test_existing():\n    assert True\n'            > "$PROJ/tests/test_existing.py"
printf 'def test_more():\n    assert True\n'                > "$PROJ/tests/test_more.py"
printf 'x = 1\n'                                            > "$PROJ/src/app.py"
printf 'jobs:\n  t:\n    steps:\n      - run: pytest -q\n      - run: ruff check .\n' \
  > "$PROJ/.github/workflows/ci.yml"

out="$( cd "$PROJ" && SKEPTIC_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$CP" feat )"; rc=$?
assert_eq   "context-pack exits 0"            0 "$rc"
assert_eq   "prints the artifact path"        ".skepticism/runs/feat/project.md" "$out"
PACK="$PROJ/$out"
assert_file "the pack is written"             "$PACK"

# The plugin root is recorded so no subagent ever hunts for a reference file —
# path flailing is pure quadratic waste.
assert_file_contains "records the plugin root"    "$PACK" "$PLUGIN_ROOT"

# What CI runs is the ground truth about what the project actually executes.
assert_file_contains "extracts the CI test command" "$PACK" "pytest -q"
assert_file_contains "extracts the CI lint command" "$PACK" "ruff check ."

# The suite's shape — the fix for tests landing in a file beside the suite.
assert_file_contains "lists an existing test file"  "$PACK" "tests/test_existing.py"
assert_file_contains "counts the existing tests"    "$PACK" "2 existing test file"
assert_file_contains "names the layout section"     "$PACK" "Test layout and conventions"

# A runner absent from PATH (a venv, a container) must not read as "no tests":
# it falls back to CI evidence and labels the answer a guess rather than a fact.
if ! command -v pytest >/dev/null 2>&1; then
  assert_file_contains "falls back to CI for the test cmd" "$PACK" "guess"
fi

# ── A project with no tests at all must say so, not stay silent ──────────────
# Silence here would let the author invent a convention and call it discovered.
BLANK="$WORK/blank"
mkdir -p "$BLANK"
printf 'x = 1\n' > "$BLANK/app.py"
out="$( cd "$BLANK" && bash "$CP" feat )"
assert_file_contains "empty project is stated plainly" "$BLANK/$out" "no existing tests found"

# ── Gate overrides are surfaced (they beat everything else in the pack) ──────
mkdir -p "$PROJ/.skepticism"
printf '#!/usr/bin/env bash\nexit 0\n' > "$PROJ/.skepticism/red-check.sh"
chmod +x "$PROJ/.skepticism/red-check.sh"
( cd "$PROJ" && bash "$CP" feat >/dev/null )
assert_file_contains "reports the red-check override" "$PACK" "red-check.sh\`: yes"

summary
