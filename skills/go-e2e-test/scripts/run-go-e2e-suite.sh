#!/bin/bash
# run-go-e2e-suite.sh <journeys|smoke|quarantine> [-- <arguments for the test binary>]
#
# Runs one selection of the Go end-to-end package and gives the verdict the
# flaky-test policy (owned by test-pyramid) asks for:
#   journeys    go test -tags e2e, every test not listed in the quarantine file
#   smoke       go test -tags smoke -run '^TestSmoke' (read-only tests)
#   quarantine  go test -tags e2e, only the quarantined tests; never blocks,
#               except that a missing test or a passed deadline does
# A test that fails is run again once, by exact name. Failed twice = failed.
# Failed then passed = flaky: reported, written to the summary, exit still 0.
# A selection that runs no test fails. A build failure, a refusal in TestMain,
# a panic or a timeout is never retried.
#
# Environment: E2E_PACKAGE (default ./tests/e2e/), E2E_QUARANTINE_FILE (default
# tests/e2e/quarantine.txt; lines "TestName | issue URL | YYYY-MM-DD"),
# E2E_TEST_TIMEOUT (default 20m), E2E_RESULTS_DIR (default e2e-evidence/results),
# E2E_TODAY (YYYY-MM-DD, for testing the deadline check).
# Exit 0 = passed (flaky tests are listed); 1 = a test failed twice, the run
# broke, or a quarantine deadline has passed; 2 = usage or a malformed
# quarantine file; 3 = the selection ran no test.
set -uo pipefail
exec python3 -I - "$@" << 'PY'
import datetime, json, os, re, subprocess, sys

USAGE = "usage: run-go-e2e-suite.sh <journeys|smoke|quarantine> [-- <arguments for the test binary>]"
args = sys.argv[1:]
if not args or args[0] not in ("journeys", "smoke", "quarantine"):
    print(USAGE)
    sys.exit(2)
mode, extra = args[0], []
if len(args) > 1:
    if args[1] != "--":
        print(USAGE)
        sys.exit(2)
    extra = args[2:]

package = os.environ.get("E2E_PACKAGE", "./tests/e2e/")
quarantine_file = os.environ.get("E2E_QUARANTINE_FILE", "tests/e2e/quarantine.txt")
timeout = os.environ.get("E2E_TEST_TIMEOUT", "20m")
results = os.environ.get("E2E_RESULTS_DIR", "e2e-evidence/results")
today = os.environ.get("E2E_TODAY") or datetime.date.today().isoformat()
os.makedirs(results, exist_ok=True)

quarantined, overdue = [], []
if os.path.isfile(quarantine_file):
    for number, line in enumerate(open(quarantine_file, encoding="utf-8"), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [part.strip() for part in line.split("|")]
        if (len(parts) != 3 or not re.fullmatch(r"Test\w+", parts[0])
                or not re.fullmatch(r"https?://\S+", parts[1])
                or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", parts[2])):
            print(f"ERROR: {quarantine_file}:{number}: want 'TestName | issue URL | YYYY-MM-DD', got: {line}")
            sys.exit(2)
        quarantined.append({"test": parts[0], "issue": parts[1], "deadline": parts[2]})
        if today > parts[2] and mode != "smoke":
            overdue.append(parts)


def exact(names):
    return "^(" + "|".join(re.escape(name) for name in names) + ")$"


def go_test(tag, select, attempt):
    """One go test run. Returns (exit status, {top-level test: outcome}, {test: trace id})."""
    command = ["go", "test", "-tags", tag, "-count=1", "-timeout", timeout, "-json", *select, package]
    if extra:
        command += ["-args", *extra]
    print("+ " + " ".join(command), flush=True)
    path = os.path.join(results, f"{mode}-attempt{attempt}.json")
    outcome, traces = {}, {}
    with open(path, "w", encoding="utf-8") as raw:
        run = subprocess.Popen(command, stdout=subprocess.PIPE, text=True)
        for line in run.stdout:
            raw.write(line)
            try:
                event = json.loads(line)
            except ValueError:
                print(line, end="")
                continue
            test, action = event.get("Test"), event.get("Action")
            if action in ("output", "build-output"):
                text = event.get("Output", "")
                print(text, end="")
                found = re.search(r"\btrace_id=([0-9a-f]{32})\b", text)
                if test and found:
                    traces[test.split("/")[0]] = found.group(1)
            elif test and "/" not in test and action in ("pass", "fail", "skip"):
                outcome[test] = action
        status = run.wait()
    sys.stdout.flush()
    return status, outcome, traces


if mode == "smoke":
    tag, select = "smoke", ["-run", "^TestSmoke"]
elif mode == "journeys":
    tag, select = "e2e", ["-run", "^Test"]
    if quarantined:
        select += ["-skip", exact(q["test"] for q in quarantined)]
else:
    tag = "e2e"
    if not quarantined:
        print("quarantine: the list is empty; nothing to run")
        sys.exit(0)
    select = ["-run", exact(q["test"] for q in quarantined)]

status, first, traces = go_test(tag, select, 1)
failed = sorted(name for name, result in first.items() if result == "fail")
second, flaky, failed_twice, broke = {}, [], [], False
if mode == "quarantine":
    failed_twice = []          # reported below, never blocking
elif status != 0 and not failed:
    broke = True               # build failure, TestMain refusal, panic or timeout
elif failed:
    print(f"== retrying once, by exact name: {', '.join(failed)}", flush=True)
    retry_status, second, retry_traces = go_test(tag, ["-run", exact(failed)], 2)
    for name in failed:
        if second.get(name) == "pass":
            flaky.append({"test": name, "attempt_1": "fail", "attempt_2": "pass", "trace_id": traces.get(name, "")})
        else:
            failed_twice.append({"test": name, "trace_id": retry_traces.get(name) or traces.get(name, "")})

ran = [name for name, result in first.items() if result in ("pass", "fail")]
missing = [q["test"] for q in quarantined if mode == "quarantine" and q["test"] not in first]
summary = {
    "mode": mode, "tag": tag, "date": today,
    "ran": len(ran),
    "passed": sorted(name for name, result in first.items() if result == "pass"),
    "skipped": sorted(name for name, result in first.items() if result == "skip"),
    "flaky": flaky, "failed": failed_twice if mode != "quarantine" else [],
    "quarantined": [] if mode == "smoke" else quarantined,
    "quarantine_results": first if mode == "quarantine" else {},
    "broke": broke,
}
with open(os.path.join(results, f"{mode}-summary.json"), "w", encoding="utf-8") as out:
    json.dump(summary, out, indent=2, sort_keys=True)
    out.write("\n")

print(f"== {mode}: {len(ran)} ran, {len(summary['passed'])} passed first time, "
      f"{len(flaky)} flaky, {len(summary['failed'])} failed, {len(summary['skipped'])} skipped, "
      f"{0 if mode == 'smoke' else len(quarantined)} quarantined")
for entry in flaky:
    print(f"FLAKY {entry['test']}: failed, then passed on the one retry (trace_id={entry['trace_id'] or 'none printed'}). "
          "Record it; a second flake means quarantine.")
for entry in summary["failed"]:
    print(f"FAIL {entry['test']}: failed twice (trace_id={entry['trace_id'] or 'none printed'})")
for entry in quarantined if mode != "smoke" else []:
    if mode == "quarantine":
        print(f"QUARANTINED {entry['test']}: {first.get(entry['test'], 'did not run')} "
              f"(issue {entry['issue']}, deadline {entry['deadline']}); not blocking")
    else:
        print(f"QUARANTINED {entry['test']}: skipped here, proves nothing (issue {entry['issue']}, deadline {entry['deadline']})")

if broke:
    print("FAIL: the run broke before or outside a test (build failure, a refusal in TestMain, a panic or a timeout). Not retried.")
    sys.exit(1)
if not ran:
    print(f"FAIL: the {mode} selection ran no test. A selection that runs nothing proves nothing.")
    sys.exit(3)
if missing:
    print(f"FAIL: quarantined but not found in the package: {', '.join(missing)}. Remove the entry or fix the name.")
    sys.exit(1)
if overdue:
    for name, issue, deadline in overdue:
        print(f"FAIL: quarantine deadline {deadline} has passed for {name} ({issue}). "
              "Restore it, or delete it with a record; the gate stays red until then.")
    sys.exit(1)
sys.exit(1 if summary["failed"] else 0)
PY
