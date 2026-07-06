#!/usr/bin/env bash
# run.sh — entry point for the skepticism eval harness.
#
#   ./evals/run.sh --tier0       deterministic script unit tests   (CI-safe, fast)
#   ./evals/run.sh --validate    static + fixture-build checks on the LLM tiers
#                                 (structure, bash -n, pre/post defined, setup runs,
#                                  triggering JSON valid)            (CI-safe)
#   ./evals/run.sh --ci          --tier0 then --validate  (what CI runs)
#   ./evals/run.sh --scenarios   how to run the behavioral evals (needs API)
#   ./evals/run.sh --triggering  how to run the triggering evals (needs API)
#
# Default with no args: --ci.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
export PLUGIN_ROOT

run_tier0() {
  local fail=0
  echo "══ Tier 0: deterministic script tests ══"
  for t in "$HERE"/tier0-scripts/test-*.sh; do
    echo "▶ $(basename "$t")"
    bash "$t" || fail=1
    echo
  done
  return $fail
}

validate_scenarios() {
  local fail=0
  echo "══ Validate: scenario structure + fixtures ══"
  for dir in "$HERE"/scenarios/*/; do
    local name; name="$(basename "$dir")"
    echo "▶ $name"
    local ok=1
    [[ -f "$dir/eval.md"   ]] || { echo "  FAIL missing eval.md";   ok=0; }
    [[ -f "$dir/setup.sh"  ]] || { echo "  FAIL missing setup.sh";  ok=0; }
    [[ -f "$dir/checks.sh" ]] || { echo "  FAIL missing checks.sh"; ok=0; }
    grep -q '## Acceptance Criteria' "$dir/eval.md" 2>/dev/null || { echo "  FAIL eval.md has no Acceptance Criteria"; ok=0; }
    if [[ -f "$dir/setup.sh"  ]]; then bash -n "$dir/setup.sh"  || { echo "  FAIL setup.sh syntax";  ok=0; }; fi
    if [[ -f "$dir/checks.sh" ]]; then bash -n "$dir/checks.sh" || { echo "  FAIL checks.sh syntax"; ok=0; }; fi
    # pre()/post() must be defined once checks-lib + checks.sh are sourced.
    if [[ -f "$dir/checks.sh" ]]; then
      ( source "$HERE/lib/checks-lib.sh"; source "$dir/checks.sh"
        declare -F pre  >/dev/null || exit 1
        declare -F post >/dev/null || exit 1 ) \
        || { echo "  FAIL checks.sh must define pre() and post()"; ok=0; }
    fi
    # The fixture must actually build (catches real setup.sh breakage).
    if [[ -f "$dir/setup.sh" ]]; then
      local wd; wd="$(mktemp -d -t skeptic-val.XXXXXX)"
      if SKEPTIC_WORKDIR="$wd" bash "$dir/setup.sh" >/dev/null 2>&1; then
        echo "  ok   fixture builds"
      else
        echo "  FAIL setup.sh errored while building the fixture"; ok=0
      fi
      rm -rf "$wd"
    fi
    [[ "$ok" -eq 1 ]] && echo "  ✓ $name valid" || fail=1
    echo
  done
  return $fail
}

validate_triggering() {
  local fail=0
  echo "══ Validate: triggering eval sets ══"
  for f in "$HERE"/triggering/*-trigger-eval.json; do
    echo "▶ $(basename "$f")"
    python3 - "$f" <<'PY' || fail=1
import json, sys
cases = json.load(open(sys.argv[1]))
assert isinstance(cases, list), "must be a JSON array"
pos = neg = 0
for c in cases:
    assert set(c) >= {"query", "should_trigger"}, f"bad entry: {c}"
    assert isinstance(c["query"], str) and c["query"], "empty query"
    assert isinstance(c["should_trigger"], bool), "should_trigger must be bool"
    pos += c["should_trigger"]; neg += not c["should_trigger"]
assert pos >= 8, f"want >=8 should-trigger, got {pos}"
assert neg >= 8, f"want >=8 should-not-trigger, got {neg}"
print(f"  ok   {len(cases)} queries ({pos} trigger / {neg} not)")
PY
  done
  python3 -m py_compile "$HERE/triggering/run-triggering.py" \
    && echo "  ok   run-triggering.py compiles" || fail=1
  echo
  return $fail
}

case "${1:---ci}" in
  --tier0)      run_tier0 ;;
  --validate)   v=0; validate_scenarios || v=1; validate_triggering || v=1; exit $v ;;
  --ci)         c=0; run_tier0 || c=1; validate_scenarios || c=1; validate_triggering || c=1
                echo "════════════════════════"
                [[ $c -eq 0 ]] && echo "CI evals: PASS" || echo "CI evals: FAIL"
                exit $c ;;
  --scenarios|--triggering)
                echo "The behavioral (1a/1b) and triggering (2) tiers need API access and a"
                echo "controller / claude CLI, so they don't run here. See evals/README.md →"
                echo "'Running the behavioral evals' and 'Running the triggering evals'." ;;
  *) echo "usage: run.sh [--tier0|--validate|--ci|--scenarios|--triggering]"; exit 2 ;;
esac
