# checks-lib.sh — deterministic check verbs for scenario checks.sh files.
#
# The runner sources THIS, then the scenario's checks.sh, then calls pre()/post().
# These are the "second witness" in the dual-witness model: an LLM judge grades
# the prose Acceptance Criteria in eval.md, and these verbs assert the same facts
# mechanically. A scenario passes only if BOTH agree. Every verb prints a line
# and returns non-zero on failure so pre()/post() can accumulate a status.
#
# Deps: bash + python3 (python3 is already required by the plugin's own hooks).
# Convention: fixtures and captured agent output live under $SKEPTIC_WORKDIR.

_ck_ok()   { printf '    ok   %s\n' "$1"; return 0; }
_ck_bad()  { printf '    FAIL %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         ↳ %s\n' "$2"; return 1; }

# ── Filesystem / process verbs ───────────────────────────────────────────────
need_file()          { [[ -f "$1" ]]     && _ck_ok "file exists: $1"      || _ck_bad "missing file: $1"; }
need_absent()        { [[ ! -e "$1" ]]   && _ck_ok "absent: $1"           || _ck_bad "should NOT exist: $1"; }
need_file_contains() { grep -qF -- "$2" "$1" 2>/dev/null && _ck_ok "$1 contains [$2]" || _ck_bad "$1 missing [$2]"; }
need_file_lacks()    { grep -qF -- "$2" "$1" 2>/dev/null && _ck_bad "$1 unexpectedly contains [$2]" || _ck_ok "$1 lacks [$2]"; }
need_cmd()           { if "$@" >/dev/null 2>&1; then _ck_ok "command succeeds: $*"; else _ck_bad "command failed: $*"; fi; }

# need_tree_clean <repo> — the perturbation-adversary's non-negotiable safety
# invariant: after it runs, every TRACKED file must be byte-for-byte as it
# started. A mutation is always an edit to a tracked source file, so we ignore
# untracked noise (e.g. __pycache__/ from running the suite) — that isn't a
# leftover mutation and must not spuriously fail the safety check.
need_tree_clean() {
  local dirty; dirty="$(git -C "$1" status --porcelain --untracked-files=no 2>/dev/null)"
  [[ -z "$dirty" ]] && _ck_ok "working tree clean: $1" || _ck_bad "working tree DIRTY (unreverted mutation?): $1" "$dirty"
}

# ── Verdict verb — the deterministic half for the reviewer subagents ─────────
# The runner captures the subagent's final structured message to verdict.txt.
need_verdict() { # <verdict.txt> <pass|fail>
  local got; got="$(grep -Eio 'verdict:[[:space:]]*(pass|fail)' "$1" 2>/dev/null | head -1 | grep -Eio '(pass|fail)')"
  [[ "$got" == "$2" ]] && _ck_ok "verdict is '$2'" || _ck_bad "expected verdict '$2', parsed '${got:-<none>}'" "check $1"
}

# ── Transcript verbs — for full-workflow (Tier 1b) claude -p session JSONL ───
# Grep-based and version-coupled (like superpowers' own): adjust the patterns to
# your Claude Code transcript format if these stop matching.
tx_skill_called() { # <transcript.jsonl> <skill-name e.g. skeptic:coding>
  python3 - "$1" "$2" <<'PY'
import sys
path, skill = sys.argv[1], sys.argv[2]
try:
    data = open(path, encoding="utf-8").read()
except OSError:
    sys.exit(1)
# A Skill tool call naming the skill, or a Read/Bash touching its SKILL.md.
sys.exit(0 if (skill in data and ('"Skill"' in data or 'SKILL.md' in data)) else 1)
PY
  [[ $? -eq 0 ]] && _ck_ok "skill invoked: $2" || _ck_bad "skill never invoked: $2"
}

tx_agents_dispatched() { # <transcript.jsonl> <min-count>
  local n
  n="$(python3 - "$1" <<'PY'
import re, sys
try: data = open(sys.argv[1], encoding="utf-8").read()
except OSError: print(0); sys.exit()
print(len(re.findall(r'"name":\s*"(Agent|Task)"', data)))
PY
)"
  [[ "${n:-0}" -ge "$2" ]] && _ck_ok "subagents dispatched: $n (≥ $2)" || _ck_bad "too few subagents dispatched: ${n:-0} (< $2)"
}

# tx_run_completed <transcript.jsonl> — did the headless session reach a clean
# terminal state? A crashed/errored run (e.g. an API ECONNRESET) writes no code
# either, so without this gate an aborted run FALSELY passes a "no code written"
# check. Treat its failure as INDETERMINATE (re-run), not a behavioral fail.
tx_run_completed() {
  python3 - "$1" <<'PY'
import json, sys
ok = False
try: lines = open(sys.argv[1], errors="ignore").read().splitlines()
except OSError: sys.exit(1)
for line in lines:
    line = line.strip()
    if not line: continue
    try: ev = json.loads(line)
    except Exception: continue
    if ev.get("type") == "result":
        if ev.get("is_error"): sys.exit(1)
        txt = (ev.get("result") or "").strip()
        if txt.startswith("API Error"): sys.exit(1)
        ok = True
sys.exit(0 if ok else 1)
PY
  [[ $? -eq 0 ]] && _ck_ok "run reached a clean terminal state" \
    || _ck_bad "run did NOT complete (errored/empty) — INDETERMINATE, re-run; not a behavioral fail"
}

# tx_no_source_edited <transcript.jsonl> — no Edit/Write to a NON-test source
# file (mirrors the gate's own rule). The oracle for "it refused to write code."
tx_no_source_edited() {
  python3 - "$1" <<'PY'
import json, re, sys
TEST_RE = re.compile(r"(^|/)(tests?|__tests__|spec)(/|$)|(^|/)test_|(_test|\.test|\.spec)\.", re.I)
try: lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError: sys.exit(0)
def is_source(p):
    if not p: return False
    if p.startswith("docs/skepticism") or "/docs/skepticism/" in p: return False
    if p.startswith(".skepticism") or "/.skepticism/" in p: return False
    return not TEST_RE.search(p)
offenders = []
for line in lines:
    for m in re.finditer(r'"name":\s*"(Edit|Write|MultiEdit)".*?"file_path":\s*"([^"]+)"', line):
        if is_source(m.group(2)): offenders.append(m.group(2))
if offenders:
    print("edited source:", ", ".join(sorted(set(offenders)))); sys.exit(1)
sys.exit(0)
PY
  [[ $? -eq 0 ]] && _ck_ok "no non-test source file was edited" || _ck_bad "a source file was edited (should have refused)"
}
