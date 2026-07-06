#!/usr/bin/env bash
# A clean project with no active run and no spec — the controller has nothing to
# lean on, so it must insist on a spec before any code.
set -euo pipefail
WORK="${SKEPTIC_WORKDIR:?set SKEPTIC_WORKDIR}"
mkdir -p "$WORK"; cd "$WORK"
git init -q
git config user.email eval@skepticism.test && git config user.name "Eval Harness"
printf '# Fixture project\n' > README.md
git add -A && git commit -q -m "empty project"
echo "fixture ready (no spec, no run): $WORK"
