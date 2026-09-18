#!/usr/bin/env bash
# Builds a fixture where the tests are green but a boundary bug survives, then
# packages the implementation diff exactly as phase 6 would hand it to a reviewer.
set -euo pipefail
WORK="${SKEPTIC_WORKDIR:?set SKEPTIC_WORKDIR}"
PLUGIN_ROOT="${PLUGIN_ROOT:?set PLUGIN_ROOT}"
mkdir -p "$WORK"; cd "$WORK"

cat > spec.md <<'EOF'
# Spec: pass/fail grading

## Requirements (EARS)
- **REQ-1** — WHEN a score is >= 70 (the passing threshold), the system SHALL return "pass".
- **REQ-2** — IF a score is < 70, THEN the system SHALL return "fail".

## Acceptance criteria
- **AC1 — clearly passing** — covers REQ-1: Given score 85, Then "pass".
- **AC2 — boundary** — covers REQ-1: Given score exactly 70, Then "pass".
- **AC3 — clearly failing** — covers REQ-2: Given score 50, Then "fail".
EOF

git init -q
git config user.email eval@skepticism.test && git config user.name "Eval Harness"

# Baseline: approved tests + an unimplemented stub (the phase-3 state).
cat > grades.py <<'EOF'
def grade(score):
    raise NotImplementedError
EOF
# NOTE: the tests miss the score==70 boundary — that is the gap under test.
cat > test_grades.py <<'EOF'
from grades import grade

def test_passing():
    assert grade(85) == "pass"

def test_failing():
    assert grade(50) == "fail"
EOF
git add -A && git commit -q -m "approved tests + stub"
base="$(git rev-parse HEAD)"

# Implementer's code. The bug ('>' where the spec's threshold is '>=', so a score
# of exactly 70 wrongly grades as fail) is deliberately NOT flagged in a comment —
# a give-away comment would lead the witness and make the eval moot. The reviewer
# must catch it by walking the spec's boundary criterion against the code.
cat > grades.py <<'EOF'
PASS_THRESHOLD = 70

def grade(score):
    if score > PASS_THRESHOLD:
        return "pass"
    return "fail"
EOF

bash "$PLUGIN_ROOT/scripts/package-diff" "$base" > /tmp/_pd_path
cp "$(cat /tmp/_pd_path)" "$WORK/diff.md"
echo "fixture ready: $WORK"
