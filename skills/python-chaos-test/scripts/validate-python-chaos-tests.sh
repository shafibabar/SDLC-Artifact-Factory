#!/bin/bash
# validate-python-chaos-tests.sh <product root>
#
# Text checks on a Python product's chaos experiments and what runs them. It
# runs nothing and needs no Python package, Docker or cluster. Each FAIL is a
# defect found in python-chaos-test 1.2.0 or forbidden by the product owner's
# decisions of 2026-11-28; each WARN needs a person's judgement.
#
#   chaos files      a chaos test outside tests/chaos/ (the coverage gate leaves
#                    out only that folder, --skip-suite chaos); tests/chaos/
#                    without the conftest.py that marks every test `chaos` and
#                    refuses a run the runner did not start; a coverage-gate line
#                    without --skip-suite chaos
#   toxics           the toxiproxy-python client (its add_toxic returns nothing:
#                    a refused toxic is never noticed)
#   breaker tests    a breaker test that never reads the breaker's state or
#                    misses open, half-open or closed
#   retries          a tenacity retry with no stop (it retries forever); an
#                    experiment or a pytest run that is retried
#   event loop       a blocking call (time.sleep, requests) inside async def in
#                    the product's code (WARN: the whole worker stalls)
#   manifests, Chaos Mesh, workflows, experiments: as go-chaos-test's validator
#
# The block from "manifests" to "experiments" is go-chaos-test's own, kept
# identical by tests/scripts/python-chaos-copies.test.sh: change both together.
#
# Exit 0 = no FAIL; 1 = at least one FAIL; 2 = usage.
set -uo pipefail
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "usage: validate-python-chaos-tests.sh <product root>" >&2; exit 2; }
exec python3 -I - "$1" << 'PY'
import ast, json, os, re, sys

root = os.path.realpath(sys.argv[1])
fails, warns = [], []
SKIP = {".git", "vendor", "node_modules", ".sdlc-memory", ".venv", "venv", "__pycache__", ".tox"}
# These quote the patterns they check (the coverage gate names itself in its usage line).
OWN = {"run-chaos-experiment.sh", "validate-python-chaos-tests.sh", "validate-go-chaos-tests.sh", "check-python-coverage.sh"}


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


def call_name(node):
    func = node.func if isinstance(node, ast.Call) else node
    if isinstance(func, ast.Attribute):
        return func.attr
    return func.id if isinstance(func, ast.Name) else ""


# ---------------------------------------------------------- Python files
py_files = list(files(lambda r, n: n.endswith(".py")))
chaos_tests = []
for path in py_files:
    src, name, r = read(path), os.path.basename(path), rel(path)
    in_chaos = r.startswith("tests/chaos/")
    is_test = name.startswith("test_") or name.endswith("_test.py")
    is_chaos = in_chaos or "chaos" in name or re.search(r"^\s*(from|import)\s+(tests\.chaos|toxiproxy)\b", src, re.M) is not None
    if is_test and is_chaos:
        chaos_tests.append(path)
        if not in_chaos:
            fail(path, 1, "a chaos test outside tests/chaos/: the coverage gate leaves out only that folder (--skip-suite chaos), "
                          "so make ci would collect and run it (W3-D10)")
    for n, line in enumerate(src.splitlines(), 1):
        if re.match(r"\s*(from\s+toxiproxy\s+import|import\s+toxiproxy\b)", line):
            fail(path, n, "the toxiproxy-python client: its add_toxic returns nothing, so a refused toxic (HTTP 400) is never noticed "
                          "and the experiment passes on nothing; use the Toxics helper of tests/chaos/support/chaostest.py")
    try:
        tree = ast.parse(src)
    except (SyntaxError, ValueError):
        if is_chaos:
            fail(path, 1, "does not parse as Python")
        continue
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and is_test and re.match(r"test\w*breaker", node.name, re.I):
            body = ast.get_source_segment(src, node) or ""
            states = {s for s, pat in (("open", r"[\"']open(ed)?[\"']|\bOPEN\b"), ("half-open", r"[\"']half-open(ed)?[\"']|\bHALF_OPEN\b"),
                                       ("closed", r"[\"']closed[\"']|\bCLOSED\b")) if re.search(pat, body)}
            if len(states) < 3 or not re.search(r"breaker_state\(|current_state|\.state\b|transitions", body):
                fail(path, node.lineno, f"{node.name} does not assert the breaker's states (found {sorted(states) or 'none'}): one call "
                                        "that fails fast proves no breaker; drive past the threshold and assert closed, open, half-open and closed")
        if isinstance(node, ast.Call) and call_name(node) in ("retry", "Retrying", "AsyncRetrying") \
                and re.search(r"^\s*(from\s+tenacity\s+import|import\s+tenacity)", src, re.M) \
                and not any(k.arg == "stop" for k in node.keywords):
            fail(path, node.lineno, f"a tenacity {call_name(node)} with no stop: tenacity retries forever by default; "
                                    "integration-design caps the attempts (stop=stop_after_attempt(n))")
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for deco in node.decorator_list:
                if isinstance(deco, (ast.Name, ast.Attribute)) and call_name(deco) == "retry" \
                        and re.search(r"^\s*(from\s+tenacity\s+import|import\s+tenacity)", src, re.M):
                    fail(path, deco.lineno, "a bare tenacity @retry: it retries forever with no wait; set stop and wait")
        if isinstance(node, ast.AsyncFunctionDef) and not r.startswith("tests/"):
            for inner in ast.walk(node):
                if isinstance(inner, ast.Call) and isinstance(inner.func, ast.Attribute) and isinstance(inner.func.value, ast.Name) \
                        and (inner.func.value.id, inner.func.attr) in (("time", "sleep"), ("requests", "get"), ("requests", "post")):
                    warn(path, inner.lineno, f"{inner.func.value.id}.{inner.func.attr} inside async def {node.name}: a blocking call "
                                             "stalls every request of that worker, health checks included (offload with asyncio.to_thread)")
    if is_chaos and re.search(r"pytest\.(skip|xfail)\(|mark\.(skip|skipif|xfail)\b", src):
        warn(path, 1, "a chaos test that can skip: the runner turns any skipped test into INVALID")

if chaos_tests:
    conftest = os.path.join(root, "tests/chaos/conftest.py")
    src = read(conftest)
    if not re.search(r"addinivalue_line\(\s*[\"']markers[\"']\s*,\s*[\"']chaos\b", src) or "add_marker" not in src:
        fails.append("FAIL: tests/chaos/conftest.py: must register the chaos marker and put it on every test of the folder")
    if "CHAOS_EXPERIMENT_ID" not in src or "CHAOS-REFUSED" not in src:
        fails.append("FAIL: tests/chaos/conftest.py: must refuse (CHAOS-REFUSED) every test that run-chaos-experiment.sh did not start "
                     "(CHAOS_EXPERIMENT_ID unset): a bare pytest collects tests/chaos")
for path in files(lambda r, n: n in ("Makefile",) or n.endswith((".mk", ".yml", ".yaml", ".sh", ".toml", ".cfg", ".ini"))):
    src, start, logical = read(path), 1, ""
    for n, line in enumerate(src.splitlines(), 1):
        logical += line.rstrip("\\") + " "
        if line.rstrip().endswith("\\"):
            continue  # a continued line: judge the whole command
        if chaos_tests and "check-python-coverage" in logical and "--skip-suite chaos" not in logical:
            fail(path, start, "the coverage gate without --skip-suite chaos: make ci would collect tests/chaos")
        start, logical = n + 1, ""
        if re.search(r"addopts\s*=.*--reruns|reruns\s*=\s*[1-9]", line):
            fail(path, n, "reruns in the pytest settings: they would retry unit and integration tests too, and an experiment never")

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
if (experiments or chaos_tests) and not runner_present:
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
    if tool == "pytest":
        command = (exp.get("fault") or {}).get("command", "")
        missing = [flag for flag, pat in (("-m chaos", r"-m\s+[\"']?chaos\b"), ("-p no:cacheprovider", r"-p\s+no:cacheprovider\b"),
                                          ("-p no:rerunfailures", r"-p\s+no:rerunfailures\b"), ('-o addopts=""', r"-o\s+[\"']?addopts="))
                   if not re.search(pat, command)]
        if missing or re.search(r"\bnot\s+chaos\b|--reruns\b|--lf\b|--ff\b|--sw\b|--count\b|--junit-?xml", command):
            fail(path, 1, f"the pytest command needs -m chaos, -p no:cacheprovider, -p no:rerunfailures and -o addopts=\"\", and no "
                          f"--reruns, --lf, --ff, --sw, --count or --junitxml (missing: {', '.join(missing) or 'none'})")
    if exp.get("retries") or exp.get("retry"):
        fail(path, 1, "an experiment is never retried")

for line in fails + warns:
    print(line)
print(f"{len(fails)} FAIL, {len(warns)} WARN")
sys.exit(1 if fails else 0)
PY
