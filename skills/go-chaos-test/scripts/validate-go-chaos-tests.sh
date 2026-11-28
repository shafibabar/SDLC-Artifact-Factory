#!/bin/bash
# validate-go-chaos-tests.sh <product root>
#
# Text checks on a Go product's chaos experiments and what runs them. It runs
# nothing and needs no Go, Docker or cluster. Each FAIL is a defect found in
# go-chaos-test 2.1.0 or forbidden by the product owner's decisions of
# 2026-11-28; each WARN needs a person's judgement.
#
#   chaos files      a chaos test, a chaos hook or the chaostest package without
#                    //go:build chaos (make ci and the coverage gate would compile it)
#   toxics           an AddToxic or RemoveToxic whose error is dropped
#   breaker tests    a breaker test that never asserts the open, half-open and
#                    closed states
#   manifests        a tenant, shared or platform namespace; the removed
#                    spec.scheduler field; a selector beyond the experiment's own
#                    namespace; a sustained fault with no duration
#   Chaos Mesh       installed anywhere but as a release line of the throwaway
#                    cluster, or from anything but the pinned chart
#   workflows        a chaos run on a pull request; a masked exit status
#   retries          an experiment that is retried
#   experiments      a definition the runner would reject
#
# Exit 0 = no FAIL; 1 = at least one FAIL; 2 = usage.
set -uo pipefail
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "usage: validate-go-chaos-tests.sh <product root>" >&2; exit 2; }
exec python3 -I - "$1" << 'PY'
import json, os, re, sys

root = os.path.realpath(sys.argv[1])
fails, warns = [], []
SKIP = {".git", "vendor", "node_modules", ".sdlc-memory"}
OWN = {"run-chaos-experiment.sh", "validate-go-chaos-tests.sh"}  # this skill's own scripts quote the patterns they check


def rel(path):
    return os.path.relpath(path, root)


def files(pred):
    for base, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP)
        for name in sorted(names):
            path = os.path.join(base, name)
            if name not in OWN and pred(rel(path), name):
                yield path


def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def fail(path, line, message):
    fails.append(f"FAIL: {rel(path)}:{line}: {message}")


def warn(path, line, message):
    warns.append(f"WARN: {rel(path)}:{line}: {message}")


def tagged(source):
    for line in source.splitlines():
        stripped = line.strip()
        if stripped.startswith("//go:build"):
            return re.search(r"\bchaos\b", stripped) is not None and "!chaos" not in stripped
        if stripped.startswith("package "):
            return False
    return False


# ------------------------------------------------------------- Go files
go_files = list(files(lambda r, n: n.endswith(".go")))
for path in go_files:
    src, name = read(path), os.path.basename(path)
    r = rel(path)
    is_chaos = ("chaos" in name or r.startswith("tests/chaos/") or "/chaostest/" in r
                or '"github.com/Shopify/toxiproxy' in src or re.search(r'/chaostest"', src) is not None)
    if is_chaos and not tagged(src):
        fail(path, 1, "a chaos file without //go:build chaos: make ci and the coverage gate would compile and run it (W3-D10)")
    for n, line in enumerate(src.splitlines(), 1):
        code = line.split("//", 1)[0]
        if re.search(r"\b(AddToxic|RemoveToxic|ResetState|Disable)\(", code):
            if re.search(r"(^|[{;])\s*(_\s*,\s*_|_)\s*=\s*[\w.]+\.(AddToxic|RemoveToxic|ResetState|Disable)\(", code) or (re.match(r"\s*[\w.]+\.(AddToxic|RemoveToxic|ResetState|Disable)\(", code) and "chaostest." not in code):
                fail(path, n, "a Toxiproxy call whose error is dropped: a failed AddToxic leaves no fault and the experiment passes on nothing")
    for match in re.finditer(r"func\s+(Test\w*[Bb]reaker\w*)\s*\(", src):
        body_start = match.end()
        nxt = re.search(r"\nfunc\s", src[body_start:])
        body = src[body_start: body_start + nxt.start() if nxt else len(src)]
        states = {s for s, pat in (("open", r"\"open\"|StateOpen"), ("half-open", r"\"half-open\"|StateHalfOpen"),
                                   ("closed", r"\"closed\"|StateClosed")) if re.search(pat, body)}
        if len(states) < 3 or not re.search(r"State\(|OnStateChange", body):
            line = src[:match.start()].count("\n") + 1
            fail(path, line, f"{match.group(1)} does not assert the breaker's states (found {sorted(states) or 'none'}): one call "
                             "that fails fast proves no breaker; drive past the threshold and assert closed, open, half-open and closed")
    if is_chaos and re.search(r"\bt\.Skip", src):
        warn(path, 1, "a chaos test that can skip: a skipped experiment must not read as a pass")

# ---------------------------------------------------------- manifests
yaml_files = list(files(lambda r, n: n.endswith((".yaml", ".yml"))))
for path in yaml_files:
    src = read(path)
    r = rel(path)
    if r.startswith(".github/"):
        continue
    for doc in re.split(r"^---\s*$", src, flags=re.M):
        if "chaos-mesh.org/" not in doc:
            continue
        kind = (re.search(r"^kind:\s*(\S+)", doc, re.M) or [None, ""])[1]
        own_ns = (re.search(r"^\s{2}namespace:\s*(\S+)", doc, re.M) or [None, ""])[1]
        offset = src.find(doc)
        for n, line in enumerate(doc.splitlines(), src[:offset].count("\n") + 1):
            if re.match(r"\s*scheduler:", line):
                fail(path, n, "spec.scheduler was removed in Chaos Mesh 2.0; a repeated fault is a Schedule resource")
            if re.search(r"(tenant|platform|shared|prod|production|staging|kube-system)", line) and re.search(r"namespaces?:|^\s*-\s", line):
                fail(path, n, "a tenant, shared, platform or production namespace: faults go only to the run's own throwaway cluster")
        for m in re.finditer(r"namespaces:\s*\[([^\]]*)\]", doc):
            names = [x.strip().strip("'\"") for x in m.group(1).split(",") if x.strip()]
            if names != [own_ns]:
                line = src[:offset + m.start()].count("\n") + 1
                fail(path, line, f"the selector reaches namespaces {names}; it must be exactly the experiment's own ({own_ns or 'none'})")
        if kind in ("NetworkChaos", "StressChaos", "HTTPChaos", "IOChaos", "TimeChaos", "DNSChaos") and not re.search(r"^\s*duration:", doc, re.M):
            warn(path, src[:offset].count("\n") + 1, f"a {kind} with no duration: only the runner's removal bounds it")
        if kind == "Schedule" and re.search(r"concurrencyPolicy:\s*Allow", doc):
            warn(path, src[:offset].count("\n") + 1, "a Schedule that allows overlapping runs widens the blast radius")

# ----------------------------------------------------- Chaos Mesh install
for path in files(lambda r, n: n in ("Makefile",) or n.endswith((".sh", ".yml", ".yaml", ".mk", ".conf"))):
    src, r = read(path), rel(path)
    for n, line in enumerate(src.splitlines(), 1):
        if re.search(r"helm\s+(install|upgrade)\b.*chaos-mesh", line):
            fail(path, n, "Chaos Mesh installed by hand: its daemon is privileged; it is installed only as a release line of the throwaway "
                          "cluster (E2E_RELEASES in tests/chaos/chaos-e2e.conf)")
        if re.search(r"install\.sh.*chaos|chaos-mesh\.org/install", line):
            fail(path, n, "Chaos Mesh's quick-start script: for trials only; install the pinned chart into the throwaway cluster")
        if re.search(r"kubectl\b.*\b(apply|create)\b.*(chaos|mesh)/", line) and "run-chaos-experiment" not in line and not r.startswith("lab/"):
            fail(path, n, "a chaos manifest applied outside run-chaos-experiment.sh: nothing confirms, watches or removes the fault")
    if re.search(r"chaos.*values", r) and r.endswith((".yaml", ".yml")) and "chaosDaemon" in src:
        if not re.search(r"runtime:\s*containerd", src):
            warn(path, 1, "chaosDaemon.runtime is not containerd: kind's nodes run containerd")
        if re.search(r"^\s*privileged:\s*false", src, re.M):
            warn(path, 1, "chaosDaemon.privileged: false still runs the daemon with host PID and host mounts; it changes no rule")
    if r.endswith(".conf"):
        for n, line in enumerate(src.splitlines(), 1):
            if re.match(r"\s*chaos-mesh\|", line) and not re.search(r"chaos-mesh-2\.8\.8\.tgz\|", line):
                fail(path, n, "the Chaos Mesh release is not the pinned, checked chart chaos-mesh-2.8.8.tgz")

# ---------------------------------------------------------- workflows
for path in files(lambda r, n: r.startswith(".github/workflows/") and n.endswith((".yml", ".yaml"))):
    src = read(path)
    if not re.search(r"make chaos|run-chaos-experiment|chaos-e2e\.conf", src):
        continue
    on = re.search(r"^on:\s*(.*?)(?=^\S)", src, re.M | re.S)
    if on and re.search(r"pull_request", on.group(0) + on.group(1)):
        fail(path, 1, "a chaos run on a pull request: chaos runs on its schedule and by hand only")
    for n, line in enumerate(src.splitlines(), 1):
        if re.search(r"continue-on-error:\s*true|\|\|\s*true|\|\s*tee\b", line):
            fail(path, n, "the exit status is masked: FAIL, INVALID and REFUSED must stop the job")
        if re.search(r"nick-fields/retry|--rerun-fails|retry_on|max_attempts", line):
            fail(path, n, "a retried chaos run: an experiment runs once (test-pyramid: 0 retries below end-to-end)")

for path in files(lambda r, n: n in ("Makefile",) or n.endswith((".sh", ".conf", ".yml", ".yaml", ".mk", ".json"))):
    src = read(path)
    for n, line in enumerate(src.splitlines(), 1):
        if "chaos" in line and re.search(r"--rerun-fails|-count[= ]([2-9]|\d\d)\b|\bfor\s+\w+\s+in\s+1\s+2|until\s+.*run-chaos", line):
            fail(path, n, "a retried or repeated experiment: an experiment runs once and its first result stands")
        if "run-chaos-experiment" in line and re.search(r"\|\|\s*true|^\s*-\./|\|\s*tee\b", line):
            fail(path, n, "the runner's exit status is masked")

# ---------------------------------------------------------- experiments
runner_present = os.path.isfile(os.path.join(root, "tests/chaos/run-chaos-experiment.sh"))
experiments = list(files(lambda r, n: r.startswith("tests/chaos/experiments/") and n.endswith(".json")))
if (experiments or any(re.search(r"chaos", rel(p)) for p in go_files)) and not runner_present:
    fails.append("FAIL: tests/chaos/run-chaos-experiment.sh: missing: every experiment starts through the runner")
for path in experiments:
    try:
        exp = json.load(open(path, encoding="utf-8"))
    except ValueError as exc:
        fail(path, 1, f"not JSON: {exc}")
        continue
    tool = (exp.get("fault") or {}).get("tool")
    for key in ("experiment_id", "pattern", "hypothesis", "blast_radius", "abort"):
        if not exp.get(key):
            fail(path, 1, f"no {key}")
    if tool in ("toxiproxy", "chaos-mesh"):
        st = exp.get("steady_state") or {}
        for key in ("slo_id", "sli", "endpoint", "path", "good_statuses", "under_ms", "objective", "window_seconds"):
            if not st.get(key):
                fail(path, 1, f"steady_state.{key} missing: the hypothesis is written on the SLO's output metric before injection")
        if re.search(r"p\d\d|percentile|average", str(st.get("sli", "")), re.I):
            warn(path, 1, "the SLI reads like a percentile or average; use the SLO record's ratio (good / valid) exactly")
        ab = exp.get("abort") or {}
        if not (ab.get("sli_below") and ab.get("over_seconds") and ab.get("max_seconds")):
            fail(path, 1, "abort needs sli_below, over_seconds and max_seconds: concrete numbers set before injection")
    if tool == "chaos-mesh":
        manifest = (exp.get("fault") or {}).get("manifest", "")
        if not os.path.isfile(os.path.join(root, manifest)):
            fail(path, 1, f"the manifest {manifest} does not exist")
    if tool == "go-test":
        command = (exp.get("fault") or {}).get("command", "")
        if not re.search(r"-tags[= ]\S*\bchaos\b", command) or not re.search(r"-count[= ]1\b", command):
            fail(path, 1, "the go test command needs -tags chaos and -count=1")
    if exp.get("retries") or exp.get("retry"):
        fail(path, 1, "an experiment is never retried")

for line in fails + warns:
    print(line)
print(f"{len(fails)} FAIL, {len(warns)} WARN")
sys.exit(1 if fails else 0)
PY
