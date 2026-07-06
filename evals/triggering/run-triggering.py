#!/usr/bin/env python3
"""run-triggering.py — Tier 2. Does each skill FIRE on the right prompts?

Triggering is orthogonal to output correctness: it depends almost entirely on the
skill's `description`. This runner fires each eval query at a headless
`claude -p` session with the plugin loaded, and inspects the streamed events for
whether Claude *chose* to invoke the skill. Scored as a binary classification
(precision / recall / accuracy) over should-/shouldn't-trigger queries, run a few
times each because triggering is non-deterministic.

Adapted from Anthropic skill-creator's run_eval.py mechanism. Unlike that tool
(which optimizes a *candidate* description via a temp command), this tests the
ACTUAL shipped skill as installed, so it points `--plugin-dir` at the repo.

REQUIRES the `claude` CLI + API access. NOT a CI test (costs money, non-hermetic).

Usage:
  python3 evals/triggering/run-triggering.py \
      --eval-set evals/triggering/coding-trigger-eval.json \
      --skill skeptic:coding \
      --plugin-dir . \
      --runs 3 --threshold 0.5 [--model claude-...]
"""
import argparse, json, os, subprocess, sys


def query_triggers(query, skill, plugin_dir, model, timeout):
    """Run one headless query; return True iff Claude invoked `skill`."""
    cmd = ["claude", "-p", query, "--plugin-dir", plugin_dir,
           "--output-format", "stream-json", "--verbose"]
    if model:
        cmd += ["--model", model]
    env = dict(os.environ)
    env.pop("CLAUDECODE", None)  # let `claude -p` nest inside a Claude Code session
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        return False
    out = proc.stdout
    # A Skill tool call naming the skill, or a Read of its SKILL.md, counts as a
    # trigger. The bare skill name ("coding"/"spec") also matches the namespaced id.
    short = skill.split(":", 1)[-1]
    for line in out.splitlines():
        if '"Skill"' not in line and "SKILL.md" not in line:
            continue
        if skill in line or f'"{short}"' in line or f"/{short}/SKILL.md" in line:
            return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--eval-set", required=True)
    ap.add_argument("--skill", required=True, help="e.g. skeptic:coding")
    ap.add_argument("--plugin-dir", default=".")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("--model", default=None)
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()

    cases = json.load(open(args.eval_set))
    tp = fp = tn = fn = 0
    print(f"triggering eval: {args.skill}  ({len(cases)} queries × {args.runs} runs)\n")
    for c in cases:
        hits = sum(query_triggers(c["query"], args.skill, args.plugin_dir,
                                   args.model, args.timeout)
                   for _ in range(args.runs))
        rate = hits / args.runs
        fired = rate >= args.threshold
        want = bool(c["should_trigger"])
        ok = fired == want
        if want and fired: tp += 1
        elif want and not fired: fn += 1
        elif not want and fired: fp += 1
        else: tn += 1
        mark = "ok  " if ok else "FAIL"
        print(f"  {mark}  rate={rate:.2f} want={'Y' if want else 'N'}  {c['query'][:70]}")

    total = tp + fp + tn + fn
    passed = tp + tn
    prec = tp / (tp + fp) if (tp + fp) else 1.0
    rec = tp / (tp + fn) if (tp + fn) else 1.0
    print(f"\n── {args.skill}: {passed}/{total} correct  "
          f"(precision {prec:.2f}, recall {rec:.2f}; "
          f"TP={tp} FP={fp} TN={tn} FN={fn})")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
