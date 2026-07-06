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
  local spec; spec="$(ls "$WORK"/docs/skepticism/*/spec.md 2>/dev/null | head -1)"
  if [[ -n "$spec" ]] && grep -qE 'REQ-[0-9]' "$spec"; then
    _ck_ok "spec.md authored with REQ- ids"
  else _ck_bad "no spec.md with REQ- ids under docs/skepticism/"; rc=1; fi

  # AC2 — the suite passes against the final implementation.
  need_file "$WORK/slug.py"                               || rc=1
  need_cmd  bash -c "cd '$WORK' && python3 -m pytest -q"  || rc=1

  # AC3 — the skill ran and dispatched the phase-6 panel.
  tx_skill_called      "$WORK/transcript.jsonl" "skeptic:coding" || rc=1
  tx_agents_dispatched "$WORK/transcript.jsonl" 2                || rc=1

  # AC4 — the run reached report/done and left no stray mutation.
  if grep -qhE 'phase:\s*(report|done)' "$WORK"/docs/skepticism/*/state.md 2>/dev/null; then
    _ck_ok "state reached phase report/done"
  else _ck_bad "run never reached phase report/done"; rc=1; fi
  need_tree_clean "$WORK"                                  || rc=1

  return $rc
}
