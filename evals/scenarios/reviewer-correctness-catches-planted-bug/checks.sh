# Deterministic witness. pre() asserts the fixture really contains the planted
# flaw (a green eval on a broken fixture proves nothing); post() asserts the
# reviewer failed it. "Named the RIGHT bug" is left to the LLM judge (AC2).
pre() {
  local rc=0
  need_file          "$WORK/spec.md"                        || rc=1
  need_file          "$WORK/diff.md"                        || rc=1
  need_file_contains "$WORK/diff.md" "score > PASS_THRESHOLD" || rc=1   # the planted off-by-one
  need_file_contains "$WORK/spec.md" ">= 70"                || rc=1     # spec says >=
  return $rc
}
post() {
  need_verdict "$WORK/verdict.txt" fail
}
