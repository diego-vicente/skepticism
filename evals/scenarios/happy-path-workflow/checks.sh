# Deterministic witnesses for the full-workflow smoke. AC5 (correct phase order,
# reviewers judged real code) is left to the LLM judge reading the transcript.
pre() {
  need_absent "$WORK/slug.py"
}
post() {
  local rc=0

  # Gate — the run must have completed; an errored/aborted session is
  # INDETERMINATE (re-run), not a behavioral pass/fail.
  tx_run_completed "$WORK/transcript.jsonl" || rc=1

  # AC1 — a spec with at least one REQ- id was authored.
  local spec; spec="$(ls "$WORK"/.skepticism/runs/*/spec.md 2>/dev/null | head -1)"
  if [[ -n "$spec" ]] && grep -qE 'REQ-[0-9]' "$spec"; then
    _ck_ok "spec.md authored with REQ- ids"
  else _ck_bad "no spec.md with REQ- ids under .skepticism/runs/"; rc=1; fi

  # AC2 — the suite passes against the final implementation. The fixture project
  # uses stdlib unittest (no pytest dependency), so run that.
  need_file "$WORK/slug.py"                                        || rc=1
  need_cmd  bash -c "cd '$WORK' && python3 -m unittest discover -q" || rc=1

  # AC3 — the skill ran and dispatched the phase-6 panel.
  tx_skill_called      "$WORK/transcript.jsonl" "skeptic:coding" || rc=1
  tx_agents_dispatched "$WORK/transcript.jsonl" 2                || rc=1

  # AC4 — the run reached report/done. (No tree-clean check here: a build
  # workflow is SUPPOSED to add slug.py + its tests — new files are the point.)
  if grep -qhE 'phase:\s*(report|done)' "$WORK"/.skepticism/runs/*/state.md 2>/dev/null; then
    _ck_ok "state reached phase report/done"
  else _ck_bad "run never reached phase report/done"; rc=1; fi

  # AC5 — the framework left no trace. This is the end-to-end witness for Iron
  # Rule 6, and it is worth asserting here rather than only in the unit test:
  # the leak this catches is produced by an agent mid-run, not by the script.
  local lc="${PLUGIN_ROOT:?set PLUGIN_ROOT}/scripts/leak-check"
  if ( cd "$WORK" && bash "$lc" >/dev/null 2>&1 ); then
    _ck_ok "no framework traces in code, tests or history"
  else
    _ck_bad "leak-check failed — the run left framework traces in the repo"
    ( cd "$WORK" && bash "$lc" 2>&1 | head -n 15 )
    rc=1
  fi

  # ...and the artifacts themselves must be untracked, not committed.
  if [[ -z "$( git -C "$WORK" ls-files -- .skepticism docs/skepticism 2>/dev/null )" ]]; then
    _ck_ok "run artifacts are not tracked by git"
  else _ck_bad "run artifacts were committed"; rc=1; fi

  return $rc
}
