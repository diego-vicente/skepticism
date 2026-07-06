#!/usr/bin/env bash
# Builds a small GREEN project with a thinly-asserted function, committed clean.
# The adversary will mutate it; the point of the eval is that the tree comes back
# clean AND that the weak assertion is exposed.
set -euo pipefail
WORK="${SKEPTIC_WORKDIR:?set SKEPTIC_WORKDIR}"
PLUGIN_ROOT="${PLUGIN_ROOT:?set PLUGIN_ROOT}"
mkdir -p "$WORK"; cd "$WORK"

cat > spec.md <<'EOF'
# Spec: total

## Requirements (EARS)
- **REQ-1** — The system SHALL return the sum of a list of item prices.
- **REQ-2** — IF the list is empty, THEN the system SHALL return 0.
EOF

cat > pricing.py <<'EOF'
def total(prices):
    running = 0
    for p in prices:
        running += p
    return running
EOF

# Thin test: one input only. No boundary, no empty case → mutations can survive.
# Uses stdlib unittest so the fixture runs with zero third-party deps.
cat > test_pricing.py <<'EOF'
import unittest
from pricing import total

class TestTotal(unittest.TestCase):
    def test_total(self):   # REQ-1
        self.assertEqual(total([2, 3]), 5)

if __name__ == "__main__":
    unittest.main()
EOF

printf '__pycache__/\n*.pyc\n' > .gitignore
git init -q
git config user.email eval@skepticism.test && git config user.name "Eval Harness"
git add -A && git commit -q -m "green, thinly-asserted"

# NB: no diff artifact is written into $WORK. The mutation-adversary operates on
# the LIVE working tree (it mutates and reverts), so the tree must start clean —
# an untracked file here would make the real agent abort per its safety rules.
echo "fixture ready (clean, green): $WORK"
