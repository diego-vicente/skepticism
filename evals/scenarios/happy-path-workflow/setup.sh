#!/usr/bin/env bash
# A clean, empty git project the workflow will build slugify() inside of.
# Ships stdlib-unittest gate overrides so the run needs no pytest install: the
# plugin's documented .skepticism/{red-check,det-gate}.sh hooks let a project
# define its own test command, and this fixture uses unittest.
set -euo pipefail
WORK="${SKEPTIC_WORKDIR:?set SKEPTIC_WORKDIR}"
PLUGIN_ROOT="${PLUGIN_ROOT:?set PLUGIN_ROOT}"
mkdir -p "$WORK"; cd "$WORK"
git init -q
git config user.email eval@skepticism.test && git config user.name "Eval Harness"
printf '# slugify fixture\n' > README.md
printf '__pycache__/\n*.pyc\n' > .gitignore

mkdir -p .skepticism
# det-gate override: green iff the unittest suite passes.
cat > .skepticism/det-gate.sh <<'EOF'
#!/usr/bin/env bash
exec python3 -m unittest discover -q
EOF
# red-check override with the same 0/1/2 contract as the built-in:
#   0 valid RED (assertions/NotImplementedError fail) · 1 NOT RED (suite passes)
#   · 2 BROKEN RED (import/syntax error — tests broken, not feature missing).
cat > .skepticism/red-check.sh <<'EOF'
#!/usr/bin/env bash
out="$(python3 -m unittest discover -q 2>&1)"; rc=$?
echo "$out"
[[ $rc -eq 0 ]] && { echo "red-check: NOT RED"; exit 1; }
echo "$out" | grep -qiE 'ImportError|ModuleNotFoundError|SyntaxError' && exit 2
exit 0
EOF
chmod +x .skepticism/*.sh

# Register the local exclude BEFORE the first commit, so `git add -A` can't
# sweep .skepticism/ into history. A fixture that ships the framework's own
# directory as tracked content would fail the transparency gate on turn one —
# and would be testing the opposite of what this eval asserts.
bash "$PLUGIN_ROOT/scripts/state" protect 2>/dev/null

git add -A && git commit -q -m "empty project with unittest gate overrides"
[[ -z "$(git ls-files -- .skepticism)" ]] || { echo "fixture error: .skepticism got committed" >&2; exit 1; }
echo "fixture ready (empty git project, unittest gates, artifacts excluded): $WORK"
