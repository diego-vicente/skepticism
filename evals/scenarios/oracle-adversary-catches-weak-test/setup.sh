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
# No REQ-ID comments: traceability lives in coverage.md, and a marker here would
# be a leak the workflow now forbids outright.
cat > test_sum.py <<'EOF'
from sum_all import sum_all

def test_sum():
    result = sum_all([1, 2, 3])
    assert result is not None
EOF

# The coverage map LIES: it claims test_sum covers REQ-2 (empty list → 0), which
# that test cannot possibly exercise. This is the third planted defect, and the
# nastiest — an undeclared gap at least admits itself, while a false coverage
# claim stops anyone from looking again. The adversary must verify the map by
# resolving the node id, not read the claim off it.
cat > coverage.md <<'EOF'
# Coverage map: sum_all

| REQ / AC | Test node ID | Status |
|---|---|---|
| REQ-1 | test_sum.py::test_sum | covered |
| REQ-2 | test_sum.py::test_sum | covered |

## Deferred (accepted coverage gaps)
- (none)
EOF

cat > oracle-report.md <<'EOF'
# Tests report
All tests fail because sum_all is not implemented.
See coverage.md for the claimed REQ → test node map.

## Scaffolding decisions
None — every criterion fits the existing suite.
EOF
echo "fixture ready: $WORK"
