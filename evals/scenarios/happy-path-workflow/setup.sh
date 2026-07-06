#!/usr/bin/env bash
# A clean, empty git project the workflow will build slugify() inside of.
set -euo pipefail
WORK="${SKEPTIC_WORKDIR:?set SKEPTIC_WORKDIR}"
mkdir -p "$WORK"; cd "$WORK"
git init -q
git config user.email eval@skepticism.test && git config user.name "Eval Harness"
printf '# slugify fixture\n' > README.md
git add -A && git commit -q -m "empty project"
echo "fixture ready (empty git project): $WORK"
