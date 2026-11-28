#!/bin/bash
# validate-python-load-tests.sh <product-root-or-path>...
#
# Text checks on a product's load tests and what runs them: the k6 scripts and
# other files of a load/ folder, the designation records, every line of a
# Makefile, shell script, configuration file or workflow that starts a load
# test, and the workflows that do. It needs no k6, Docker or cluster and runs
# nothing: it finds the known dangerous mistakes, it does not prove a test good.
#
# FAIL rules: TARGET (an address written into a script, a load line or a
# workflow; a designation that names a staging or production host which no
# signed impact statement in the product covers), STATEMENT (an impact
# statement without a field the runner requires or without the product owner's
# sign-off), NOGUARD (a
# k6 script that does not go through lib/gate.js), DIRECTK6 (k6 started without
# run-load-test.sh), CHECKONLY (check() with no threshold on checks), CLOSED (a
# closed-model executor outside the smoke test with no stated reason), NODROP
# (an arrival-rate script with no dropped_iterations threshold), MASKED (exit
# status hidden), RETRY, PRTRIGGER, RELEASE, CREDENTIALS (a stored token or a
# secrets reference), GAUGEFN (increase, rate or irate on something that is
# not a counter), OUTPUT (a deprecated k6 output), PUSH (metrics or annotations
# sent to a monitoring system), PAID (a paid load service), TOOL (a load tool
# other than k6, a locustfile.py included, or locust among a Python product's
# dependencies). WARN rules: UNPINNED (k6 image or action without a pinned
# version), SUMMARYEXPORT, NOALWAYS (results not uploaded after a failure).
# Exit 0 = no FAIL (each WARN needs judgement); 1 = at least one FAIL;
# 2 = usage, a missing path, or nothing to check.
# It skips itself and any copy of itself, whatever the copy is called, and
# Python virtual environments (any folder holding a pyvenv.cfg).
#
# This is python-load-test's copy of the validator go-load-test owns (there
# validate-go-load-tests.sh). Everything from `set -uo pipefail` down is the same
# program in both skills, and a test fails when the two differ: change them
# together. It reads k6 scripts, records, Makefiles, shell and configuration
# files, workflows and Python dependency files; it never reads Go or Python code.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: $(basename "$0") <product-root-or-path>..." >&2
  exit 2
fi
exec python3 -I - "$0" "$@" << 'PY'
import json, os, re, sys

SELF = sys.argv[1]
TOOL_NAME = os.path.basename(SELF)[:-3] if SELF.endswith(".sh") else os.path.basename(SELF)


def program(text):
    # Everything from `set -uo pipefail` down: the part every copy of this validator shares.
    start = text.find("\nset -uo pipefail\n")
    return text[start:] if start >= 0 else None


try:
    OWN_PROGRAM = program(open(SELF, encoding="utf-8", errors="replace").read())
except OSError:
    OWN_PROGRAM = None
SKIP_DIRS = {".git", "vendor", "node_modules", "e2e-evidence", "load-evidence", "load-baseline", ".venv", "venv", ".tox", ".nox",
             "__pycache__", ".mypy_cache", ".pytest_cache", "site-packages"}

found = []
for arg in sys.argv[2:]:
    if os.path.isfile(arg):
        found.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not os.path.isfile(os.path.join(base, d, "pyvenv.cfg")))
            found += [os.path.join(base, n) for n in sorted(names)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)

fails = warns = checked = 0


def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")


def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)


def line_of(text, index):
    return text[:index].count("\n") + 1


def blank(match):
    return "\n" * match.group(0).count("\n")


JS_TOKEN = re.compile(r"//[^\n]*|/\*.*?\*/|'(?:\\.|[^'\\\n])*'|\"(?:\\.|[^\"\\\n])*\"|`(?:\\.|[^`\\])*`", re.S)
URL = re.compile(r"https?://([A-Za-z0-9.\-]+|\[[0-9a-fA-F:]+\])")
LOCAL = {"127.0.0.1", "localhost", "[::1]"}
SHARED = re.compile(r"^(staging|stage|stg|prod|production|live)\d*$")
LOAD_LINE = re.compile(r"run-load-test\.sh|\bk6\b(?!/)|\bmake\s+load\b|\bmake\s+load-")
NOT_COUNTER = re.compile(r"\b(increase|rate|irate)\(\s*(?:sum\s*(?:by\s*\([^)]*\))?\s*\()?\s*([a-zA-Z_:][a-zA-Z0-9_:]*)")


def in_load_folder(path):
    parts = os.path.abspath(path).replace(os.sep, "/").split("/")
    return "load" in parts[:-1]


def shared_host(host):
    return any(SHARED.match(label) for label in re.split(r"[.\-_]", host.lower()))


def address(raw):
    url = re.match(r"^(https?)://([^/?#]+)", str(raw or "").strip(), re.I)
    return f"{url.group(1)}://{url.group(2)}".lower() if url else ""


SIGNED_TEXT = lambda v: isinstance(v, str) and v.strip() and not re.search(r"<[^>]*>|\bTBD\b|\bTODO\b", v)
STATEMENT_FIELDS = ("statement_id", "product", "base_url", "purpose", "test_type", "profile_limit", "data_written", "data_removal",
                    "impact", "how_to_stop", "watched_by", "window_start", "window_end", "marker", "token_max_minutes",
                    "approved_by", "approved_on")


def read_json(path):
    try:
        return json.loads(open(path, encoding="utf-8", errors="replace").read())
    except (OSError, ValueError):
        return None


# Addresses covered by a signed impact statement anywhere in the given paths: load may go there for verification.
covered = set()
for path in found:
    if path.endswith(".json") and in_load_folder(path):
        data = read_json(path)
        if isinstance(data, dict) and "statement_id" in data and SIGNED_TEXT(data.get("approved_by")) and SIGNED_TEXT(data.get("approved_on")):
            covered.add(address(data.get("base_url")))


def check_queries(path, text):
    for m in NOT_COUNTER.finditer(text):
        name = m.group(2)
        if name in ("sum", "max", "min", "avg", "count", "by", "without", "histogram_quantile"):
            continue
        if not re.search(r"_(total|count|sum|bucket)$", name):
            report("FAIL", "GAUGEFN", path, line_of(text, m.start()),
                   f"{m.group(1)}() on {name}, which is not named like a counter: use delta() or max_over_time() for a gauge")
    for m in re.finditer(r"/api/annotations|/api/v1/write|remote_write|pushgateway", text):
        report("FAIL", "PUSH", path, line_of(text, m.start()),
               "a load test reads the environment's own monitoring; it never writes metrics or annotations into one")


def check_k6_script(path, raw):
    code = JS_TOKEN.sub(lambda m: blank(m) if m.group(0).startswith("/") else m.group(0), raw)  # comments out, strings kept
    bare = JS_TOKEN.sub(lambda m: blank(m) if m.group(0).startswith("/") else '""' + blank(m), raw)
    name = os.path.basename(path)
    is_gate = name == "gate.js"
    uses_gate = bool(re.search(r"from\s+['\"][./]*(?:lib/)?gate\.js['\"]", code))
    is_test = bool(re.search(r"export\s+(default\s+function|const\s+options)", bare))
    if is_test and not uses_gate and "LOAD_TARGET_PROOF" not in code:
        report("FAIL", "NOGUARD", path, 1, "this script can be aimed anywhere: import ./lib/gate.js, which refuses a target the runner did not check")
    for m in URL.finditer(code):
        if m.group(1) not in LOCAL:
            report("FAIL", "TARGET", path, line_of(code, m.start()),
                   f"address {m.group(0)} is written into the script: the target comes only from the runner (LOAD_BASE_URL)")
    for m in re.finditer(r"__ENV\.(BASE|BASE_URL|TARGET|HOST|URL)\b", code):
        report("FAIL", "TARGET", path, line_of(code, m.start()),
               f"the target is read from {m.group(0)}, which anyone can set: use BASE_URL from ./lib/gate.js")
    if re.search(r"\bcheck\s*\(", bare) and not re.search(r"['\"]?checks(\{[^}]*\})?['\"]?\s*:", code):
        report("FAIL", "CHECKONLY", path, line_of(bare, re.search(r"\bcheck\s*\(", bare).start()),
               "check() never changes k6's exit status: add a threshold on checks (or on a custom metric) for every rule it states")
    for m in re.finditer(r"executor\s*:\s*['\"](ramping-vus|constant-vus)['\"]|^\s*(vus|stages)\s*:", code, re.M):
        line = raw.split("\n")[line_of(code, m.start()) - 1]
        if "closed-model:" not in line and not (m.group(2) and re.search(r"executor\s*:", code)):
            report("FAIL", "CLOSED", path, line_of(code, m.start()),
                   "a closed model slows its own load when the target slows, so it understates latency for a rate target: "
                   "use an arrival-rate executor, or state the reason on this line as // closed-model: <reason>")
    if re.search(r"arrival-rate", code) and not is_gate and not re.search(r"dropped_iterations|steadyThresholds", code):
        report("FAIL", "NODROP", path, 1, "an arrival-rate scenario needs a dropped_iterations threshold: a starved generator must not pass")
    for m in re.finditer(r"\b(Authorization|token|password|secret)\b['\"]?\s*[:=]\s*['\"`](?!\$\{)[A-Za-z0-9._\-]{12,}", code):
        report("FAIL", "CREDENTIALS", path, line_of(code, m.start()), "a credential is written into the script")
    if re.search(r"\bfor\s*\([^)]*attempt|\bretr(y|ies)\s*[:=(]", bare):
        m = re.search(r"\bfor\s*\([^)]*attempt|\bretr(y|ies)\s*[:=(]", bare)
        report("FAIL", "RETRY", path, line_of(bare, m.start()), "a load test sends each request once: a retry hides the failure it should count")


def strip_hash(text):
    return re.sub(r"(^|[ \t])#[^\n]*", lambda m: m.group(1), text)


def check_load_lines(path, raw, workflow=False):
    text = strip_hash(raw)
    lines = text.split("\n")
    joined, start = [], None
    for number, line in enumerate(lines, 1):  # join backslash continuations
        if start is None:
            start, buffer = number, ""
        buffer += line.rstrip("\\")
        if line.rstrip().endswith("\\"):
            continue
        joined.append((start, buffer))
        start = None
    for number, line in joined:
        if not LOAD_LINE.search(line):
            continue
        if re.search(r"\|\|\s*(true|:|exit\s+0|echo)\b|;\s*true\s*$|--no-thresholds|\bset\s+\+e\b", line) or re.match(r"\t-", line):
            report("FAIL", "MASKED", path, number, "the exit status of the load test is hidden: 99 means a threshold was crossed and must stop the job")
        elif re.search(r"(run-load-test\.sh|\bk6\s+run\b|\bmake\s+load[\w\-]*)[^|\n]*\|(?!\|)", line):
            report("FAIL", "MASKED", path, number, "a pipe replaces the load test's exit status with the last command's")
        if re.search(r"\bk6\s+(run|cloud)\b", line) or re.search(r"grafana/k6[^ \n]*\s+run\b", line):
            if "LOAD_K6" not in line:
                report("FAIL", "DIRECTK6", path, number, "k6 is started directly: only run-load-test.sh checks the target and reads the result")
        if re.search(r"\b(until|while)\b.*(run-load-test|k6)|--retr(y|ies)\b|\bretry\b|(run-load-test\.sh[^\n]*\|\|[^\n]*run-load-test\.sh)", line):
            report("FAIL", "RETRY", path, number, "a load test is not run again until it passes: zero retries, and a second run is a new result")
        for m in URL.finditer(line):
            if m.group(1) not in LOCAL and not re.search(r"github\.com|githubusercontent\.com|grafana\.com|dl\.k6\.io", m.group(0)):
                report("FAIL", "TARGET", path, number, f"address {m.group(0)} on a load line: the target comes from the run marker or the designation record")
        for m in re.finditer(r"--out[ =]+(\S+)|-o\s+(experimental-\S+|influxdb\S*|opentelemetry\S*|cloud\S*|statsd\S*)", line):
            out = m.group(1) or m.group(2)
            if re.match(r"experimental-prometheus-rw|influxdb", out):
                report("FAIL", "OUTPUT", path, number, f"{out.split('=')[0]} is deprecated in k6 v2.4.0 and planned for removal in v3")
            if not re.match(r"(json|csv)=", out):
                report("FAIL", "PUSH", path, number, f"--out {out.split('=')[0]} sends the run's metrics to a monitoring system: keep results in files")
        if "--summary-export" in line:
            report("WARN", "SUMMARYEXPORT", path, number, "k6 discourages --summary-export: the summary comes from handleSummary in lib/gate.js")
        m = re.search(r"(?<![\w./])grafana/k6(:latest|@|:[\w.\-]+)?", line)
        if m and (m.group(1) in (None, ":latest")):
            report("WARN", "UNPINNED", path, number, "the k6 image has no pinned version")
    for m in re.finditer(r"K6_PROMETHEUS_RW_\w+|K6_INFLUXDB_\w+", text):
        report("FAIL", "OUTPUT", path, line_of(text, m.start()), f"{m.group(0)} configures an output deprecated in k6 v2.4.0")
    for m in re.finditer(r"K6_CLOUD_TOKEN|\bk6\s+cloud\b|grafana cloud k6|blazemeter|loader\.io|flood\.io", text, re.I):
        report("FAIL", "PAID", path, line_of(text, m.start()), "a paid load service needs the product owner's approval first; the default is self-run k6")
    for m in re.finditer(r"\b(vegeta|locust|artillery|gatling|jmeter)\b", text, re.I):
        report("FAIL", "TOOL", path, line_of(text, m.start()), f"{m.group(1)}: k6 is the one load tool")


def check_workflow(path, raw):
    text = strip_hash(raw)
    trigger = re.search(r"^(on|\"on\"|'on'|true):(.*?)(?=^\S)", text + "\nend:", re.M | re.S)
    block = trigger.group(2) if trigger else ""
    if re.search(r"\bpull_request(_target)?\b", block):
        report("FAIL", "PRTRIGGER", path, line_of(text, text.find("pull_request")), "a load test never runs on a pull request")
    if re.search(r"^\s*release\s*:", block, re.M) or re.search(r"\[[^\]]*\brelease\b[^\]]*\]", block.split("\n")[0]):
        report("FAIL", "RELEASE", path, line_of(text, text.find("release")),
               "a release trigger fires after publication: the verdict run is a job the publishing job needs")
    for m in re.finditer(r"\$\{\{\s*secrets\.(\w+)", text):
        report("FAIL", "CREDENTIALS", path, line_of(text, m.start()),
               f"secrets.{m.group(1)}: no standing credential. The indicative tier needs none; the verdict tier gets short-lived tokens at run time")
    for m in re.finditer(r"continue-on-error\s*:\s*true", text):
        report("FAIL", "MASKED", path, line_of(text, m.start()), "continue-on-error turns a failed load test green")
    for m in re.finditer(r"uses\s*:\s*(nick-fields/retry|[\w\-]+/[\w\-]*retry[\w\-]*)", text):
        report("FAIL", "RETRY", path, line_of(text, m.start()), "a retry action reruns the load test until it passes")
    for m in re.finditer(r"uses\s*:\s*([\w\-./]+)@([\w.\-]+)", text):
        if not m.group(1).startswith("./") and not re.fullmatch(r"[0-9a-f]{40}", m.group(2)):
            report("WARN", "UNPINNED", path, line_of(text, m.start()), f"{m.group(1)}@{m.group(2)} is not pinned to a commit")
    if re.search(r"upload-artifact", text) and not re.search(r"if\s*:\s*\$\{\{\s*always\(\)", text):
        report("WARN", "NOALWAYS", path, 1, "results are not uploaded after a failure: add if: ${{ always() }} to the upload step")


PY_DEPENDENCY = re.compile(r"^\s*locust(?:[\[<>=~!;\s]|$)|[\"']locust(?:[\[<>=~!;\s\"']|$)", re.M | re.I)

for path in found:
    name = os.path.basename(path)
    lower = path.replace(os.sep, "/").lower()
    if name.endswith(".sh") and OWN_PROGRAM and program(read(path)) == OWN_PROGRAM:
        continue  # this validator, or a copy of it under another name: its own rule texts are not findings
    if name == "locustfile.py" or (name.endswith(".py") and re.search(r"^\s*(from\s+locust\b|import\s+locust\b)", read(path), re.M)):
        checked += 1
        report("FAIL", "TOOL", path, 1, "locust: k6 is the one load tool; the k6 scripts drive a Python service from outside")
        continue
    if name in ("pyproject.toml", "setup.cfg", "Pipfile") or re.fullmatch(r"requirements[\w.\-]*\.(txt|in)", name):
        raw = read(path)
        m = PY_DEPENDENCY.search(raw)
        if m:
            checked += 1
            report("FAIL", "TOOL", path, line_of(raw, m.start()), "locust among the dependencies: k6 is the one load tool")
        continue
    if name.endswith(".js") and in_load_folder(path):
        checked += 1
        check_k6_script(path, read(path))
    elif name.endswith(".json") and in_load_folder(path):
        raw = read(path)
        try:
            data = json.loads(raw)
        except ValueError:
            continue
        if isinstance(data, dict) and "statement_id" in data:
            missing = [key for key in STATEMENT_FIELDS if key not in data or data[key] in ("", None, {}, [])]
            if missing:
                report("FAIL", "STATEMENT", path, 1, f"the impact statement has no {', '.join(missing)}: the runner refuses it")
            if not (SIGNED_TEXT(data.get("approved_by")) and SIGNED_TEXT(data.get("approved_on"))):
                report("FAIL", "STATEMENT", path, 1, "the impact statement carries no product-owner sign-off (approved_by, approved_on)")
            if not data.get("expires_on") and not data.get("single_use_run_id"):
                report("FAIL", "STATEMENT", path, 1, "the impact statement has neither expires_on nor single_use_run_id: it must lapse")
        if isinstance(data, dict) and "base_url" in data:
            checked += 1
            host = re.sub(r"^https?://", "", str(data.get("base_url"))).split("/")[0].split(":")[0]
            if shared_host(host) and address(data.get("base_url")) not in covered:
                report("FAIL", "TARGET", path, 1, f"base_url {data['base_url']} names a shared staging or production host and no signed "
                       "impact statement covers that address: load goes there only with the product owner's signed statement")
        if isinstance(data, list) and data and all(isinstance(e, dict) and "token" in e for e in data):
            checked += 1
            report("FAIL", "CREDENTIALS", path, 1, "a subjects file with tokens is stored in the repository: tokens are issued for one run and deleted after it")
    elif "/.github/workflows/" in lower and name.endswith((".yml", ".yaml")):
        raw = read(path)
        if LOAD_LINE.search(strip_hash(raw)):
            checked += 1
            check_workflow(path, raw)
            check_load_lines(path, raw, workflow=True)
    elif name in ("Makefile", "makefile", "GNUmakefile") or name.endswith((".mk", ".sh", ".conf")):
        raw = read(path)
        if name == "run-load-test.sh" or name == "run-e2e-environment.sh":
            continue
        if LOAD_LINE.search(strip_hash(raw)) or in_load_folder(path):
            checked += 1
            check_load_lines(path, raw)
            if in_load_folder(path):
                check_queries(path, strip_hash(raw))
    elif in_load_folder(path) and name.endswith((".promql", ".txt", ".yaml", ".yml", ".md")):
        checked += 1
        check_queries(path, read(path))

if checked == 0:
    print("ERROR: nothing was checked: no load/ folder, load line or load workflow under the given paths")
    sys.exit(2)
print(f"{TOOL_NAME}: {checked} file(s) checked: {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
