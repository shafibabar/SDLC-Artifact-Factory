#!/bin/bash
# run-python-e2e-suite.sh <journeys|smoke|quarantine>
#
# Runs one selection of the Python end-to-end tests with pytest and gives the
# verdict the flaky-test policy (owned by test-pyramid) asks for:
#   journeys    tests/e2e/journeys, -m "e2e and not smoke", every test not listed
#               in the quarantine file
#   smoke       tests/e2e/smoke, -m smoke (read-only tests)
#   quarantine  tests/e2e/journeys, only the quarantined tests; never blocks,
#               except that a missing test or a passed deadline does
# A test that fails is run again once, by exact node id, in a new pytest process.
# Failed twice = failed. Failed then passed = flaky: reported, written to the
# summary, exit still 0. A selection that runs no test fails, whatever pytest's
# own exit status says. A refusal by the guard, a collection error, a usage
# error, an interrupt or the time limit is never retried.
#
# The verdict is this script's, not pytest's: pytest exits 0 when every test
# was skipped, and a rerun plugin exits 0 when a test passed on its rerun. The
# product's addopts and PYTEST_ADDOPTS are cleared and any rerun plugin is
# switched off, so nothing can narrow the selection or add retries.
#
# Environment: E2E_PY_DIR (default tests/e2e), E2E_PY_QUARANTINE_FILE (default
# <E2E_PY_DIR>/quarantine-python.txt; lines "<node id> | issue URL | YYYY-MM-DD"),
# E2E_PY_TIMEOUT (seconds for one pytest process, default 1200), E2E_PYTHON
# (default python3: the one of the product's environment, e.g. under `uv run`),
# E2E_RESULTS_DIR (default e2e-evidence/results), E2E_TODAY (YYYY-MM-DD, for
# testing the deadline check).
# Exit 0 = passed (flaky tests are listed); 1 = a test failed twice, the run
# broke, or a quarantine deadline has passed; 2 = usage or a malformed
# quarantine file; 3 = the selection ran no test.
set -uo pipefail
exec python3 -I - "$@" << 'PY'
import datetime, json, os, re, signal, subprocess, sys, tempfile

USAGE = "usage: run-python-e2e-suite.sh <journeys|smoke|quarantine>"
args = sys.argv[1:]
if len(args) != 1 or args[0] not in ("journeys", "smoke", "quarantine"):
    print(USAGE)
    sys.exit(2)
mode = args[0]

base = os.environ.get("E2E_PY_DIR", "tests/e2e").rstrip("/")
quarantine_file = os.environ.get("E2E_PY_QUARANTINE_FILE", f"{base}/quarantine-python.txt")
results = os.environ.get("E2E_RESULTS_DIR", "e2e-evidence/results")
python = os.environ.get("E2E_PYTHON", "python3")
today = os.environ.get("E2E_TODAY") or datetime.date.today().isoformat()
try:
    limit = float(os.environ.get("E2E_PY_TIMEOUT", "1200"))
except ValueError:
    print("ERROR: E2E_PY_TIMEOUT must be a number of seconds")
    sys.exit(2)
folder = f"{base}/smoke" if mode == "smoke" else f"{base}/journeys"
marker = "smoke" if mode == "smoke" else "e2e and not smoke"
if not os.path.isdir(folder):
    print(f"FAIL: no folder {folder}: the {mode} selection ran no test. A selection that runs nothing proves nothing.")
    sys.exit(3)
os.makedirs(results, exist_ok=True)

quarantined, overdue = [], []
if os.path.isfile(quarantine_file):
    for number, line in enumerate(open(quarantine_file, encoding="utf-8"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [part.strip() for part in line.split("|")]
        if (len(parts) != 3 or not re.fullmatch(re.escape(base) + r"/journeys/\S+\.py::\S+", parts[0])
                or not re.fullmatch(r"https?://\S+", parts[1])
                or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", parts[2])):
            print(f"ERROR: {quarantine_file}:{number}: want '{base}/journeys/<file>.py::<test> | issue URL | YYYY-MM-DD', got: {line}")
            sys.exit(2)
        quarantined.append({"test": parts[0], "issue": parts[1], "deadline": parts[2]})
        if today > parts[2] and mode != "smoke":
            overdue.append(parts)

# The plugin this script hands to pytest: it applies the quarantine list and
# the retry selection by exact node id, and writes one line per test phase.
PLUGIN = r'''
import json, os, re

import pytest

_EVENTS = os.environ["E2E_RUNNER_EVENTS"]
_KEEP = json.loads(os.environ["E2E_RUNNER_KEEP"])
_DROP = set(json.loads(os.environ["E2E_RUNNER_DROP"]))


def _emit(record):
    with open(_EVENTS, "a", encoding="utf-8") as out:
        out.write(json.dumps(record) + "\n")


@pytest.hookimpl(trylast=True)
def pytest_collection_modifyitems(config, items):
    _emit({"event": "collected", "ids": [item.nodeid for item in items]})
    keep = set(_KEEP) if _KEEP is not None else None
    dropped = [item for item in items if item.nodeid in _DROP or (keep is not None and item.nodeid not in keep)]
    if dropped:
        config.hook.pytest_deselected(items=dropped)
        gone = {id(item) for item in dropped}
        items[:] = [item for item in items if id(item) not in gone]
    _emit({"event": "selected", "ids": [item.nodeid for item in items]})


def pytest_runtest_logreport(report):
    text = report.longreprtext + "\n" + "\n".join(content for _, content in report.sections)
    trace = re.search(r"\btrace_id=([0-9a-f]{32})\b", text)
    _emit({"event": "report", "id": report.nodeid, "when": report.when, "outcome": report.outcome,
           "refused": "REFUSED:" in report.longreprtext, "trace": trace.group(1) if trace else ""})
'''


def pytest_run(attempt, keep, drop):
    """One pytest process. Returns (exit status or 'timeout', {node id: outcome},
    {node id: trace id}, collected node ids, refused)."""
    stem = os.path.join(results, f"python-{mode}-attempt{attempt}")
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "e2e_runner_plugin.py"), "w", encoding="utf-8") as out:
            out.write(PLUGIN)
        events = os.path.join(tmp, "events.jsonl")
        open(events, "w").close()
        env = {k: v for k, v in os.environ.items() if k != "PYTEST_ADDOPTS"}
        env["PYTHONPATH"] = tmp + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
        env.update(E2E_RUNNER_EVENTS=events, E2E_RUNNER_KEEP=json.dumps(keep), E2E_RUNNER_DROP=json.dumps(drop))
        command = [python, "-m", "pytest", folder, "-m", marker, "-o", "addopts=", "-p", "e2e_runner_plugin",
                   "-p", "no:rerunfailures", "-p", "no:flaky", "-p", "no:cacheprovider", "-v", f"--junitxml={stem}.xml"]
        print("+ " + " ".join(command), flush=True)
        try:
            # SIGINT is set back to its default in the child: when this script was
            # itself started in the background the signal arrives ignored, and
            # pytest could then not be stopped in an orderly way at the time limit.
            run = subprocess.Popen(command, env=env, preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
        except OSError as exc:
            print(f"ERROR: cannot run {python}: {exc}")
            sys.exit(2)
        try:
            status = run.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            print(f"== time limit of {limit:g}s reached: stopping pytest", flush=True)
            run.send_signal(signal.SIGINT)   # pytest then runs teardown and writes its report
            try:
                run.wait(timeout=30)
            except subprocess.TimeoutExpired:
                run.kill()
                run.wait()
            status = "timeout"
        outcome, traces, collected, refused = {}, {}, [], False
        for line in open(events, encoding="utf-8"):
            record = json.loads(line)
            if record["event"] == "collected":
                collected = record["ids"]
            elif record["event"] == "report":
                name, result = record["id"], record["outcome"]
                refused = refused or record["refused"]
                if record["trace"]:
                    traces[name] = record["trace"]
                # failed in any phase = failed; skipped in setup or call = skipped;
                # passed only when the call passed and nothing failed.
                if result == "failed":
                    outcome[name] = "fail"
                elif result == "skipped" and outcome.get(name) != "fail":
                    outcome[name] = "skip"
                elif record["when"] == "call" and result == "passed" and name not in outcome:
                    outcome[name] = "pass"
        with open(f"{stem}.json", "w", encoding="utf-8") as out:
            json.dump({"exit": status, "outcome": outcome, "trace_ids": traces}, out, indent=2, sort_keys=True)
            out.write("\n")
    sys.stdout.flush()
    return status, outcome, traces, collected, refused


names = [q["test"] for q in quarantined]
if mode == "quarantine":
    if not quarantined:
        print("quarantine: the list is empty; nothing to run")
        sys.exit(0)
    keep, drop = names, []
elif mode == "journeys":
    keep, drop = None, names
else:
    keep, drop = None, []

status, first, traces, collected, refused = pytest_run(1, keep, drop)
if refused:
    first = {}                 # nothing ran: the guard stopped every test before its first request
failed =sorted(name for name, result in first.items() if result == "fail")
flaky, failed_twice, broke = [], [], ""
if refused:
    broke = "the guard refused the target"
elif status == "timeout":
    broke = f"the time limit of {limit:g}s was reached"
elif status not in (0, 1, 5) or (status == 1 and not failed):
    broke = f"pytest exited {status} outside a test (2 = collection error or interrupt, 3 = internal error, 4 = usage error)"
elif mode == "quarantine":
    pass                       # reported below, never blocking
elif failed:
    print(f"== retrying once, by exact node id: {', '.join(failed)}", flush=True)
    retry_status, second, retry_traces, _, retry_refused = pytest_run(2, failed, [])
    for name in failed:
        if second.get(name) == "pass" and not retry_refused:
            flaky.append({"test": name, "attempt_1": "fail", "attempt_2": "pass", "trace_id": traces.get(name, "")})
        else:
            failed_twice.append({"test": name, "trace_id": retry_traces.get(name) or traces.get(name, "")})

ran = [name for name, result in first.items() if result in ("pass", "fail")]
missing = [name for name in names if mode == "quarantine" and name not in collected]
summary = {
    "mode": mode, "runner": "pytest", "date": today,
    "ran": len(ran),
    "passed": sorted(name for name, result in first.items() if result == "pass"),
    "skipped": sorted(name for name, result in first.items() if result == "skip"),
    "flaky": flaky, "failed": failed_twice,
    "quarantined": [] if mode == "smoke" else quarantined,
    "quarantine_results": first if mode == "quarantine" else {},
    "broke": broke,
}
with open(os.path.join(results, f"python-{mode}-summary.json"), "w", encoding="utf-8") as out:
    json.dump(summary, out, indent=2, sort_keys=True)
    out.write("\n")

print(f"== python {mode}: {len(ran)} ran, {len(summary['passed'])} passed first time, "
      f"{len(flaky)} flaky, {len(failed_twice)} failed, {len(summary['skipped'])} skipped, "
      f"{0 if mode == 'smoke' else len(quarantined)} quarantined")
for entry in flaky:
    print(f"FLAKY {entry['test']}: failed, then passed on the one retry (trace_id={entry['trace_id'] or 'none printed'}). "
          "Not green: record it; a second flake means quarantine.")
for entry in failed_twice:
    print(f"FAIL {entry['test']}: failed twice (trace_id={entry['trace_id'] or 'none printed'})")
for entry in quarantined if mode != "smoke" else []:
    if mode == "quarantine":
        print(f"QUARANTINED {entry['test']}: {first.get(entry['test'], 'did not run')} "
              f"(issue {entry['issue']}, deadline {entry['deadline']}); not blocking, and not counted as passed")
    else:
        print(f"QUARANTINED {entry['test']}: left out here, proves nothing (issue {entry['issue']}, deadline {entry['deadline']})")

if broke:
    print(f"FAIL: the run broke: {broke}. Not retried.")
    sys.exit(1)
if not ran:
    print(f"FAIL: the {mode} selection ran no test (pytest exited {status}). A selection that runs nothing proves nothing.")
    sys.exit(3)
if missing:
    print(f"FAIL: quarantined but not found in {folder}: {', '.join(missing)}. Remove the entry or fix the node id.")
    sys.exit(1)
if overdue:
    for name, issue, deadline in overdue:
        print(f"FAIL: quarantine deadline {deadline} has passed for {name} ({issue}). "
              "Restore it, or delete it with a record; the gate stays red until then.")
    sys.exit(1)
sys.exit(1 if failed_twice else 0)
PY
