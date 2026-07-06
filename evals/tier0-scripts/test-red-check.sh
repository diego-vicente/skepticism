#!/usr/bin/env bash
# test-red-check.sh — Tier 0. Unit-tests the RED gate (phase 2). red-check must
# distinguish three states the whole "failing-tests-first" discipline hinges on:
#   exit 0  valid RED  — suite fails on assertions (the good red → proceed)
#   exit 1  NOT RED    — suite passes with no impl (tests don't test anything)
#   exit 2  BROKEN RED — suite errors on import/collection (tests are broken)
#   exit 3  unknown    — no runner detected
# Mis-classifying BROKEN as valid would wave broken tests through; mis-classifying
# valid as NOT RED would stall a correct run. Both are silent, so we pin them.
#
# Hermetic: a fake `pytest` on PATH emits controlled output/exit codes, so the
# real classify() logic is exercised without any Python test runner installed.
set -uo pipefail

_ASSERT_NAME="red-check"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
RC="$PLUGIN_ROOT/scripts/red-check"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-redcheck.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Fake pytest: behavior chosen by $FAKE_PYTEST_MODE. Its output must be classified
# purely by exit code + the ERROR_RE grep, so we craft each case deliberately.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/pytest" <<'FAKE'
#!/usr/bin/env bash
case "${FAKE_PYTEST_MODE:-}" in
  pass)  echo "2 passed in 0.01s"; exit 0 ;;
  fail)  echo "E       assert 1 == 2"; echo "1 failed in 0.01s"; exit 1 ;;
  error) echo "ImportError: No module named 'app'"; exit 2 ;;
esac
FAKE
chmod +x "$WORK/bin/pytest"
export PATH="$WORK/bin:$PATH"

# A project where the pytest branch is detected (pyproject.toml present).
mkdir -p "$WORK/proj"; : > "$WORK/proj/pyproject.toml"
# An empty project where no runner should be detected.
mkdir -p "$WORK/empty"

# rc <dir>  → prints red-check's exit code (FAKE_PYTEST_MODE taken from env)
rc() { ( cd "$1" && bash "$RC" >/dev/null 2>&1 ); echo $?; }

FAKE_PYTEST_MODE=fail  assert_eq "assertion failure → valid RED (0)"  0 "$(FAKE_PYTEST_MODE=fail  rc "$WORK/proj")"
FAKE_PYTEST_MODE=pass  assert_eq "suite passes → NOT RED (1)"         1 "$(FAKE_PYTEST_MODE=pass  rc "$WORK/proj")"
FAKE_PYTEST_MODE=error assert_eq "import error → BROKEN RED (2)"      2 "$(FAKE_PYTEST_MODE=error rc "$WORK/proj")"
assert_eq "no runner detected → unknown (3)"                         3 "$(rc "$WORK/empty")"

# The project override short-circuits detection and its exit code passes through.
mkdir -p "$WORK/proj/.skepticism"
cat > "$WORK/proj/.skepticism/red-check.sh" <<'OVR'
#!/usr/bin/env bash
echo "OVERRIDE-RAN"; exit 0
OVR
chmod +x "$WORK/proj/.skepticism/red-check.sh"
out="$( cd "$WORK/proj" && bash "$RC" 2>&1 )"; ovr_rc=$?
assert_eq       "override runs and exit passes through" 0 "$ovr_rc"
assert_contains "override is what ran (not pytest)"     "$out" "OVERRIDE-RAN"

summary
