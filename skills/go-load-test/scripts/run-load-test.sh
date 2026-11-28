#!/bin/bash
# run-load-test.sh --tier indicative|verdict --type <test type> --subjects-cmd <command>
#                  [--endpoint <name>] [--designation <file>] [--statement <file>]
#                  [--dir <tests/load>] [--out <dir>] [--previous <result.json>]
#
# The only way a load test starts. It checks where the load would go, refuses
# anything that is neither this run's own throwaway cluster, the product's
# designated performance environment, nor a system named in an impact
# statement the product owner signed, runs k6 once (no retry), and turns k6's
# exit status and summary into one verdict.
#
#   indicative  the target is read from the run marker of the cluster that
#               go-e2e-test's run-e2e-environment.sh created (E2E_RUN_ID,
#               E2E_KUBECONFIG, --endpoint). No address comes from the caller.
#   verdict     the target is the base_url of the designation record
#               (--designation): signed off, not expired, and the environment
#               itself must answer with the same designation id.
#               With --statement (a signed impact statement) the target is the
#               statement's base_url: every field present, signed, not expired
#               (or its single_use_run_id equal to LOAD_RUN_ID), inside its time
#               window, the run's profile within the statement's limits, and the
#               marker served unless the statement says why it cannot be. Such a
#               run is a verification of that system at that time, not a
#               capacity verdict unless --designation names the same address.
#               A host named like staging or production is refused without a
#               statement. k6 follows no redirect in a statement run.
#
# --subjects-cmd writes the test subjects to the file named by
# LOAD_SUBJECTS_FILE (a JSON list of {"id","token"[,"expires_at"]}); it gets
# LOAD_TIER and LOAD_BASE_URL. The file is created for the run and deleted
# after it. In the verdict tier every token must expire within the
# token_max_minutes of the designation and of the statement.
#
# Verdicts and exit statuses:
#   0   PASS (verdict tier), INDICATIVE PASS, or MEASURED (breakpoint)
#   1   FAIL: k6 exited 99 (a threshold was crossed), or an indicative regression
#   2   usage, configuration, a profile that does not say who decided a number,
#       or a k6 version this script was not proven on
#   3   REFUSED: the target is not allowed; no request of the test was sent
#   4   INVALID: the run proves nothing (dropped iterations, a saturated
#       generator, no requests, no thresholds, a script error, no summary)
#   130 interrupted (k6 exits 105)
# Results go to <out>/<type>-result.json and <type>-k6-summary.json; <out> is
# --out, else $E2E_RESULTS_DIR/load, else load-evidence/load.
# Environment: LOAD_K6 (default k6), LOAD_K6_VERSION (default v2.4.0),
# LOAD_RUNNER_CLASS (a label for the machine, kept with the result so that two
# indicative runs are compared only on the same class of runner), LOAD_RUN_ID
# (this run's id, for a statement signed for a single run).
set -uo pipefail
exec python3 -I - "$@" << 'PY'
import datetime, hashlib, ipaddress, json, os, re, resource, secrets, shlex, signal, socket, subprocess, sys, tempfile, time
import urllib.error, urllib.parse, urllib.request

USAGE = ("usage: run-load-test.sh --tier indicative|verdict --type <test type> --subjects-cmd <command> "
         "[--endpoint <name>] [--designation <file>] [--statement <file>] [--dir <tests/load>] [--out <dir>] [--previous <result.json>]")
TYPES = {
    "indicative": ["smoke", "average-load", "overload"],
    "verdict": ["smoke", "average-load", "stress", "soak", "spike", "breakpoint", "overload"],
}
K6_EXITS = {
    97: "cloud run failed", 98: "cloud progress unavailable", 100: "setup timed out", 101: "teardown timed out",
    102: "timed out", 103: "stopped through the REST API", 104: "invalid configuration", 106: "REST API could not start",
    107: "script exception (also: a refusal or a profile error raised by the script)", 108: "aborted by the script",
    109: "k6 panicked", 110: "marked as failed by the script",
}
NOT_PROVEN = {
    "indicative": [
        "Capacity, and whether any stated target (NFR or SLO) is met: this tier never shows either.",
        "Anything about production sizing: one kind node on the machine that also runs the load generator, small data, test-only identities.",
        "A difference from the previous run is a prompt to look, not a measurement: the runner is shared and its size depends on the repository's visibility.",
    ],
    "verdict": [
        "The rolling SLO window: one run shows the targets held at this load for this run's length, not for 28 days.",
        "Production itself: the result holds for the sizing and data recorded in the designation, nothing larger.",
        "Faults injected on purpose and the speed of a single function: the chaos-test and performance-test skills of the product's language.",
    ],
    "verification": [
        "Capacity: this run went to a system named in an impact statement, not a designated performance environment. "
        "It is a result about that system at that time, not a capacity verdict.",
        "Any other time: the system's own traffic, sizing and data were whatever they were inside the statement's window.",
        "The rolling SLO window: one run shows the targets held at this load for this run's length, not for 28 days.",
    ],
}


def stop(code, message):
    print(message, file=sys.stderr)
    sys.exit(code)


def refuse(message):
    stop(3, f"REFUSED: {message}\nNo request of the test was sent.")


args, argv = {}, sys.argv[1:]
while argv:
    flag = argv.pop(0)
    if flag not in ("--tier", "--type", "--subjects-cmd", "--endpoint", "--designation", "--statement", "--dir", "--out", "--previous") or not argv:
        stop(2, USAGE)
    args[flag[2:]] = argv.pop(0)
tier, kind = args.get("tier"), args.get("type")
if tier not in TYPES or not kind or "subjects-cmd" not in args:
    stop(2, USAGE)
if kind not in TYPES["verdict"]:
    stop(2, f"ERROR: unknown test type '{kind}'. Known: {', '.join(TYPES['verdict'])}")
if kind not in TYPES[tier]:
    refuse(f"a {kind} test is not allowed in the indicative tier ({', '.join(TYPES['indicative'])} only): "
           "it needs the designated performance environment")

load_dir = args.get("dir", "tests/load")
script = os.path.join(load_dir, f"{kind}.js")
profile_path = os.path.join(load_dir, "profile.json")
for needed in (script, profile_path, os.path.join(load_dir, "lib", "gate.js")):
    if not os.path.isfile(needed):
        stop(2, f"ERROR: missing {needed}")

# ------------------------------------------------------------------ profile
try:
    profile = json.load(open(profile_path, encoding="utf-8"))
except ValueError as exc:
    stop(2, f"PROFILE ERROR: {profile_path} is not JSON: {exc}")
problems = []


def need(path, test, what):
    node = profile
    for key in path.split("."):
        node = node.get(key) if isinstance(node, dict) else None
    if node is None or not test(node):
        problems.append(f"{path}: {what}")
    return node


text = lambda v: isinstance(v, str) and v.strip() and not re.search(r"<[^>]*>|\bTBD\b|\bTODO\b", v)
number = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0
need("nfr.id", lambda v: isinstance(v, str) and re.fullmatch(r"NFR-[A-Z]+-\d+", v), "the NFR row the target comes from, as NFR-<AREA>-<nn>")
need("nfr.level", lambda v: v in ("Must", "Plan", "Stretch"), "which response measure is tested: Must, Plan or Stretch")
need("nfr.environment", text, "the Environment cell of that NFR row, copied")
need("slo.availability.id", text, "the SLO row the error definition comes from")
need("slo.availability.objective", lambda v: number(v) and v < 1, "the objective as a fraction, for example 0.995")
need("slo.availability.good_statuses", lambda v: isinstance(v, list) and v, "the statuses the SLI counts as good")
need("slo.latency.id", text, "the SLO row the latency target comes from")
need("slo.latency.percentile", lambda v: number(v) and v < 100, "the percentile the target names")
need("slo.latency.under_ms", number, "the latency target in milliseconds")
need("limiter.per_subject_per_second", number, "the product's rate limit per subject")
need("limiter.burst", number, "the limiter's burst")
need("limiter.source", text, "where that limit is configured")
need("data.description", text, "what data the test reads and writes, and how much")
need("data.distinct_items", number, "how many different items the journey spreads its requests over")
for key in ("decided_by", "reason"):
    need(f"data.{key}", text, "the sources give no rule for data volume: say who decided it and why")
shape = (profile.get(tier) or {}).get(kind)
if not isinstance(shape, dict):
    problems.append(f"{tier}.{kind}: this test type is not planned for this tier")
else:
    for key in ("decided_by", "reason"):
        if not text(shape.get(key)):
            problems.append(f"{tier}.{kind}.{key}: every number of a profile names who decided it and why")
if problems:
    stop(2, "PROFILE ERROR in " + profile_path + ":\n  " + "\n  ".join(problems))

# ------------------------------------------------------------------- target
target = {"tier": tier}


def loopback(host):
    try:
        return ipaddress.ip_address(host.strip("[]")).is_loopback
    except ValueError:
        return False


def stays_local(host):
    """An address whose traffic never leaves this machine: a loopback address, or a name under .localhost
    (reserved for loopback, RFC 6761) that resolves to loopback addresses only."""
    if loopback(host):
        return True
    if not (host.lower() == "localhost" or host.lower().endswith(".localhost")):
        return False
    try:
        found = {info[4][0] for info in socket.getaddrinfo(host, None)}
    except OSError:
        return False
    return bool(found) and all(loopback(address.split("%")[0]) for address in found)


def run_tool(command):
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        refuse(f"could not run {command[0]}: {exc}")
    if done.returncode != 0:
        refuse(f"{' '.join(command[:1] + command[3:])} failed: {done.stderr.strip() or done.stdout.strip()}")
    try:
        return json.loads(done.stdout)
    except ValueError:
        refuse(f"{command[0]} did not answer with JSON")


if tier == "indicative":
    if "designation" in args or "statement" in args:
        stop(2, "ERROR: --designation or --statement belongs to the verdict tier")
    run_id, kubeconfig, endpoint = os.environ.get("E2E_RUN_ID", ""), os.environ.get("E2E_KUBECONFIG", ""), args.get("endpoint", "")
    if not endpoint:
        stop(2, "ERROR: the indicative tier needs --endpoint <name from E2E_ENDPOINTS>")
    if not run_id or not kubeconfig:
        refuse("E2E_RUN_ID and E2E_KUBECONFIG are not set: the indicative tier runs only inside the end-to-end "
               "environment run (make e2e, make load-indicative), as a line of E2E_SUITES")
    real = os.path.realpath(kubeconfig)
    own = [os.path.realpath(os.path.expanduser("~/.kube/config"))]
    own += [os.path.realpath(p) for p in os.environ.get("KUBECONFIG", "").split(os.pathsep) if p]
    if real in own:
        refuse("E2E_KUBECONFIG is the caller's own kubeconfig, not one created for a run")
    if not os.path.isfile(real):
        refuse(f"E2E_KUBECONFIG {kubeconfig} does not exist")
    context = f"kind-e2e-{run_id}"
    view = run_tool(["kubectl", "--kubeconfig", real, "config", "view", "-o", "json"])
    entry = next((c for c in view.get("contexts") or [] if c.get("name") == context), None)
    if entry is None:
        refuse(f"the kubeconfig has no context {context}")
    cluster = next((c for c in view.get("clusters") or [] if c.get("name") == entry["context"].get("cluster")), {})
    server = urllib.parse.urlsplit(cluster.get("cluster", {}).get("server", ""))
    if not server.hostname or not loopback(server.hostname):
        refuse(f"the API server of {context} ({server.netloc or 'unknown'}) is not on this machine")
    marker = run_tool(["kubectl", "--kubeconfig", real, "--context", context, "get", "configmap", "e2e-run-marker",
                       "-n", "default", "-o", "json"]).get("data") or {}
    if marker.get("run-id") != run_id:
        refuse(f"the cluster's run marker says run \"{marker.get('run-id')}\", this run is \"{run_id}\"")
    address = marker.get(f"endpoint.{endpoint}", "")
    if not re.fullmatch(r"127\.0\.0\.1:\d+", address):
        refuse(f"the run marker has no loopback address for endpoint \"{endpoint}\" (found \"{address}\")")
    base_url = f"http://{address}"
    # The published port accepts connections before the cluster routes them (seen: every
    # request of a first run ended in EOF). Poll until the product answers; no fixed wait.
    deadline, answered, last = time.monotonic() + 60, False, None
    while not answered and time.monotonic() < deadline:
        try:
            urllib.request.build_opener(urllib.request.ProxyHandler({})).open(base_url + "/", timeout=5).close()
            answered = True
        except urllib.error.HTTPError:
            answered = True  # any HTTP status means requests reach the product
        except (OSError, urllib.error.URLError) as exc:
            last = exc
            time.sleep(0.5)  # poll interval inside a deadline
    if not answered:
        stop(4, f"INVALID: {base_url} gave no HTTP answer within 60 seconds ({last}); nothing was measured")
    target.update(environment=f"throwaway kind cluster e2e-{run_id}, created and deleted by this run", run_id=run_id, endpoint=endpoint)
else:
    record = statement = None
    if "designation" not in args and "statement" not in args:
        refuse("the verdict tier needs --designation <record>: a verdict is given only in the product's designated performance environment "
               "(another system only with --statement, the product owner's signed impact statement for it)")
    today = datetime.datetime.now(datetime.timezone.utc).date()

    def read_record(path, what):
        try:
            data = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError) as exc:
            refuse(f"cannot read the {what} {path}: {exc}")
        if not isinstance(data, dict):
            refuse(f"the {what} {path} is not a JSON object")
        return data

    def signed_dates(data, what):
        try:
            approved = datetime.date.fromisoformat(data["approved_on"])
            expires = datetime.date.fromisoformat(data["expires_on"]) if data.get("expires_on") else None
        except ValueError:
            refuse(f"approved_on and expires_on of the {what} must be dates (yyyy-mm-dd)")
        if approved > today:
            refuse(f"the {what} is dated {approved}, which is in the future")
        if expires is not None and expires < today:
            refuse(f"the {what} expired on {expires}; the product owner has to renew it")

    def exact_address(raw, what):
        url = urllib.parse.urlsplit(raw)
        if url.scheme not in ("https", "http") or not url.hostname or url.path not in ("", "/") or url.query or url.fragment or url.username:
            refuse(f"base_url \"{raw}\" of the {what} must be scheme://host[:port] with nothing after it")
        return url

    if "designation" in args:
        record = read_record(args["designation"], "designation record")
        for key in ("designation_id", "product", "base_url", "approved_by", "approved_on", "expires_on", "sizing", "data", "generator"):
            if not text(record.get(key)):
                refuse(f"the designation record has no {key}" + (": it carries no product-owner sign-off" if key.startswith("approved") else ""))
        if not isinstance(record.get("test_types"), list) or not number(record.get("token_max_minutes")):
            refuse("the designation record must list test_types and set token_max_minutes")
        signed_dates(record, "designation")
        if kind not in record["test_types"]:
            refuse(f"the designation does not allow the {kind} test (allowed: {', '.join(record['test_types'])})")
        exact_address(record["base_url"], "designation record")

    if "statement" in args:
        # The product owner's signed impact statement: exactly where the load goes and what it does there.
        statement = read_record(args["statement"], "impact statement")
        for key in ("statement_id", "product", "base_url", "purpose", "test_type", "data_written", "data_removal", "how_to_stop",
                    "watched_by", "window_start", "window_end", "marker", "approved_by", "approved_on"):
            if not text(statement.get(key)):
                refuse(f"the impact statement has no {key}" + (": it carries no product-owner sign-off" if key.startswith("approved") else ""))
        impact = statement.get("impact")
        for key in ("other_users", "other_teams", "dependent_systems", "third_parties", "cost"):
            if not isinstance(impact, dict) or not text(impact.get(key)):
                refuse(f"the impact statement has no impact.{key}: it must say who and what the load affects (\"none\" where nothing)")
        limit = statement.get("profile_limit")
        for key in ("rate_per_second", "peak_rate_per_second", "duration_seconds"):
            if not isinstance(limit, dict) or not number(limit.get(key)):
                refuse(f"the impact statement has no profile_limit.{key}: it must state the rate, the peak and the length it allows")
        if not number(statement.get("token_max_minutes")):
            refuse("the impact statement has no token_max_minutes")
        if not (statement["marker"] == "served" or re.fullmatch(r"cannot be served: .{10,}", statement["marker"])):
            refuse("the impact statement's marker must be \"served\", or \"cannot be served: <why>\" for a system nobody here can change")
        if not text(statement.get("expires_on")) and not text(statement.get("single_use_run_id")):
            refuse("the impact statement has neither expires_on nor single_use_run_id: a signed statement must lapse")
        signed_dates(statement, "impact statement")
        if text(statement.get("single_use_run_id")) and statement["single_use_run_id"] != os.environ.get("LOAD_RUN_ID", ""):
            refuse(f"the impact statement is for run \"{statement['single_use_run_id']}\" only; this run is "
                   f"\"{os.environ.get('LOAD_RUN_ID', '')}\" (LOAD_RUN_ID)")
        if statement["test_type"] != kind:
            refuse(f"the impact statement allows the {statement['test_type']} test, not {kind}")
        exact_address(statement["base_url"], "impact statement")
        # What the run would send, from its profile entry: every rate against the peak, the held rate against the rate,
        # and the sum of every length against the duration (a sum is never shorter than the run).
        rates = [v for k, v in shape.items() if k.endswith("rate_per_second") and number(v)]
        peak = max(rates) if rates else shape.get("iterations", 0)  # a smoke run sends at most its iterations
        held = shape.get("recovery_rate_per_second") if kind == "spike" else shape.get("rate_per_second", peak)
        units = {"ms": 0.001, "s": 1, "m": 60, "h": 3600}
        length = sum(float(v) if k == "seconds" and number(v) else sum(float(n) * units[u] for n, u in re.findall(r"(\d+(?:\.\d+)?)(ms|s|m|h)", v))
                     for k, v in shape.items() if k == "seconds" or (isinstance(v, str) and re.fullmatch(r"(\d+(\.\d+)?(ms|s|m|h))+", v)))
        for name, run_value, allowed in (("peak rate", peak, limit["peak_rate_per_second"]), ("rate", held, limit["rate_per_second"]),
                                         ("length in seconds", length, limit["duration_seconds"])):
            if not number(run_value) or run_value > allowed:
                refuse(f"the run's {name} ({run_value}, from profile.json {tier}.{kind}) exceeds the {allowed} the impact statement allows")
        try:
            start, end = (datetime.datetime.fromisoformat(statement[k].replace("Z", "+00:00")) for k in ("window_start", "window_end"))
            if start.tzinfo is None or end.tzinfo is None:
                raise ValueError("no time zone")
        except ValueError:
            refuse("window_start and window_end must be date-times with a time zone (yyyy-mm-ddThh:mm:ssZ)")
        now = datetime.datetime.now(datetime.timezone.utc)
        if now < start or now + datetime.timedelta(seconds=length) > end:
            refuse(f"the run would not fit inside the statement's window ({start.isoformat()} to {end.isoformat()}); "
                   f"it is {now.strftime('%Y-%m-%dT%H:%M:%SZ')} and the run takes up to {length:.0f} seconds")

    url = exact_address((statement or record)["base_url"], "impact statement" if statement else "designation record")
    host = url.hostname
    base_url = f"{url.scheme}://{url.netloc}"
    if record and statement and urllib.parse.urlsplit(record["base_url"]).netloc.lower() != url.netloc.lower():
        refuse(f"the designation names {record['base_url']}, the impact statement {statement['base_url']}: one run has one address")
    if url.scheme == "http" and not stays_local(host):
        refuse("base_url must be https: the run carries tokens")
    shared = [label for label in re.split(r"[.\-_]", host.lower()) if re.fullmatch(r"(staging|stage|stg|prod|production|live)\d*", label)]
    if shared and not statement:
        refuse(f"\"{host}\" is named like a shared staging or production environment ({shared[0]}); load goes there only with "
               "the product owner's signed impact statement for it (--statement), never on a designation alone")
    wanted_ids = {}
    if record:
        wanted_ids["designation_id"] = record["designation_id"]
    if statement and statement["marker"] == "served":
        wanted_ids["statement_id"] = statement["statement_id"]
    if wanted_ids:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), type("NoRedirect", (urllib.request.HTTPRedirectHandler,), {
            "redirect_request": lambda self, *a, **k: None})())
        try:
            with opener.open(base_url + "/.well-known/load-test-designation", timeout=15) as answer:
                served = json.loads(answer.read(65536).decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if 300 <= exc.code < 400:
                refuse(f"{base_url} answers its marker with a redirect to {exc.headers.get('Location')}: load goes only to the stated address")
            refuse(f"{base_url} does not serve a designation marker ({exc}); it is not the "
                   + ("designated environment" if record else "system the impact statement names"))
        except (OSError, ValueError, AttributeError, urllib.error.URLError) as exc:
            refuse(f"{base_url} does not serve a designation marker ({exc}); it is not the "
                   + ("designated environment" if record else "system the impact statement names"))
        for key, want in wanted_ids.items():
            got = served.get(key) if isinstance(served, dict) else None
            if got != want:
                refuse(f"{base_url} serves {key.split('_')[0]} \"{got}\", the {'record' if key == 'designation_id' else 'impact statement'} says \"{want}\"")
    if record:
        target.update(environment=f"designated performance environment {record['designation_id']}",
                      designation={k: record[k] for k in ("designation_id", "product", "base_url", "approved_by", "approved_on",
                                                           "expires_on", "sizing", "data", "generator", "test_types", "token_max_minutes")})
    if statement:
        if not record:
            target.update(environment=f"{host}, named in impact statement {statement['statement_id']}: a verification, not a designated environment")
        target["statement"] = statement  # verbatim, as the product owner signed it
        target["verification"] = not record
    token_limit = min(d["token_max_minutes"] for d in (record, statement) if d)
target["base_url"] = base_url

# ------------------------------------------------------------------- k6
k6 = shlex.split(os.environ.get("LOAD_K6", "k6"))
wanted = os.environ.get("LOAD_K6_VERSION", "v2.4.0")
try:
    version = subprocess.run(k6 + ["version"], capture_output=True, text=True, timeout=60).stdout.strip()
except (OSError, subprocess.TimeoutExpired) as exc:
    stop(2, f"ERROR: k6 is not installed ({exc})")
if not re.search(r"\bk6 " + re.escape(wanted) + r"\b", version):
    stop(2, f"ERROR: found \"{version or 'no k6'}\"; this script needs k6 {wanted} (exit statuses and summary format are version facts)")

out_dir = args.get("out") or os.path.join(os.environ.get("E2E_RESULTS_DIR", "load-evidence"), "load")
os.makedirs(out_dir, exist_ok=True)
out_dir = os.path.realpath(out_dir)
summary_path = os.path.join(out_dir, f"{kind}-k6-summary.json")
result_path = os.path.join(out_dir, f"{kind}-result.json")
for stale in (summary_path, result_path):
    if os.path.exists(stale):
        os.remove(stale)

work = tempfile.mkdtemp(prefix="load-run-")
subjects_file = os.path.join(work, "subjects.json")
child = None


def cleanup():
    for name in os.listdir(work):
        os.remove(os.path.join(work, name))
    os.rmdir(work)


def on_signal(signum, frame):
    if child is not None and child.poll() is None:
        child.send_signal(signal.SIGINT)


signal.signal(signal.SIGINT, on_signal)
signal.signal(signal.SIGTERM, on_signal)

env = dict(os.environ, LOAD_TIER=tier, LOAD_BASE_URL=base_url, LOAD_SUBJECTS_FILE=subjects_file)
made = subprocess.run(["/bin/bash", "-c", args["subjects-cmd"]], env=env)
try:
    subjects = json.load(open(subjects_file, encoding="utf-8"))
    assert isinstance(subjects, list) and subjects and all(text(s.get("id")) and text(s.get("token")) for s in subjects)
except (OSError, ValueError, AssertionError, AttributeError):
    cleanup()
    stop(2, f"ERROR: --subjects-cmd (exit {made.returncode}) did not write a JSON list of {{\"id\",\"token\"}} to LOAD_SUBJECTS_FILE")
os.chmod(subjects_file, 0o600)
if tier == "verdict":
    now = datetime.datetime.now(datetime.timezone.utc)
    latest = now + datetime.timedelta(minutes=token_limit)
    for subject in subjects:
        try:
            raw = subject["expires_at"]
            expiry = (datetime.datetime.fromtimestamp(raw, datetime.timezone.utc) if isinstance(raw, (int, float))
                      else datetime.datetime.fromisoformat(str(raw).replace("Z", "+00:00")))
            if expiry.tzinfo is None:
                raise ValueError("no time zone")
        except (KeyError, ValueError, OverflowError, OSError):
            cleanup()
            refuse(f"the token of subject \"{subject['id']}\" states no expires_at: only short-lived tokens are used in a designated environment")
        if expiry <= now or expiry > latest:
            cleanup()
            refuse(f"the token of subject \"{subject['id']}\" expires {expiry.isoformat()}: it must be valid now and for at most "
                   f"{token_limit} minutes, the limit the product owner approved")

nonce = secrets.token_hex(16)
proof = hashlib.sha256(f"{nonce}|{tier}|{base_url}".encode()).hexdigest()
# Every run, in every tier: load goes to the approved address only; a redirect is
# answered, never followed, so it cannot carry load to another host.
command = k6 + ["run", "--quiet", "--max-redirects", "0"]
for name, value in (("LOAD_TIER", tier), ("LOAD_TYPE", kind), ("LOAD_BASE_URL", base_url), ("LOAD_NONCE", nonce),
                    ("LOAD_TARGET_PROOF", proof), ("LOAD_SUBJECTS_FILE", subjects_file), ("LOAD_SUMMARY", summary_path)):
    command += ["-e", f"{name}={value}"]
command.append(script)
print(f"== load test: tier {tier}, type {kind}, target {base_url} ({target['environment']})", flush=True)
before = resource.getrusage(resource.RUSAGE_CHILDREN)
started, wall = datetime.datetime.now(datetime.timezone.utc), time.monotonic()
child = subprocess.Popen(command, env=dict(os.environ, K6_NO_USAGE_REPORT="true"))
while True:
    try:
        k6_exit = child.wait()
        break
    except KeyboardInterrupt:
        continue
wall = time.monotonic() - wall
ended = datetime.datetime.now(datetime.timezone.utc)
after = resource.getrusage(resource.RUSAGE_CHILDREN)
cleanup()
cores = os.cpu_count() or 1
cpu_share = ((after.ru_utime + after.ru_stime) - (before.ru_utime + before.ru_stime)) / (wall * cores) if wall > 0 else 0.0

# ------------------------------------------------------------------ verdict
summary = None
try:
    summary = json.load(open(summary_path, encoding="utf-8"))
except (OSError, ValueError):
    pass
metrics = (summary or {}).get("metrics", {})
value = lambda metric, stat: (metrics.get(metric, {}).get("values") or {}).get(stat)
thresholds = [{"metric": m, "threshold": t, "ok": bool(r.get("ok")), "values": metrics[m].get("values", {})}
              for m in sorted(metrics) for t, r in sorted((metrics[m].get("thresholds") or {}).items())]
crossed = [f"{t['metric']}: {t['threshold']}" for t in thresholds if not t["ok"]]
dropped = value("dropped_iterations", "count") or 0
invalid, reasons = [], []
if k6_exit == 105:
    verdict = "ABORTED"
    reasons.append("k6 was interrupted (exit 105); nothing is concluded")
else:
    if summary is None:
        invalid.append("k6 wrote no summary")
    if k6_exit not in (0, 99):
        invalid.append(f"k6 exited {k6_exit}: {K6_EXITS.get(k6_exit, 'not a test result')}")
    if summary is not None:
        if not thresholds:
            invalid.append("the script declares no threshold, so nothing was judged")
        if not value("http_reqs", "count"):
            invalid.append("no request was sent")
        if dropped:
            invalid.append(f"{int(dropped)} iterations were dropped: the generator did not offer the stated load "
                           "(too few virtual users, or the target slowed until they ran out)")
    if cpu_share >= 0.8:
        invalid.append(f"the load generator used {cpu_share:.0%} of this machine's {cores} CPUs: less than 20% was left idle, "
                       "so its timings cannot be trusted")
    if invalid:
        verdict, reasons = "INVALID", invalid + ([f"also crossed: {c}" for c in crossed])
    elif kind == "breakpoint":
        verdict = "MEASURED"
        reached = value("offered_rate", "value")
        reasons.append(f"the climb stopped at about {reached:.1f} requests per second ({'; '.join(crossed)})" if k6_exit == 99 and reached
                       else "no target was missed up to the ceiling of the climb")
    elif k6_exit == 99:
        verdict, reasons = "FAIL", [f"crossed: {c}" for c in crossed]
    else:
        verdict = "PASS" if tier == "verdict" else "INDICATIVE PASS"

digest = hashlib.sha256()
for path in sorted(os.path.join(base, n) for base, _, names in os.walk(load_dir) for n in names if n.endswith((".js", "profile.json"))):
    digest.update(open(path, "rb").read())
uname = os.uname()
latency = f"http_req_duration{{expected_response:true{',scenario:hold' if shape.get('warm_up') == 'excluded' else ''}}}"
stat = f"p({profile['slo']['latency']['percentile']})"
comparable_on = {"type": kind, "shape": {k: v for k, v in shape.items() if k not in ("decided_by", "reason")},
                 "scripts_and_profile": digest.hexdigest(), "k6": wanted, "cpus": cores, "machine": uname.machine, "system": uname.sysname,
                 "runner_class": os.environ.get("LOAD_RUNNER_CLASS", "")}
comparison = None
if tier == "indicative" and verdict == "INDICATIVE PASS" and kind == "average-load":
    comparison = {"with": args.get("previous", ""), "metric": f"{latency} {stat}", "now_ms": value(latency, stat)}
    previous = None
    if args.get("previous"):
        try:
            previous = json.load(open(args["previous"], encoding="utf-8"))
        except (OSError, ValueError):
            pass
    if previous is None:
        comparison["outcome"] = "no previous result to compare with"
    elif previous.get("comparable_on") != comparable_on:
        differs = sorted(k for k in comparable_on if (previous.get("comparable_on") or {}).get(k) != comparable_on[k])
        comparison["outcome"] = "not comparable with the previous run: " + ", ".join(differs) + " changed"
    elif previous.get("verdict") != "INDICATIVE PASS" or not (previous.get("comparison") or {}).get("now_ms"):
        comparison["outcome"] = "the previous run did not pass, so it is no baseline"
    else:
        before_ms, now_ms = previous["comparison"]["now_ms"], comparison["now_ms"]
        change = (now_ms - before_ms) / before_ms * 100
        comparison.update(previous_ms=before_ms, change_percent=round(change, 1), tolerance_percent=shape.get("tolerance_percent"))
        if not number(shape.get("tolerance_percent")):
            comparison["outcome"] = "reported only: the profile sets no tolerance_percent"
        elif change > shape["tolerance_percent"]:
            verdict = "FAIL"
            comparison["outcome"] = "regression"
            reasons.append(f"{stat} rose {change:.1f}% against the previous run ({before_ms:.2f} ms to {now_ms:.2f} ms), "
                           f"more than the {shape['tolerance_percent']}% the profile allows")
        else:
            comparison["outcome"] = "within tolerance"
    if comparison["outcome"] != "regression":
        reasons.append(f"comparison with the previous run: {comparison['outcome']}")

try:
    commit = subprocess.run(["git", "rev-parse", "--verify", "-q", "HEAD"], capture_output=True, text=True, timeout=30).stdout.strip() or "unknown"
except (OSError, subprocess.TimeoutExpired):
    commit = "unknown"
result = {
    "verdict": verdict, "reasons": reasons, "tier": tier, "type": kind, "k6_exit": k6_exit, "k6": version, "commit": commit,
    "started": started.strftime("%Y-%m-%dT%H:%M:%SZ"), "ended": ended.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "target": target, "product": profile.get("product", ""), "nfr": profile["nfr"], "slo": profile["slo"], "limiter": profile["limiter"],
    "shape": shape, "data": profile["data"], "subjects": len(subjects), "thresholds": thresholds,
    "requests": value("http_reqs", "count"), "request_rate": value("http_reqs", "rate"),
    "latency": metrics.get(latency, metrics.get("http_req_duration", {})).get("values", {}), "latency_metric": latency,
    "validity": {"dropped_iterations": int(dropped), "generator_cpu_share": round(cpu_share, 3), "generator_cpus": cores,
                 "retries": 0},
    "comparable_on": comparable_on, "comparison": comparison,
    "does_not_prove": NOT_PROVEN["verification" if target.get("verification") else tier],
    "summary_file": summary_path,
}
with open(result_path, "w", encoding="utf-8") as handle:
    json.dump(result, handle, indent=1)
print(f"== {verdict}: {tier} {kind} test (k6 exit {k6_exit}); result in {result_path}")
for reason in reasons:
    print(f"   {reason}")
if tier == "indicative":
    print("   Indicative only: this run proves nothing about capacity or about any stated target.")
if target.get("verification"):
    print(f"   Verification under impact statement {target['statement']['statement_id']}: a result about {base_url} "
          "at this time, not a capacity verdict.")
sys.exit({"PASS": 0, "INDICATIVE PASS": 0, "MEASURED": 0, "FAIL": 1, "INVALID": 4, "ABORTED": 130}[verdict])
PY
