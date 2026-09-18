#!/usr/bin/env bash
# test-det-gate.sh — Tier 0. det-gate is the cheap, ungameable checkpoint run
# BEFORE any LLM reviewer. We test the pieces that are hermetic and carry the
# logic: the project override branch, the no-checks-detected safe exit, and the
# core run()/verdict aggregation (any failing check ⇒ overall fail, naming it).
# Full multi-stack detection against real linters is out of Tier 0 by design
# (it needs per-stack fixtures + toolchains); we fake the tools to test the wiring.
set -uo pipefail

_ASSERT_NAME="det-gate"
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HARNESS_DIR/../.." && pwd)"
DG="$PLUGIN_ROOT/scripts/det-gate"
source "$PLUGIN_ROOT/evals/lib/assert.sh"

WORK="$(mktemp -d -t skeptic-detgate.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Fake Python toolchain on PATH — stub EVERY tool det-gate probes (ruff, mypy,
# pytest) so the test controls the full check set and never picks up whatever the
# host happens to have installed. ruff/mypy pass; pytest obeys FAKE_PYTEST_MODE.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/ruff"   <<'F'
#!/usr/bin/env bash
echo "ruff ok"; exit 0
F
cat > "$WORK/bin/mypy"   <<'F'
#!/usr/bin/env bash
echo "mypy ok"; exit 0
F
cat > "$WORK/bin/pytest" <<'F'
#!/usr/bin/env bash
[[ "${FAKE_PYTEST_MODE:-}" == "fail" ]] && { echo "1 failed"; exit 1; }
echo "1 passed"; exit 0
F
chmod +x "$WORK/bin/ruff" "$WORK/bin/mypy" "$WORK/bin/pytest"
export PATH="$WORK/bin:$PATH"

# ── Override branch: an executable .skepticism/det-gate.sh replaces everything ─
mkdir -p "$WORK/ovr/.skepticism"
cat > "$WORK/ovr/.skepticism/det-gate.sh" <<'OVR'
#!/usr/bin/env bash
echo "OVERRIDE-RAN"; exit 1
OVR
chmod +x "$WORK/ovr/.skepticism/det-gate.sh"
out="$( cd "$WORK/ovr" && bash "$DG" 2>&1 )"; rc=$?
assert_eq       "override exit passes through"     1 "$rc"
assert_contains "override is what ran"             "$out" "OVERRIDE-RAN"
assert_contains "leak-check ran before it"         "$out" "leak-check"

# ── Transparency is NOT overridable: a leaking repo fails before the override ─
# Iron Rule 6 must not be switchable off by a det-gate.sh the user forgot about,
# so leak-check runs first and short-circuits on failure.
LEAKY="$WORK/leaky"
mkdir -p "$LEAKY/.skepticism/runs/feat"
cat > "$LEAKY/.skepticism/det-gate.sh" <<'OVR'
#!/usr/bin/env bash
echo "OVERRIDE-RAN"; exit 0
OVR
chmod +x "$LEAKY/.skepticism/det-gate.sh"
( cd "$LEAKY" \
  && git init -q . \
  && git config user.email eval@skepticism.test \
  && git config user.name "Eval Harness" \
  && printf '# state\n' > .skepticism/runs/feat/state.md \
  && git add -A -f && git commit -q -m "leak" ) >/dev/null 2>&1
out="$( cd "$LEAKY" && bash "$DG" 2>&1 )"; rc=$?
assert_eq       "tracked artifacts ⇒ exit 1"       1 "$rc"
assert_contains "verdict names leak-check"         "$out" "leak-check"
[[ "$out" != *OVERRIDE-RAN* ]] \
  && _pass "override is skipped when leak-check fails" \
  || _fail "override is skipped when leak-check fails" "override ran anyway"

# ── No known checks → safe exit 0 (never block a project it doesn't understand) ─
mkdir -p "$WORK/blank"
out="$( cd "$WORK/blank" && bash "$DG" 2>&1 )"; rc=$?
assert_eq       "no checks detected exits 0"       0 "$rc"
assert_contains "explains no checks were found"    "$out" "no known checks"

# ── Detection + aggregation: a Python project with a failing check ⇒ fail ─────
mkdir -p "$WORK/py"; : > "$WORK/py/pyproject.toml"
out="$( cd "$WORK/py" && FAKE_PYTEST_MODE=fail bash "$DG" 2>&1 )"; rc=$?
assert_eq       "any failing check ⇒ exit 1"       1 "$rc"
assert_contains "verdict names the failing check"  "$out" "pytest"

# ── All checks pass ⇒ exit 0 ─────────────────────────────────────────────────
out="$( cd "$WORK/py" && FAKE_PYTEST_MODE=pass bash "$DG" 2>&1 )"; rc=$?
assert_eq       "all checks pass ⇒ exit 0"         0 "$rc"
assert_contains "verdict says all passed"          "$out" "all checks passed"

summary
