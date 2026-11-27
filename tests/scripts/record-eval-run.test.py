#!/usr/bin/env python3
"""Tests scripts/record-eval-run.py and its wiring in tests/run-skill-evals.sh (#1508).

No GitHub call and no model call: a throwaway git repo holds copies of the two
scripts, and pretend `gh` and `claude` commands sit first on PATH. The pretend
gh logs every call; the pretend claude writes a result file shaped like a real
`claude plugin eval --json` run.
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
passed, failed = 0, []


def check(name, ok, detail=""):
    global passed
    if ok:
        print(f"PASS: record-eval-run ({name})")
        passed += 1
    else:
        print(f"FAIL: record-eval-run ({name}) {detail}")
        failed.append(name)


GH = r'''#!/usr/bin/env python3
import json, os, sys
log = os.environ["GH_LOG"]
args = sys.argv[1:]
body = sys.stdin.read() if "--input" in args else ""
if os.environ.get("GH_FAIL"):
    sys.stderr.write("HTTP 500: boom\n"); sys.exit(1)
with open(log, "a") as f:
    f.write(json.dumps({"args": args, "body": json.loads(body)["body"] if body else ""}) + "\n")
if "POST" in args:
    print(555)
elif "PATCH" in args:
    print(555)
else:  # list of first lines of existing comments
    sys.stdout.write(os.environ.get("GH_EXISTING", ""))
'''

CLAUDE = r'''#!/usr/bin/env python3
import json, os, sys
out = sys.argv[sys.argv.index("--json") + 1]
if os.environ.get("CLAUDE_NO_RESULT"):
    sys.exit(2)
ok = not os.environ.get("CLAUDE_CASE_FAILS")
def tries(p, at): return [{"score": 1 if p else 0, "passed": p, "turns": 5, "costUsd": 0.25, "durationSeconds": 60,
                           "startedAt": at, "error": None}]
json.dump({"schemaVersion": 1, "costUsd": 1.5, "partial": False, "suite": {"threshold": 0.66},
  "cases": [
    {"name": "case-a", "arms": {"with": tries(True, "2026-01-02T10:00:00.000Z"), "without": tries(False, "2026-01-02T10:01:00.000Z")},
     "aggregates": {"passRate": 1, "passRateWithout": 0, "delta": 1}},
    {"name": "case-b", "arms": {"with": tries(ok, "2026-01-02T10:02:00.000Z"), "without": tries(False, "2026-01-02T10:03:00.000Z")},
     "aggregates": {"passRate": 1 if ok else 0, "passRateWithout": 0, "delta": 1 if ok else 0}}],
  "aggregates": {"casesTotal": 2, "casesPassed": 2 if ok else 1, "meanDelta": 1 if ok else 0.5}}, open(out, "w"))
'''

tmp = Path(tempfile.mkdtemp(prefix="record-eval-run."))
try:
    repo, bindir, log = tmp / "repo", tmp / "bin", tmp / "gh.log"
    for d in (repo / "scripts", repo / "tests", repo / "skills/demo", repo / "evals/demo/case-a", bindir):
        d.mkdir(parents=True)
    shutil.copy(REPO_ROOT / "scripts/record-eval-run.py", repo / "scripts")
    shutil.copy(REPO_ROOT / "tests/run-skill-evals.sh", repo / "tests")
    (repo / "evals/demo/case-a/prompt.md").write_text("prompt\n")
    (repo / "skills/demo/SKILL.md").write_text("demo\n")
    for name, src in (("gh", GH), ("claude", CLAUDE)):
        (bindir / name).write_text(src)
        (bindir / name).chmod(0o755)
    git = ["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.test"]
    subprocess.run([*git, "init", "-q", "-b", "main"], check=True)
    subprocess.run([*git, "add", "-A"], check=True)
    subprocess.run([*git, "commit", "-qm", "init"], check=True)

    base_env = {k: v for k, v in os.environ.items() if k not in ("CLAUDECODE", "EVAL_RUN_BY", "EVAL_RECORD_OFF")}
    base_env.update(PATH=f"{bindir}:{os.environ['PATH']}", GH_LOG=str(log))

    def run(*extra, **env):
        if log.exists():
            log.unlink()
        p = subprocess.run(["bash", str(repo / "tests/run-skill-evals.sh"), "demo", *extra],
                           capture_output=True, text=True, env={**base_env, **env})
        calls = [json.loads(l) for l in log.read_text().splitlines()] if log.exists() else []
        return p, calls

    # 1. Not on an issue branch: nothing is posted, the runner behaves as before.
    p, calls = run()
    check("on main nothing is posted", calls == [] and "not posted to GitHub" in p.stdout, p.stdout + p.stderr)
    check("on main the verdict and exit code are unchanged", p.returncode == 0 and "VERDICT: PASS — 2/2 cases passed" in p.stdout, p.stdout)

    subprocess.run([*git, "checkout", "-q", "-b", "issue-12-demo"], check=True)

    # 2. On an issue branch: one comment is posted, then the SAME comment is edited.
    p, calls = run()
    posts = [c for c in calls if "POST" in c["args"]]
    patches = [c for c in calls if "PATCH" in c["args"]]
    check("start posts exactly one comment to issue 12",
          len(posts) == 1 and "repos/{owner}/{repo}/issues/12/comments" in posts[0]["args"], str(calls)[:300])
    check("the first comment says the run started",
          bool(posts) and posts[0]["body"].startswith("**Eval run 1: started**") and "work-timeline:eval" in posts[0]["body"])
    check("finish edits that same comment and posts no second one",
          len(patches) == 1 and "repos/{owner}/{repo}/issues/comments/555" in patches[0]["args"], str(calls)[:300])
    final = patches[0]["body"] if patches else ""
    check("the final record starts with the Work Record first line",
          final.startswith("**Eval run 1: PASS.** 2/2 cases, mean delta +1.00, $1.50"), final[:120])
    check("the final record has a row per case", "| case-a | 1.00 | 0.00 | +1.00 | pass |" in final and "| case-b |" in final, final)
    block = final.split("work-timeline:eval ", 1)[-1].rsplit(" -->", 1)[0] if final else "{}"
    try:
        data = json.loads(block)
    except ValueError:
        data = {}
    check("the hidden block carries the exact results",
          data.get("verdict") == "PASS" and data.get("passed") == 2 and data.get("total") == 2 and data.get("delta") == 1
          and data.get("cost") == 1.5 and len(data.get("cases", [])) == 2 and data.get("started") and data.get("finished"), block[:300])
    texts = [m.get("text", "") for m in data.get("milestones", [])]
    check("milestones show how the run progressed",
          any(t.startswith("Run started") for t in texts)
          and "Case case-a, with the plugin: 1 of 1 attempts passed" in texts
          and "Case case-a, without the plugin: 0 of 1 attempts passed" in texts
          and any(t.startswith("Verdict: PASS") for t in texts), str(texts))
    check("who ran it defaults to terminal outside Claude Code", data.get("by") == "terminal", str(data.get("by")))
    check("the exit code is the verdict's", p.returncode == 0 and "VERDICT: PASS" in p.stdout)

    # 3. The run number follows the comments already on the issue.
    p, calls = run(GH_EXISTING="**Eval run 1: FAIL** (suite unchanged).\nsome other comment\n**Eval run 2: started** — x\n")
    posts = [c for c in calls if "POST" in c["args"]]
    check("the run number increments past existing runs", bool(posts) and posts[0]["body"].startswith("**Eval run 3: started**"),
          posts[0]["body"][:60] if posts else "no post")

    # 4. --run-by and the Claude Code default.
    p, calls = run("--run-by", "subagent")
    check("--run-by is recorded", any("run by subagent" in c["body"] for c in calls if "PATCH" in c["args"]))
    p, calls = run(CLAUDECODE="1")
    check("inside Claude Code the default is 'Claude session'", any("run by Claude session" in c["body"] for c in calls if "PATCH" in c["args"]))

    # 5. A failing case: FAIL is recorded and the runner still exits 1.
    p, calls = run(CLAUDE_CASE_FAILS="1")
    final = next((c["body"] for c in calls if "PATCH" in c["args"]), "")
    check("a failed run is recorded as FAIL with the reason",
          final.startswith("**Eval run 1: FAIL.** 1/2 cases, mean delta +0.50") and "1 of 2 case(s) failed" in final
          and "| case-b | 0.00 | 0.00 | +0.00 | **fail** |" in final, final[:400])
    check("a failed run still exits 1", p.returncode == 1)

    # 6. The eval tool leaves no result: recorded as INVALID, runner still exits 2.
    p, calls = run(CLAUDE_NO_RESULT="1")
    final = next((c["body"] for c in calls if "PATCH" in c["args"]), "")
    check("a run with no result is recorded as INVALID", final.startswith("**Eval run 1: INVALID.**") and "left no result" in final, final[:200])
    check("a run with no result still exits 2", p.returncode == 2 and "VERDICT: ERROR" in p.stderr)

    # 7. GitHub is unreachable: a warning, and the verdict and exit code do not change.
    p, calls = run(GH_FAIL="1")
    check("a GitHub failure is a warning, not an error",
          p.returncode == 0 and "VERDICT: PASS" in p.stdout and "RECORD: warning" in p.stderr and "boom" in p.stderr, p.stderr)
    p, calls = run(GH_FAIL="1", CLAUDE_CASE_FAILS="1")
    check("a GitHub failure leaves a failing run's exit code at 1", p.returncode == 1)

    # 8. The switch.
    p, calls = run(EVAL_RECORD_OFF="1")
    check("EVAL_RECORD_OFF=1 posts nothing", calls == [] and p.returncode == 0)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print(f"\n{passed} passed, {len(failed)} failed")
sys.exit(1 if failed else 0)
