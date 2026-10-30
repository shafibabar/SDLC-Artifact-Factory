#!/usr/bin/env bash
# tests/run-skill-evals.sh — run one skill's eval suite with the built-in
# `claude plugin eval` runner and apply the Fresh-Eyes verdict (closes #1228).
#
# Where evals live: evals/<skill>/<case>/{prompt.md, graders/*.md} at the REPO
# ROOT. The runner refuses an eval dir inside skills/ ("a loaded component
# directory"), and keeping golden answers out of the skill's own folder also
# stops them leaking into the context of the run they grade.
#
# Verdict (exit 0 only if BOTH hold):
#   1. every case passes (casesPassed == casesTotal at --threshold), and
#   2. the skill beats the no-plugin baseline: meanDelta > 0. A skill that
#      scores the same with and without the plugin adds nothing Claude did not
#      already know — that is the grounding question this campaign exists to
#      answer, so a non-positive delta fails even when every case passes.
#
# Usage:
#   tests/run-skill-evals.sh <skill> [--runs N] [--max-cost-usd X] [--threshold T]
#   tests/run-skill-evals.sh --verdict-only <aggregate-result.json>   # no model calls
#   tests/run-skill-evals.sh --freeze-status <skill>                  # no model calls
#
# Every run also prints the suite's freeze status: the "Freeze evals: <skill>"
# commit, and any eval file changed since it (the grader-change rule). This is
# reported, never blocking — the PR's change log is where a change is judged.
#
# Defaults: --runs 3, --max-cost-usd 7 (the per-skill budget, raised from 2 on
# 2026-10-30: independently authored cases ask for full documents), --threshold 0.66 (2 of 3 runs must pass;
# LLM-judged graders are noisy, and 1.0 would fail a case on one bad roll).
# Not 0.67: the runner compares passRate >= threshold, and 2/3 = 0.6667 < 0.67,
# so 0.67 silently demanded 3 of 3 (found on roadmap-authoring, #1330).
# Exit codes: 0 pass · 1 verdict failed · 2 usage error / no suite / runner error.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

verdict() {  # verdict <aggregate-result.json> -> prints a line, returns 0/1
  python3 - "$1" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    a = d["aggregates"]
    total, passed, delta = a["casesTotal"], a["casesPassed"], a.get("meanDelta")
except (OSError, ValueError, KeyError) as e:
    print(f"VERDICT: ERROR — unreadable result file ({e})")
    sys.exit(2)
cost = d.get("costUsd")
cost_s = f", ${cost:.2f}" if isinstance(cost, (int, float)) else ""
problems = []
if total == 0:
    problems.append("no cases ran")
if passed != total:
    problems.append(f"{total - passed} of {total} case(s) failed")
if delta is None:
    problems.append("no baseline arm (run with ablation)")
elif delta <= 0:
    problems.append(f"skill does not beat the no-plugin baseline (mean delta {delta:+.2f})")
head = f"{passed}/{total} cases passed, mean delta {delta:+.2f}{cost_s}" if delta is not None \
    else f"{passed}/{total} cases passed{cost_s}"
if problems:
    print(f"VERDICT: FAIL — {head}: " + "; ".join(problems))
    sys.exit(1)
print(f"VERDICT: PASS — {head}")
PY
}

freeze_status() {  # freeze_status <skill> <suite> -> prints the eval-freeze line(s), always returns 0
  # Separate authorship (skill-authoring-standards § Testing): a fresh subagent
  # writes the suite, which is committed as "Freeze evals: <skill>" before the
  # first run. Any later edit must be logged in the PR, so surface it here.
  local skill="$1" suite="$2" ref changed
  ref="$(git -C "$REPO_ROOT" log -1 --format=%h --fixed-strings --grep="Freeze evals: $skill" 2>/dev/null)"
  if [[ -z "$ref" ]]; then
    echo "FREEZE: none — no 'Freeze evals: $skill' commit (suite not independently authored and frozen)"
    return 0
  fi
  changed="$( { git -C "$REPO_ROOT" diff --name-only "$ref" -- "$suite"
               git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$suite"; } | sort -u)"
  if [[ -z "$changed" ]]; then
    echo "FREEZE: $ref — suite unchanged since the freeze"
  else
    echo "FREEZE: $ref — EVAL FILES CHANGED SINCE THE FREEZE (log each in the PR's 'Eval changes after freeze' table):"
    sed 's/^/  /' <<<"$changed"
  fi
}

if [[ "${1:-}" == "--verdict-only" ]]; then
  [[ -n "${2:-}" ]] || { echo "usage: $0 --verdict-only <aggregate-result.json>" >&2; exit 2; }
  verdict "$2"; exit $?
fi

if [[ "${1:-}" == "--freeze-status" ]]; then
  [[ -n "${2:-}" ]] || { echo "usage: $0 --freeze-status <skill>" >&2; exit 2; }
  freeze_status "$2" "${SKILL_EVALS_ROOT:-evals}/$2"; exit 0
fi

SKILL="${1:-}"
if [[ -z "$SKILL" || "$SKILL" == -* ]]; then
  echo "usage: $0 <skill> [--runs N] [--max-cost-usd X] [--threshold T]" >&2
  exit 2
fi
shift
RUNS=3; COST=7; THRESHOLD=0.66
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --max-cost-usd) COST="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$REPO_ROOT/skills/$SKILL" ]]; then
  echo "no such skill: $SKILL" >&2; exit 2
fi
# SKILL_EVALS_ROOT (repo-relative) exists for tests: it lets the "no suite"
# path be exercised without depending on some real skill still lacking evals.
SUITE="${SKILL_EVALS_ROOT:-evals}/$SKILL"
if [[ ! -d "$REPO_ROOT/$SUITE" ]] || [[ -z "$(find "$REPO_ROOT/$SUITE" -name prompt.md -o -name case.yaml 2>/dev/null | grep -v /results/ | head -1)" ]]; then
  echo "no eval suite for '$SKILL' (expected $SUITE/<case>/prompt.md)" >&2; exit 2
fi
command -v claude >/dev/null || { echo "claude CLI not on PATH" >&2; exit 2; }

OUT="$(mktemp -t "skill-evals-$SKILL.XXXXXX.json")"
trap 'rm -f "$OUT"' EXIT
echo "== evals: $SKILL  (runs=$RUNS, threshold=$THRESHOLD, cost cap \$$COST, with/without-plugin ablation)"
freeze_status "$SKILL" "$SUITE"
( cd "$REPO_ROOT" && claude plugin eval . --eval-dir "$SUITE" \
    --runs "$RUNS" --threshold "$THRESHOLD" --max-cost-usd "$COST" \
    --no-publish --trust-plugin --json "$OUT" )
RUNNER_RC=$?
if [[ ! -s "$OUT" ]]; then
  echo "VERDICT: ERROR — runner exited $RUNNER_RC without a result file" >&2
  exit 2
fi
verdict "$OUT"
