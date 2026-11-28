#!/bin/bash
# write-load-report.sh <result.json>...
#
# Prints the load-test report (Markdown, with the artifact frontmatter) for one
# run, from the result files run-load-test.sh wrote (<type>-result.json). All
# files must come from the same tier, product and commit. The agent writes the
# output with Write to artifacts/<product>/quality/test-reports/ and completes
# the two marked sections; the product owner approves it. Nothing is measured
# or judged here: every number and verdict is copied from the result files.
# Exit 0 = report printed; 2 = usage, an unreadable file, or files that do not
# belong to one run.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: write-load-report.sh <result.json>..." >&2
  exit 2
fi
exec python3 -I - "$@" << 'PY'
import json, sys

results = []
for path in sys.argv[1:]:
    try:
        data = json.load(open(path, encoding="utf-8"))
        for key in ("verdict", "tier", "type", "target", "nfr", "slo", "shape", "thresholds", "validity", "commit", "ended"):
            data[key]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"ERROR: {path} is not a result file of run-load-test.sh ({exc!r})", file=sys.stderr)
        sys.exit(2)
    results.append(data)
first = results[0]
for other in results[1:]:
    for key in ("tier", "commit", "product"):
        if other.get(key) != first.get(key):
            print(f"ERROR: the result files differ in {key}: one report covers one run of one tier", file=sys.stderr)
            sys.exit(2)

tier, date, product = first["tier"], first["ended"][:10], first.get("product") or "[product]"
order = ["INVALID", "ABORTED", "FAIL", "INDICATIVE PASS", "MEASURED", "PASS"]
overall = min((r["verdict"] for r in results), key=order.index)
nfr, slo = first["nfr"], first["slo"]
indicative = tier == "indicative"
each = ", ".join(f"{r['type']} {r['verdict']}" for r in results)
summary = (f"{'Indicative load check' if indicative else 'Load-test verdict'} for {product} at commit {first['commit'][:12]}: {each}."
           + (" Proves nothing about capacity." if indicative else f" Targets from {nfr['id']}."))
fmt = lambda v: f"{v:.2f}" if isinstance(v, float) else str(v)
cell = lambda v: str(v).replace("|", "\\|").replace("\n", " ")

out = []
add = out.append
add("---")
add(f"name: load-test-report-{date}")
add("version: 1.0.0")
add("phase: quality")
add("owner: test-strategist")
add(f"created: {date}")
add(f"summary: {summary[:200]}")
add(f"traces-to: [ideate/nfr-specification.md ({nfr['id']}), the SLO record ({slo['availability']['id']}, {slo['latency']['id']}), commit {first['commit'][:12]}]")
add("---")
add("")
add(f"# Load Test Report: {product}, {date}")
add("")
add("## Verdict")
add("")
add(f"**{overall}** ({tier} tier). {each}.")
add("")
if indicative:
    add("**Indicative only.** This run was made in a throwaway kind cluster on the machine that also ran the load generator. "
        "It can show a change between two runs. It proves nothing about capacity and does not show that any stated target is met; "
        "that needs a verdict run in the product's designated performance environment.")
else:
    add("The verdict holds for the environment, sizing and data recorded below, at the load the profile states, for the length of this run.")
add("")
for r in results:
    for reason in r.get("reasons", []):
        add(f"- {r['type']}: {cell(reason)}")
add("")
add("## Run")
add("")
add("| Item | Value |")
add("|---|---|")
add(f"| Tier | {tier} |")
add(f"| Commit | {first['commit']} |")
add(f"| Environment | {cell(first['target']['environment'])} |")
add(f"| Address | {first['target']['base_url']} |")
designation = first["target"].get("designation")
if designation:
    add(f"| Designation record | {designation['designation_id']}: approved by {cell(designation['approved_by'])} on {designation['approved_on']}, expires {designation['expires_on']} |")
    add(f"| Sizing (from the record) | {cell(designation['sizing'])} |")
    add(f"| Data (from the record) | {cell(designation['data'])} |")
    add(f"| Load generator (from the record) | {cell(designation.get('generator', ''))} |")
    add(f"| Tokens | issued for the run, at most {designation['token_max_minutes']} minutes, deleted after it |")
else:
    add("| Designation record | none: the indicative tier needs none and stores no credential |")
add(f"| Started / ended (UTC) | {first['started']} / {results[-1]['ended']} |")
add(f"| Tool | {cell(first.get('k6', 'k6'))} |")
add("| Retries | 0 |")
add("")
add("## Targets and where they come from")
add("")
add("| Source | Id | What it states |")
add("|---|---|---|")
add(f"| NFR | {nfr['id']} ({nfr['level']}) | Environment: {cell(nfr['environment'])} |")
add(f"| SLO, errors | {slo['availability']['id']} | objective {slo['availability']['objective']}; good statuses {cell(json.dumps(slo['availability']['good_statuses']))} |")
add(f"| SLO, latency | {slo['latency']['id']} | p({slo['latency']['percentile']}) under {slo['latency']['under_ms']} ms |")
add(f"| Rate limit | {cell(first['limiter']['source'])} | {first['limiter']['per_subject_per_second']}/s per subject, burst {first['limiter']['burst']} |")
add("")
add("## Profile and judgement calls")
add("")
add("Numbers the sources do not give (run length, ramp, virtual users, data volume, any reduced or raised rate) are decisions, recorded here with who made them.")
add("")
data = first.get("data") or {}
add(f"Test data: {cell(data.get('description', ''))}; requests spread over {data.get('distinct_items', '')} items. Decided by {cell(data.get('decided_by', ''))}: {cell(data.get('reason', ''))}.")
add("")
add("| Test type | Shape | Subjects | Decided by | Reason |")
add("|---|---|---|---|---|")
for r in results:
    shape = "; ".join(f"{k} {v}" for k, v in r["shape"].items() if k not in ("decided_by", "reason"))
    add(f"| {r['type']} | {cell(shape)} | {r.get('subjects', '')} | {cell(r['shape'].get('decided_by', ''))} | {cell(r['shape'].get('reason', ''))} |")
add("")
add("## Thresholds and results")
add("")
for r in results:
    add(f"### {r['type']}: {r['verdict']} (k6 exit status {r['k6_exit']})")
    add("")
    add(f"Requests: {fmt(r.get('requests'))} at {fmt(r.get('request_rate') or 0.0)}/s. Latency of answers the SLI counts as good (`{r.get('latency_metric', '')}`), in ms: "
        + ", ".join(f"{k} {fmt(v)}" for k, v in sorted(r.get("latency", {}).items())) + ".")
    add("")
    add("| Metric | Threshold | Result | Observed |")
    add("|---|---|---|---|")
    for t in r["thresholds"]:
        seen = ", ".join(f"{k} {fmt(v)}" for k, v in sorted(t["values"].items()) if k in ("rate", "count", "value", "max") or k.startswith("p("))
        add(f"| `{t['metric']}` | `{t['threshold']}` | {'held' if t['ok'] else '**crossed**'} | {seen} |")
    add("")
add("## Validity")
add("")
add("A run that dropped iterations or saturated its generator is invalid, not passed.")
add("")
add("| Test type | Dropped iterations | Generator CPU share (of its CPUs) | Verdict |")
add("|---|---|---|---|")
for r in results:
    v = r["validity"]
    add(f"| {r['type']} | {v['dropped_iterations']} | {v['generator_cpu_share']:.1%} of {v['generator_cpus']} | {r['verdict']} |")
add("")
comparisons = [r for r in results if r.get("comparison")]
if comparisons:
    add("## Comparison with the previous run")
    add("")
    add("Two indicative runs are compared only when the test type, its shape, the scripts and profile, the k6 version and the runner (CPU count, architecture, system, runner class) are the same.")
    add("")
    for r in comparisons:
        c = r["comparison"]
        line = f"- {r['type']}, `{c['metric']}`: now {fmt(c.get('now_ms'))} ms"
        if "previous_ms" in c:
            line += f", previous {fmt(c['previous_ms'])} ms, change {c['change_percent']}% (tolerance {c.get('tolerance_percent')}%)"
        add(line + f". Outcome: {c['outcome']}.")
    add("")
add("## The product's own measurements")
add("")
add("[From the environment's own Prometheus, each query pinned to the run's start and end, or \"not read\". Never from another environment's monitoring.]")
add("")
add("## What this run does not prove")
add("")
for item in first.get("does_not_prove", []):
    add(f"- {item}")
add("- [Add what is specific to this product and run.]")
add("")
add("## Not run or unverified")
add("")
add("[Every planned test type that did not run, and anything in this report that was not observed, with the reason.]")
add("")
add("## Approval")
add("")
add("| Product owner | Decision | Date | Comments |")
add("|---|---|---|---|")
add("| | approved / rejected | | |")
print("\n".join(out))
PY
