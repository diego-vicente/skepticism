# Deterministic witness. pre() confirms the planted defects are present;
# post() confirms the adversary failed the suite. Whether it named the RIGHT
# two defects (AC2/AC3) is the LLM judge's call.
pre() {
  local rc=0
  need_file          "$WORK/spec.md"                    || rc=1
  need_file          "$WORK/test_sum.py"                || rc=1
  need_file_contains "$WORK/test_sum.py" "is not None"  || rc=1   # the tautology
  need_file_contains "$WORK/spec.md" "REQ-2"            || rc=1   # the requirement left uncovered
  need_file_lacks    "$WORK/test_sum.py" "== 0"         || rc=1   # ...genuinely not tested
  return $rc
}
post() {
  need_verdict "$WORK/verdict.txt" fail
}
