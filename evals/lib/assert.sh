# assert.sh — minimal, dependency-free test assertions for the eval harness.
#
# Source this from a Tier-0 test script. Each assert_* prints one line and
# updates counters; call `summary` at the end (it exits non-zero on any failure,
# so `run.sh` can aggregate). No framework, no jq — bash + coreutils only, so it
# runs anywhere the plugin's own scripts do (and in CI).
#
# Usage:
#   _ASSERT_NAME="gate-check"
#   source "$(dirname "$0")/../lib/assert.sh"
#   assert_eq "exit code" 0 "$rc"
#   summary

_ASSERT_PASS=0
_ASSERT_FAIL=0
_ASSERT_NAME="${_ASSERT_NAME:-tests}"

_pass() { _ASSERT_PASS=$((_ASSERT_PASS + 1)); printf '  ok    %s\n' "$1"; }
_fail() {
  _ASSERT_FAIL=$((_ASSERT_FAIL + 1))
  printf '  FAIL  %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '        ↳ %s\n' "$2"
  return 0
}

# assert_eq <desc> <expected> <actual>
assert_eq() { [[ "$2" == "$3" ]] && _pass "$1" || _fail "$1" "expected [$2], got [$3]"; }

# assert_contains <desc> <haystack> <needle>
assert_contains() { [[ "$2" == *"$3"* ]] && _pass "$1" || _fail "$1" "substring [$3] not found in: $2"; }

# assert_empty <desc> <string>
assert_empty() { [[ -z "$2" ]] && _pass "$1" || _fail "$1" "expected empty, got: $2"; }

# assert_file <desc> <path>
assert_file() { [[ -f "$2" ]] && _pass "$1" || _fail "$1" "no such file: $2"; }

# assert_absent <desc> <path>
assert_absent() { [[ ! -e "$2" ]] && _pass "$1" || _fail "$1" "path exists but should not: $2"; }

# assert_file_contains <desc> <path> <fixed-string>
assert_file_contains() {
  grep -qF -- "$3" "$2" 2>/dev/null && _pass "$1" || _fail "$1" "[$3] not found in file: $2"
}

summary() {
  printf '── %s: %d passed, %d failed\n' "$_ASSERT_NAME" "$_ASSERT_PASS" "$_ASSERT_FAIL"
  [[ "$_ASSERT_FAIL" -eq 0 ]]
}
