#!/bin/bash
# write-pact-impact-report.sh --product <name> --date YYYY-MM-DD --results <dir>
#     [--owner <agent>] > artifacts/<product>/quality/test-reports/pact-impact-<date>.md
#
# Writes the daily Pact impact report from the answers the Pact Broker gave.
# <dir> holds one file per service and environment, each the output of
#   pact broker can-i-deploy --pacticipant <service> --version <commit>
#       --to-environment <environment> --output json > <dir>/<service>.<environment>.json
# (with --output json that command exits 0 even when the answer is "no", so
# this script's exit status, not the command's, is what fails the daily run).
# The report is built from these answers and not from the test run's exit
# status: a failing pending pact leaves the provider's test run green.
# A file that is not the broker's JSON (the command itself failed) is reported
# as "no result" and never as passing.
# Exit 0 = every flow verified, 1 = at least one flow broken, not verified or
# without a result (the report is still written), 2 = usage error or no files.
# The program below is the same as go-contract-test's script of the same name;
# the two are kept identical.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import json, os, re, sys

args = sys.argv[1:]
opts = {"owner": "test-strategist"}
while args:
    flag = args.pop(0)
    if flag in ("--product", "--date", "--results", "--owner") and args:
        opts[flag[2:]] = args.pop(0)
    else:
        print("usage: write-pact-impact-report.sh --product <name> --date YYYY-MM-DD --results <dir> [--owner <agent>]", file=sys.stderr)
        sys.exit(2)
if not all(key in opts for key in ("product", "date", "results")) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", opts["date"]):
    print("usage: give --product, --date YYYY-MM-DD and --results <dir>", file=sys.stderr)
    sys.exit(2)
try:
    names = sorted(n for n in os.listdir(opts["results"]) if n.endswith(".json"))
except OSError as exc:
    print(f"ERROR: cannot read {opts['results']}: {exc.strerror}", file=sys.stderr)
    sys.exit(2)
if not names:
    print(f"ERROR: no <service>.<environment>.json in {opts['results']}; nothing to report", file=sys.stderr)
    sys.exit(2)

def version(side):
    number = (side.get("version") or {}).get("number")
    return f"{side.get('name', '?')} {number}" if number else f"{side.get('name', '?')} (no verified version)"

services, flows = [], []
for name in names:
    service, _, environment = name[:-5].rpartition(".")
    if not service:
        service, environment = name[:-5], "?"
    try:
        with open(os.path.join(opts["results"], name), encoding="utf-8") as handle:
            answer = json.load(handle)
        summary = answer["summary"]
    except (OSError, ValueError, KeyError, TypeError):
        services.append((service, environment, "NO RESULT", "the broker gave no answer; see the run log"))
        continue
    if summary.get("deployable") is True:
        verdict = "verified"
    elif summary.get("failed"):
        verdict = "BROKEN"
    else:
        verdict = "NOT VERIFIED"
    services.append((service, environment, verdict, str(summary.get("reason", "")).replace("|", "/")))
    for row in answer.get("matrix") or []:
        result = row.get("verificationResult")
        state = "not verified" if result is None else ("passed" if result.get("success") else "FAILED")
        flows.append((environment, version(row.get("consumer") or {}), version(row.get("provider") or {}), state))

bad = [s for s in services if s[2] != "verified"]
out = [
    "---",
    f"name: pact-impact-{opts['date']}",
    "version: 1.0.0",
    "phase: quality",
    f"owner: {opts['owner']}",
    f"created: {opts['date']}",
    f"summary: Daily Pact run for {opts['product']} on {opts['date']}: {len(services) - len(bad)} of {len(services)} service and environment checks verified, {len(bad)} needing attention.",
    "traces-to: [implement/test-strategy.md]",
    "---",
    "",
    f"# Pact Impact Report: {opts['product']}, {opts['date']}",
    "",
    "What yesterday's code changes mean for the calls between services that are already in use."
    " Built from the Pact Broker's answers. Pact does not block a pull request, so a break listed here"
    " may already be merged; it cannot be deployed, because a deployment asks the broker first.",
    "",
    "## Result",
    "",
    (f"**{len(bad)} check(s) need attention.**" if bad else "**Every check is verified.**"),
    "",
    "| Service | Environment | Result | What the broker said |",
    "|---|---|---|---|",
]
out += [f"| {s} | {e} | {v} | {r} |" for s, e, v, r in services]
out += ["", "## Flows checked", "", "| Environment | Calling service | Called service | Verification |", "|---|---|---|---|"]
out += [f"| {e} | {c} | {p} | {s} |" for e, c, p, s in flows] or ["| (none) | | | |"]
out += [
    "",
    "## What each result means",
    "",
    "- **verified**: this commit works with every caller and called service now in that environment.",
    "- **BROKEN**: a caller's recorded expectation fails against this commit. It must not be deployed.",
    "- **NOT VERIFIED**: no verification is recorded for this pair, for example a new expectation the other side has not met yet, or nothing deployed there yet.",
    "- **NO RESULT**: the question could not be asked. Treated as a failure.",
    "",
    "## Action for each item needing attention",
    "",
]
out += [f"- {s} in {e} ({v}): [owner and fix, or the reason no fix is needed]" for s, e, v, _ in bad] or ["None."]
out += ["", "## Approval", "", "Product owner: [name], [date], [approved / comments]", ""]
print("\n".join(out))
sys.exit(1 if bad else 0)
PY
