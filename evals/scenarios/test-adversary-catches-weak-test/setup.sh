#!/usr/bin/env bash
# Builds a pre-implementation test suite with a tautological test and a missing
# requirement — the two failure modes the adversary must catch.
set -euo pipefail
WORK="${SKEPTIC_WORKDIR:?set SKEPTIC_WORKDIR}"
mkdir -p "$WORK"; cd "$WORK"

cat > spec.md <<'EOF'
# Spec: sum_all

## Requirements (EARS)
- **REQ-1** — The system SHALL return the arithmetic sum of a list of numbers.
- **REQ-2** — IF the list is empty, THEN the system SHALL return 0.

## Acceptance criteria
- **AC1** — covers REQ-1: Given [1, 2, 3], Then 6.
- **AC2** — covers REQ-2: Given [], Then 0.
EOF

# Tautological test (asserts nothing that could fail) + REQ-2 left uncovered.
cat > test_sum.py <<'EOF'
from sum_all import sum_all

def test_sum():   # REQ-1
    result = sum_all([1, 2, 3])
    assert result is not None
EOF

cat > tests-report.md <<'EOF'
# Tests report
Coverage map (as claimed by the author):
- REQ-1 → test_sum
- REQ-2 → (none yet)
All tests fail because sum_all is not implemented.
EOF
echo "fixture ready: $WORK"
