#!/usr/bin/env python3
"""record-eval-run.py — post one eval run to its GitHub issue (#1508).

Called by tests/run-skill-evals.sh, so a run is recorded the same way whoever
starts it (a terminal, a Claude session or a subagent):

  record-eval-run.py start  --state FILE --skill S [--runs N] [--threshold T]
                            [--cost-cap C] [--freeze TEXT] [--run-by WHO]
  record-eval-run.py finish --state FILE [--result RESULT.json]
                            --runner-rc N --verdict-rc N [--verdict-line TEXT]

start  finds the issue from the branch name (issue-<number>-...), numbers the
       run (highest "**Eval run N" comment on the issue + 1), posts
       "**Eval run N: started**" and writes FILE. On any other branch, or with
       EVAL_RECORD_OFF=1, it does nothing and writes no FILE.
finish rewrites that same comment into the final record: the first line the
       Work Record uses, a per-case table, times, who ran it, the freeze
       status, and the same facts in a hidden block read by the Work Timeline
       page. Without FILE it does nothing.

A run that dies between the two leaves the "started" comment, which is the
record that it never finished.

Recording never decides anything: this script always exits 0, and a failure
to reach GitHub is a one-line warning on stderr.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRANCH = re.compile(r"^issue-(\d+)-")
RUN_LINE = re.compile(r"^\*\*Eval run (\d+)")
ISO = "%Y-%m-%dT%H:%M:%SZ"


class RecordError(Exception):
    pass


def now():
    return datetime.now(timezone.utc).strftime(ISO)


def gh(args, payload=None):
    try:
        p = subprocess.run(["gh", *args], input=payload, capture_output=True, text=True, cwd=REPO_ROOT, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise RecordError(f"gh could not run ({e})")
    if p.returncode != 0:
        raise RecordError((p.stderr or p.stdout).strip().splitlines()[-1] if (p.stderr or p.stdout).strip() else f"gh exited {p.returncode}")
    return p.stdout


def issue_from_branch():
    try:
        p = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True, cwd=REPO_ROOT, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    m = BRANCH.match(p.stdout.strip())
    return int(m.group(1)) if m else None


def next_run_number(issue):
    out = gh(["api", f"repos/{{owner}}/{{repo}}/issues/{issue}/comments", "--paginate",
              "--jq", '.[] | .body | split("\\n")[0]'])
    seen = [int(m.group(1)) for m in map(RUN_LINE.match, out.splitlines()) if m]
    return max(seen, default=0) + 1


def run_by(explicit):
    """Who started the run. A subagent's environment is identical to its parent
    session's (checked 2026-11-27), so "subagent" has to be said explicitly."""
    who = explicit or os.environ.get("EVAL_RUN_BY")
    if who:
        return who
    return "Claude session" if os.environ.get("CLAUDECODE") else "terminal"


def hidden(data):
    # "--" may not appear inside an HTML comment; escaping ">" and "-" keeps any case name safe.
    text = json.dumps(data, separators=(",", ":"), ensure_ascii=True).replace("-->", "--\\u003e")
    return f"<!-- work-timeline:eval {text} -->"


def clock(iso):
    return datetime.strptime(iso, ISO).strftime("%Y-%m-%d %H:%M UTC")


def money(x):
    return f"${x:g}" if isinstance(x, (int, float)) else str(x)


def graders_note(freeze):
    """One phrase about the suite's freeze state, from the runner's FREEZE lines."""
    lines = [l for l in (freeze or "").splitlines() if l.strip()]
    if not lines:
        return ""
    head = lines[0]
    m = re.match(r"FREEZE:\s*(\S+)", head)
    if "none" in head.split("—")[0]:
        return "no freeze commit"
    if "unchanged" in head:
        return f"unchanged since freeze {m.group(1)}" if m else "unchanged since the freeze"
    return f"{len(lines) - 1} eval file(s) changed since freeze {m.group(1)}" if m else "changed since the freeze"


def config_line(st):
    bits = [f"skill `{st['skill']}`"]
    if st.get("runs"):
        bits.append(f"{st['runs']} run{'' if str(st['runs']) == '1' else 's'} per case, with and without the plugin")
    if st.get("threshold"):
        bits.append(f"pass threshold {st['threshold']}")
    if st.get("cost_cap"):
        bits.append(f"cost cap ${st['cost_cap']}")
    return ", ".join(bits)


# --- reading the eval tool's result file ------------------------------------
# Shape confirmed against a real run (claude 2.1.332, schemaVersion 1):
#   cases[].name, cases[].aggregates{passRate, passRateWithout, delta},
#   cases[].arms{with, without}[] = one entry per attempt with
#   {passed, score, startedAt, durationSeconds, costUsd, error}; suite.threshold; partial.

def _num(v):
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def _end(attempt):
    """When an attempt ended, as an ISO string, or None."""
    try:
        t = datetime.strptime(str(attempt["startedAt"])[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)
        return (t + timedelta(seconds=float(attempt.get("durationSeconds") or 0))).strftime(ISO)
    except (KeyError, ValueError, TypeError):
        return None


def read_cases(result):
    """-> [{name, with, without, delta, pass}] (scores are pass rates). Tolerant: [] if the shape is unknown."""
    threshold = _num((result.get("suite") or {}).get("threshold"))
    cases = []
    for c in result.get("cases") or []:
        if not isinstance(c, dict):
            continue
        agg = c.get("aggregates") if isinstance(c.get("aggregates"), dict) else {}
        row = {"name": str(c.get("name") or "?")}
        w, wo, d = _num(agg.get("passRate")), _num(agg.get("passRateWithout")), _num(agg.get("delta"))
        if w is not None:
            row["with"] = round(w, 2)
        if wo is not None:
            row["without"] = round(wo, 2)
        if d is not None:
            row["delta"] = round(d, 2)
        if w is not None and threshold is not None:
            row["pass"] = w >= threshold
        cases.append(row)
    return cases


def read_milestones(result):
    """One milestone per case and arm, timed at its last attempt: how many attempts passed, with each attempt as detail."""
    out = []
    for c in result.get("cases") or []:
        arms = c.get("arms") if isinstance(c, dict) and isinstance(c.get("arms"), dict) else {}
        for arm, label in (("with", "with the plugin"), ("without", "without the plugin")):
            tries = [t for t in arms.get(arm) or [] if isinstance(t, dict)]
            if not tries:
                continue
            ends = [e for e in map(_end, tries) if e]
            ok = sum(1 for t in tries if t.get("passed") is True)
            errors = sum(1 for t in tries if t.get("error"))
            text = f"Case {c.get('name')}, {label}: {ok} of {len(tries)} attempts passed"
            if errors:
                text += f" ({errors} ended in an error)"
            detail = []
            for i, t in enumerate(tries, 1):
                bits = ["error: " + str(t["error"])[:200] if t.get("error") else ("passed" if t.get("passed") else "failed")]
                if _num(t.get("durationSeconds")) is not None:
                    bits.append(f"{t['durationSeconds']:g} s")
                if _num(t.get("turns")) is not None:
                    bits.append(f"{t['turns']:g} turns")
                if _num(t.get("costUsd")) is not None:
                    bits.append(f"${t['costUsd']:.2f}")
                detail.append(f"Attempt {i}: " + ", ".join(bits))
            m = {"text": text, "detail": "\n".join(detail)}
            if ends:
                m["at"] = max(ends)
            out.append(m)
    return out


def case_table(cases):
    if not cases:
        return ""
    f = lambda v: "–" if v is None else f"{v:.2f}"
    sd = lambda v: "–" if v is None else f"{v:+.2f}"
    res = lambda v: "–" if v is None else ("pass" if v else "**fail**")
    rows = ["| Case | Pass rate with plugin | Pass rate without | Delta | Result |", "|---|---|---|---|---|"]
    rows += [f"| {c['name']} | {f(c.get('with'))} | {f(c.get('without'))} | {sd(c.get('delta'))} | {res(c.get('pass'))} |" for c in cases]
    return "\n".join(rows)


# --- the two commands --------------------------------------------------------

def start(a):
    if os.environ.get("EVAL_RECORD_OFF"):
        return
    issue = issue_from_branch()
    if issue is None:
        print("RECORD: not on an issue-<number>-… branch, so this run is not posted to GitHub")
        return
    n = next_run_number(issue)
    st = {"issue": issue, "run": n, "skill": a.skill, "started": now(), "by": run_by(a.run_by),
          "runs": a.runs, "threshold": a.threshold, "cost_cap": a.cost_cap, "freeze": a.freeze or ""}
    st["milestones"] = [{"at": st["started"], "text": "Run started: " + config_line(st).replace("`", "")}]
    note = graders_note(st["freeze"])
    if note:
        st["milestones"].append({"at": st["started"], "text": f"Eval suite: {note}"})
    body = "\n".join([
        f"**Eval run {n}: started** — {config_line(st)}.",
        "",
        f"- Started {clock(st['started'])}, run by {st['by']}.",
        *( [f"- Eval suite: {note}."] if note else [] ),
        "",
        "_The eval runner replaces this comment with the result when the run ends. If it still says \"started\", the run did not finish._",
        "",
        hidden({"run": n, "skill": a.skill, "started": st["started"], "by": st["by"], "graders": note, "milestones": st["milestones"]}),
    ])
    out = gh(["api", f"repos/{{owner}}/{{repo}}/issues/{issue}/comments", "-X", "POST", "--input", "-", "--jq", ".id"],
             json.dumps({"body": body}))
    st["comment_id"] = int(out.strip())
    with open(a.state, "w") as f:
        json.dump(st, f)
    print(f"RECORD: eval run {n} posted to issue #{issue} as started")


def finish(a):
    if not os.path.exists(a.state) or os.path.getsize(a.state) == 0:
        return
    with open(a.state) as f:
        st = json.load(f)
    n, finished = st["run"], now()
    result = None
    if a.result and os.path.exists(a.result) and os.path.getsize(a.result) > 0:
        try:
            with open(a.result) as f:
                result = json.load(f)
        except ValueError:
            result = None
    agg = (result or {}).get("aggregates") or {}
    total, passed, delta = agg.get("casesTotal"), agg.get("casesPassed"), agg.get("meanDelta")
    cost = (result or {}).get("costUsd")
    verdict = {0: "PASS", 1: "FAIL"}.get(a.verdict_rc, "INVALID") if result is not None else "INVALID"

    facts = []
    if total is not None:
        facts.append(f"{passed}/{total} cases")
    if isinstance(delta, (int, float)):
        facts.append(f"mean delta {delta:+.2f}")
    if isinstance(cost, (int, float)):
        facts.append(f"${cost:.2f}")
    head = f"**Eval run {n}: {verdict}.**" + (" " + ", ".join(facts) if facts else "")
    if result is None:
        head += f" The eval tool exited with code {a.runner_rc} and left no result, so nothing was scored."

    cases = read_cases(result or {})
    mins = max(0, round((datetime.strptime(finished, ISO) - datetime.strptime(st["started"], ISO)).total_seconds() / 60))
    note = graders_note(st.get("freeze"))
    why = re.sub(r"^VERDICT:\s*\w+\s*—\s*", "", (a.verdict_line or "").strip())
    milestones = list(st.get("milestones") or [])
    if result is not None and a.runner_rc != 0:
        milestones.append({"at": finished, "text": f"Eval tool stopped early (exit code {a.runner_rc}); results may be partial"})
    for m in sorted(read_milestones(result or {}), key=lambda m: m.get("at") or finished):
        milestones.append({"at": m.get("at") or finished, "text": m["text"], "detail": m["detail"]})
    if (result or {}).get("partial"):
        milestones.append({"at": finished, "text": "The eval tool reported partial results"})
    milestones.append({"at": finished, "text": f"Verdict: {verdict}" + (f" — {why}" if why else "")})

    lines = [head, ""]
    if a.verdict_line and verdict != "PASS" and why:
        lines += [f"Why: {why}.", ""]
    if result is not None and (a.runner_rc != 0 or result.get("partial")):
        lines += [f"The eval tool stopped early (exit code {a.runner_rc}, for example the cost cap was reached), so these results may be partial.", ""]
    table = case_table(cases)
    if table:
        lines += [table, ""]
    lines += [
        f"- Run: {config_line(st)}.",
        f"- Started {clock(st['started'])}, finished {clock(finished)} ({mins} min), run by {st['by']}.",
        *( [f"- Eval suite: {note}."] if note else [] ),
    ]
    changed = [l.strip() for l in (st.get("freeze") or "").splitlines()[1:] if l.strip()]
    if changed:
        lines += ["- Eval files changed since the freeze: " + ", ".join(f"`{c}`" for c in changed) + "."]
    lines += ["", "_Recorded by the eval runner. What failed and why, and what was changed in response, follow in a separate comment._", ""]
    data = {"run": n, "verdict": verdict, "skill": st["skill"], "started": st["started"], "finished": finished, "by": st["by"],
            "graders": note, "cases": cases, "milestones": milestones}
    for k, v in (("passed", passed), ("total", total), ("delta", delta), ("cost", cost)):
        if isinstance(v, (int, float)):
            data[k] = round(v, 4)
    lines.append(hidden(data))
    gh(["api", f"repos/{{owner}}/{{repo}}/issues/comments/{st['comment_id']}", "-X", "PATCH", "--input", "-", "--jq", ".id"],
       json.dumps({"body": "\n".join(lines)}))
    print(f"RECORD: eval run {n} result ({verdict}) posted to issue #{st['issue']}")


def main():
    p = argparse.ArgumentParser(description="Post one eval run to its GitHub issue.")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("--state", required=True)
    s.add_argument("--skill", required=True)
    s.add_argument("--runs")
    s.add_argument("--threshold")
    s.add_argument("--cost-cap")
    s.add_argument("--freeze")
    s.add_argument("--run-by")
    f = sub.add_parser("finish")
    f.add_argument("--state", required=True)
    f.add_argument("--result")
    f.add_argument("--runner-rc", type=int, default=0)
    f.add_argument("--verdict-rc", type=int, default=0)
    f.add_argument("--verdict-line")
    try:
        a = p.parse_args()
    except SystemExit:
        print("RECORD: warning — bad arguments; this eval run was not recorded", file=sys.stderr)
        return
    try:
        (start if a.cmd == "start" else finish)(a)
    except Exception as e:  # recording must never break an eval run
        print(f"RECORD: warning — could not record this eval run on GitHub ({e})", file=sys.stderr)


if __name__ == "__main__":
    main()
    sys.exit(0)
