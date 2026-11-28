#!/bin/bash
# run-chaos-experiment.sh --experiment <file.json> [--statement <file.json>] [--out <dir>]
#
# The only way a chaos experiment starts. It checks where the fault would go,
# refuses anything that is neither this run's own throwaway cluster nor a
# system named in a chaos statement the product owner signed, measures the
# steady state before injecting anything, injects the fault, confirms it is
# active, watches the abort conditions, always removes the fault and verifies
# the removal (on failure and on interruption too), checks recovery, and turns
# all of it into one verdict. It runs each experiment once: no retry.
#
# Where:
#   default      the target is read from the run marker of the cluster that
#                the end-to-end environment script created (E2E_RUN_ID,
#                E2E_KUBECONFIG). No address comes from the caller.
#   --statement  a system named in the product owner's signed chaos statement:
#                every field present, signed, not expired (or its
#                single_use_run_id equal to CHAOS_RUN_ID), the run inside its
#                window, the fault listed in it and within its limits, the
#                abort conditions at least as strict, the marker served unless
#                the statement says why it cannot be. Only Toxiproxy faults:
#                Chaos Mesh, Go tests and pytest run in the throwaway cluster
#                only.
#
# Fault tools: "toxiproxy" (a toxic through the Toxiproxy API), "chaos-mesh"
# (a Chaos Mesh manifest, throwaway cluster only), "go-test" (a build-tagged
# Go test that injects its own fault) and "pytest" (pytest tests marked chaos,
# under tests/chaos/, that inject their own fault). Both test tools report
# CHAOS-INVALID, CHAOS-REFUSED and CHAOS-FAULT-LEFT lines that this script
# reads, and get CHAOS_EXPERIMENT_ID. pytest runs with the product's addopts
# and PYTEST_ADDOPTS cleared, no cache and no rerun plugin; this script adds
# --junitxml and reads it, because pytest exits 0 when every test skipped.
#
# Verdicts and exit statuses:
#   0   PASS     steady state held before, the fault was confirmed active, the
#                SLI held during it, the removal was verified, it recovered
#   1   FAIL     the SLI fell below the objective during the fault, an abort
#                condition fired, it did not recover, or a Go test or pytest
#                test failed
#   2   usage or configuration error; nothing was injected
#   3   REFUSED  the target is not allowed; nothing was injected
#   4   INVALID  proves nothing: the steady state did not hold before
#                injection, the fault was never confirmed active, or the
#                test tool ran no test (pytest: none collected, any skipped,
#                or an error outside a test)
#   5   the fault's removal could not be verified: it may still be active
#   130 interrupted: the fault was removed (and the removal verified) first
# Results go to <out>/<experiment id>-result.json; <out> is --out, else
# $E2E_RESULTS_DIR/chaos, else chaos-evidence.
#
# This is python-chaos-test's copy of the runner go-chaos-test owns. Everything
# from `set -uo pipefail` down is the same program in both skills, and a test
# fails when the two differ: change them together. In a product with Go and
# Python services there is one copy, in tests/chaos/, and one chaos run.
set -uo pipefail
exec python3 -I - "$@" << 'PY'
import datetime, ipaddress, json, os, re, shlex, signal, socket, subprocess, sys, time
import urllib.error, urllib.parse, urllib.request, xml.etree.ElementTree

USAGE = "usage: run-chaos-experiment.sh --experiment <file.json> [--statement <file.json>] [--out <dir>]"
MESH_KINDS = ("PodChaos", "NetworkChaos", "StressChaos", "HTTPChaos", "IOChaos", "TimeChaos", "DNSChaos")
ONE_SHOT = ("pod-kill", "container-kill")
NOT_PROVEN = [
    "Reliability in general: a passing experiment shows this fault did not break this steady state in this run; "
    "a failing one shows a weakness (SRE book, Testing for Reliability).",
    "Any other fault, a combination of faults, or a fault at another size of system.",
]
interrupted = False


def stop(code, message):
    print(message, file=sys.stderr)
    sys.exit(code)


def refuse(message):
    stop(3, f"REFUSED: {message}\nNothing was injected.")


def on_signal(signum, frame):
    global interrupted
    interrupted = True


signal.signal(signal.SIGINT, on_signal)
signal.signal(signal.SIGTERM, on_signal)

args, argv = {}, sys.argv[1:]
while argv:
    flag = argv.pop(0)
    if flag not in ("--experiment", "--statement", "--out") or not argv:
        stop(2, USAGE)
    args[flag[2:]] = argv.pop(0)
if "experiment" not in args:
    stop(2, USAGE)

text = lambda v: isinstance(v, str) and v.strip() and not re.search(r"<[^>]*>|\bTBD\b|\bTODO\b", v)
number = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool) and v > 0


def load(path, what):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError) as exc:
        stop(2, f"ERROR: cannot read the {what} {path}: {exc}")
    if not isinstance(data, dict):
        stop(2, f"ERROR: the {what} {path} is not a JSON object")
    return data


# --------------------------------------------------------------- experiment
exp = load(args["experiment"], "experiment")
problems = []
for key in ("experiment_id", "pattern", "hypothesis", "blast_radius"):
    if not text(exp.get(key)):
        problems.append(f"{key}: missing")
fault = exp.get("fault") if isinstance(exp.get("fault"), dict) else {}
tool = fault.get("tool")
TEST_TOOLS = ("go-test", "pytest")
if tool not in ("toxiproxy", "chaos-mesh") + TEST_TOOLS:
    problems.append("fault.tool: toxiproxy, chaos-mesh, go-test or pytest")
steady = exp.get("steady_state") if isinstance(exp.get("steady_state"), dict) else None
if tool not in TEST_TOOLS or steady is not None:
    steady = steady or {}
    for key in ("slo_id", "sli", "endpoint", "path"):
        if not text(steady.get(key)):
            problems.append(f"steady_state.{key}: missing (the SLI exactly as the SLO record defines it)")
    if not (isinstance(steady.get("good_statuses"), list) and steady["good_statuses"]):
        problems.append("steady_state.good_statuses: the statuses the SLI counts as good")
    if "fault_header" in steady and not text(steady.get("fault_header")):
        problems.append("steady_state.fault_header: the response header the product sets on a degraded answer")
    for key in ("under_ms", "probe_per_second", "window_seconds"):
        if not number(steady.get(key)):
            problems.append(f"steady_state.{key}: a positive number")
    if not (number(steady.get("objective")) and steady["objective"] <= 1):
        problems.append("steady_state.objective: the SLO's objective as a fraction, for example 0.99")
abort = exp.get("abort") if isinstance(exp.get("abort"), dict) else {}
if not number(abort.get("max_seconds")):
    problems.append("abort.max_seconds: the hard bound on how long the fault may stay")
if tool not in TEST_TOOLS:
    if not (number(abort.get("sli_below")) and abort["sli_below"] <= 1):
        problems.append("abort.sli_below: the SLI below which the fault is removed at once")
    if not number(abort.get("over_seconds")):
        problems.append("abort.over_seconds: how long the SLI may stay below sli_below")
    if not number(exp.get("fault_seconds")):
        problems.append("fault_seconds: how long the fault stays")
    elif number(abort.get("max_seconds")) and exp["fault_seconds"] > abort["max_seconds"]:
        problems.append("fault_seconds is longer than abort.max_seconds")
    if not number((exp.get("recovery") or {}).get("within_seconds")):
        problems.append("recovery.within_seconds: how soon the steady state must return")
if tool == "toxiproxy":
    toxic = fault.get("toxic") if isinstance(fault.get("toxic"), dict) else {}
    for key in ("endpoint", "proxy"):
        if not text(fault.get(key)):
            problems.append(f"fault.{key}: missing")
    for key in ("name", "type", "stream"):
        if not text(toxic.get(key)):
            problems.append(f"fault.toxic.{key}: missing")
if tool == "chaos-mesh" and not text(fault.get("manifest")):
    problems.append("fault.manifest: the Chaos Mesh manifest file")
if tool == "go-test":
    command = fault.get("command", "")
    if not text(command) or not re.search(r"(^|\s)go test\s", command):
        problems.append("fault.command: a go test command")
    else:
        if not re.search(r"-tags[= ]\S*\bchaos\b", command):
            problems.append("fault.command: must build with -tags chaos")
        if not re.search(r"-count[= ]1\b", command):
            problems.append("fault.command: must carry -count=1 (a cached pass is not a run)")
        if re.search(r"--rerun-fails|-count[= ]([2-9]|\d\d)", command):
            problems.append("fault.command: an experiment is never retried")
if tool == "pytest":
    command = fault.get("command", "")
    if not text(command) or not re.search(r"(^|\s)(-m\s+)?pytest(\s|$)", command):
        problems.append("fault.command: a pytest command (pytest ..., python -m pytest ... or uv run pytest ...)")
    else:
        if not re.search(r"(^|\s)-m\s+[\"']?chaos\b", command) or re.search(r"\bnot\s+chaos\b", command):
            problems.append("fault.command: must select the chaos marker (-m chaos)")
        if not re.search(r"(^|\s)-p\s+no:cacheprovider\b", command):
            problems.append("fault.command: must carry -p no:cacheprovider (no last-failed or stepwise narrowing)")
        if not re.search(r"(^|\s)-p\s+no:rerunfailures\b", command):
            problems.append("fault.command: must carry -p no:rerunfailures (an experiment is never retried)")
        if not re.search(r"(^|\s)-o\s+[\"']?addopts=(\"\"|''|(?=[\s\"']|$))", command):
            problems.append("fault.command: must carry -o addopts=\"\" (the product's addopts may not narrow or retry it)")
        if re.search(r"--reruns\b|--lf\b|--last-failed\b|--ff\b|--failed-first\b|--sw\b|--stepwise\b|--count\b|--junit-?xml", command):
            problems.append("fault.command: no --reruns, --lf, --ff, --sw, --count or --junitxml: one run of the whole "
                            "selection, its report written where this script reads it")
if problems:
    stop(2, "EXPERIMENT ERROR in " + args["experiment"] + ":\n  " + "\n  ".join(problems))
exp_id = exp["experiment_id"]

# ------------------------------------------------------------------- target
target = {}


def loopback(host):
    try:
        return ipaddress.ip_address(host.strip("[]")).is_loopback
    except ValueError:
        return False


def stays_local(host):
    if loopback(host):
        return True
    if not (host.lower() == "localhost" or host.lower().endswith(".localhost")):
        return False
    try:
        found = {info[4][0] for info in socket.getaddrinfo(host, None)}
    except OSError:
        return False
    return bool(found) and all(loopback(a.split("%")[0]) for a in found)


def kubectl(*more, check=True):
    command = ["kubectl", "--kubeconfig", target["kubeconfig"], "--context", target["context"], *more]
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=180)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, "", str(exc)
    return done.returncode, done.stdout, done.stderr


if "statement" not in args:
    run_id, kubeconfig = os.environ.get("E2E_RUN_ID", ""), os.environ.get("E2E_KUBECONFIG", "")
    if not run_id or not kubeconfig:
        refuse("E2E_RUN_ID and E2E_KUBECONFIG are not set: a chaos experiment runs only inside the end-to-end "
               "environment run (make chaos), as a line of E2E_SUITES, or under the product owner's signed "
               "chaos statement (--statement)")
    real = os.path.realpath(kubeconfig)
    own = [os.path.realpath(os.path.expanduser("~/.kube/config"))]
    own += [os.path.realpath(p) for p in os.environ.get("KUBECONFIG", "").split(os.pathsep) if p]
    if real in own:
        refuse("E2E_KUBECONFIG is the caller's own kubeconfig, not one created for a run")
    if not os.path.isfile(real):
        refuse(f"E2E_KUBECONFIG {kubeconfig} does not exist")
    target.update(kubeconfig=real, context=f"kind-e2e-{run_id}")
    try:
        view = json.loads(subprocess.run(["kubectl", "--kubeconfig", real, "config", "view", "-o", "json"],
                                         capture_output=True, text=True, timeout=60).stdout)
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        refuse(f"cannot read the kubeconfig: {exc}")
    entry = next((c for c in view.get("contexts") or [] if c.get("name") == target["context"]), None)
    if entry is None:
        refuse(f"the kubeconfig has no context {target['context']}")
    cluster = next((c for c in view.get("clusters") or [] if c.get("name") == entry["context"].get("cluster")), {})
    server = urllib.parse.urlsplit(cluster.get("cluster", {}).get("server", ""))
    if not server.hostname or not loopback(server.hostname):
        refuse(f"the API server of {target['context']} ({server.netloc or 'unknown'}) is not on this machine")
    rc, out, err = kubectl("get", "configmap", "e2e-run-marker", "-n", "default", "-o", "json")
    try:
        marker = (json.loads(out).get("data") or {}) if rc == 0 else {}
    except (ValueError, AttributeError):
        marker = {}
    if marker.get("run-id") != run_id:
        refuse(f"the cluster's run marker says run \"{marker.get('run-id')}\", this run is \"{run_id}\"")

    def address(name):
        found = marker.get(f"endpoint.{name}", "")
        if not re.fullmatch(r"127\.0\.0\.1:\d+", found):
            refuse(f"the run marker has no loopback address for endpoint \"{name}\" (found \"{found}\")")
        return f"http://{found}"

    target["environment"] = f"throwaway kind cluster e2e-{run_id}, created and deleted by this run"
    target["run_id"] = run_id
else:
    if tool != "toxiproxy":
        refuse(f"a {tool} fault runs only in the run's own throwaway cluster: Chaos Mesh's daemon is privileged "
               "(host PID, host mounts) and an in-process test (go test or pytest) is not bounded by the statement; "
               "on another system only a Toxiproxy fault the statement lists is allowed")
    st = load(args["statement"], "chaos statement")
    for key in ("statement_id", "product", "base_url", "toxiproxy_api", "purpose", "blast_radius", "how_to_stop",
                "watched_by", "window_start", "window_end", "marker", "approved_by", "approved_on"):
        if not text(st.get(key)):
            refuse(f"the chaos statement has no {key}" + (": it carries no product-owner sign-off" if key.startswith("approved") else ""))
    impact = st.get("impact")
    for key in ("other_users", "other_teams", "dependent_systems", "third_parties", "data", "cost"):
        if not isinstance(impact, dict) or not text(impact.get(key)):
            refuse(f"the chaos statement has no impact.{key}: it must say who and what the fault affects (\"none\" where nothing)")
    st_abort = st.get("abort") if isinstance(st.get("abort"), dict) else {}
    for key in ("sli_below", "over_seconds", "max_seconds"):
        if not number(st_abort.get(key)):
            refuse(f"the chaos statement has no abort.{key}: it must state the abort conditions it was signed with")
    if not isinstance(st.get("faults"), list) or not st["faults"]:
        refuse("the chaos statement lists no faults: it must name exactly which faults it allows")
    if not (st["marker"] == "served" or re.fullmatch(r"cannot be served: .{10,}", st["marker"])):
        refuse("the chaos statement's marker must be \"served\", or \"cannot be served: <why>\"")
    if not text(st.get("expires_on")) and not text(st.get("single_use_run_id")):
        refuse("the chaos statement has neither expires_on nor single_use_run_id: a signed statement must lapse")
    today = datetime.datetime.now(datetime.timezone.utc).date()
    try:
        approved = datetime.date.fromisoformat(st["approved_on"])
        expires = datetime.date.fromisoformat(st["expires_on"]) if text(st.get("expires_on")) else None
    except ValueError:
        refuse("approved_on and expires_on of the chaos statement must be dates (yyyy-mm-dd)")
    if approved > today:
        refuse(f"the chaos statement is dated {approved}, which is in the future")
    if expires is not None and expires < today:
        refuse(f"the chaos statement expired on {expires}; the product owner has to sign a new one")
    if text(st.get("single_use_run_id")) and st["single_use_run_id"] != os.environ.get("CHAOS_RUN_ID", ""):
        refuse(f"the chaos statement is for run \"{st['single_use_run_id']}\" only; this run is "
               f"\"{os.environ.get('CHAOS_RUN_ID', '')}\" (CHAOS_RUN_ID)")
    toxic = fault["toxic"]
    allowed = next((f for f in st["faults"] if isinstance(f, dict) and f.get("tool") == "toxiproxy"
                    and f.get("proxy") == fault["proxy"] and f.get("type") == toxic["type"]), None)
    if allowed is None:
        refuse(f"the chaos statement does not allow a {toxic['type']} toxic on proxy \"{fault['proxy']}\"")
    for name, value in (toxic.get("attributes") or {}).items():
        most = (allowed.get("max_attributes") or {}).get(name)
        if not number(most) or not isinstance(value, (int, float)) or value > most:
            refuse(f"the experiment's {name} ({value}) exceeds what the chaos statement allows ({most})")
    if exp["fault_seconds"] > st_abort["max_seconds"] or abort["max_seconds"] > st_abort["max_seconds"]:
        refuse(f"the experiment keeps the fault longer than the {st_abort['max_seconds']} s the chaos statement allows")
    if abort["sli_below"] < st_abort["sli_below"] or abort["over_seconds"] > st_abort["over_seconds"]:
        refuse("the experiment's abort conditions are looser than the ones the chaos statement was signed with "
               f"(SLI below {st_abort['sli_below']} for {st_abort['over_seconds']} s)")
    try:
        start, end = (datetime.datetime.fromisoformat(st[k].replace("Z", "+00:00")) for k in ("window_start", "window_end"))
        if start.tzinfo is None or end.tzinfo is None:
            raise ValueError("no time zone")
    except ValueError:
        refuse("window_start and window_end must be date-times with a time zone (yyyy-mm-ddThh:mm:ssZ)")
    longest = steady["window_seconds"] + abort["max_seconds"] + exp["recovery"]["within_seconds"] + 60
    now = datetime.datetime.now(datetime.timezone.utc)
    if now < start or now + datetime.timedelta(seconds=longest) > end:
        refuse(f"the run would not fit inside the statement's window ({start.isoformat()} to {end.isoformat()}); "
               f"it takes up to {longest:.0f} seconds")
    urls = {}
    for key in ("base_url", "toxiproxy_api"):
        url = urllib.parse.urlsplit(st[key])
        if url.scheme not in ("http", "https") or not url.hostname or url.path not in ("", "/") or url.query or url.username:
            refuse(f"{key} \"{st[key]}\" of the chaos statement must be scheme://host[:port] with nothing after it")
        if url.scheme == "http" and not stays_local(url.hostname):
            refuse(f"{key} must be https unless it is on this machine")
        urls[key] = f"{url.scheme}://{url.netloc}"
    if st["marker"] == "served":
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), type("NoRedirect", (urllib.request.HTTPRedirectHandler,), {
            "redirect_request": lambda self, *a, **k: None})())
        try:
            with opener.open(urls["base_url"] + "/.well-known/chaos-statement", timeout=15) as answer:
                served = json.loads(answer.read(65536).decode("utf-8"))
        except urllib.error.HTTPError as exc:
            refuse(f"{urls['base_url']} does not serve the chaos statement marker ({exc}); it is not the system the statement names")
        except (OSError, ValueError, urllib.error.URLError) as exc:
            refuse(f"{urls['base_url']} does not serve the chaos statement marker ({exc}); it is not the system the statement names")
        if not isinstance(served, dict) or served.get("statement_id") != st["statement_id"]:
            refuse(f"{urls['base_url']} serves statement \"{served.get('statement_id') if isinstance(served, dict) else served}\", "
                   f"the chaos statement says \"{st['statement_id']}\"")

    def address(name):
        if name == steady["endpoint"]:
            return urls["base_url"]
        if name == fault.get("endpoint"):
            return urls["toxiproxy_api"]
        refuse(f"the chaos statement names no address for endpoint \"{name}\"")

    target["environment"] = f"{urls['base_url']}, named in chaos statement {st['statement_id']}"
    target["statement"] = st  # verbatim, as the product owner signed it

# ---------------------------------------------------------------- the probe
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), type("NoRedirect", (urllib.request.HTTPRedirectHandler,), {
    "redirect_request": lambda self, *a, **k: None})())
samples = []  # (phase, monotonic time, good)
marked = {"before": 0, "during": 0, "after": 0}  # answers carrying steady_state.fault_header


def probe_once(phase):
    url = probe_base + steady["path"]
    started = time.monotonic()
    try:
        with opener.open(url, timeout=max(2.0, steady["under_ms"] / 500.0)) as answer:
            answer.read(65536)
            status = answer.status
            if steady.get("fault_header") and answer.headers.get(steady["fault_header"]):
                marked[phase] += 1
    except urllib.error.HTTPError as exc:
        status = exc.code
    except (OSError, urllib.error.URLError):
        status = 0
    took = (time.monotonic() - started) * 1000
    good = status in steady["good_statuses"] and took < steady["under_ms"]
    samples.append((phase, time.monotonic(), good))
    rest = 1.0 / steady["probe_per_second"] - (time.monotonic() - started)
    if rest > 0:
        time.sleep(rest)  # the probe's own pace, not a wait for the system


def sli(phase, since=None):
    chosen = [g for p, t, g in samples if p == phase and (since is None or t >= since)]
    return (sum(chosen) / len(chosen), len(chosen)) if chosen else (None, 0)


# ------------------------------------------------------------- the fault
injected = False
removal = {"verified": False, "detail": "nothing was injected"}


def toxi(method, path, body=None):
    request = urllib.request.Request(toxi_base + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
    if os.environ.get("TOXIPROXY_AUTH_TOKEN"):
        request.add_header("Authorization", "Bearer " + os.environ["TOXIPROXY_AUTH_TOKEN"])
    try:
        with opener.open(request, timeout=15) as answer:
            raw = answer.read()
            return answer.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")
    except (OSError, ValueError, urllib.error.URLError) as exc:
        return 0, str(exc)


def mesh_object():
    rc, out, err = kubectl("get", manifest["kind"], manifest["metadata"]["name"], "-n", manifest["metadata"]["namespace"], "-o", "json")
    if rc != 0:
        return None, err
    try:
        return json.loads(out), ""
    except ValueError:
        return None, "kubectl did not answer with JSON"


def inject():
    if tool == "toxiproxy":
        status, answer = toxi("POST", f"/proxies/{fault['proxy']}/toxics", {
            "name": fault["toxic"]["name"], "type": fault["toxic"]["type"], "stream": fault["toxic"]["stream"],
            "toxicity": fault["toxic"].get("toxicity", 1.0), "attributes": fault["toxic"].get("attributes", {})})
        return status == 200, f"Toxiproxy answered {status}: {answer}"
    rc, out, err = kubectl("apply", "-f", fault["manifest"])
    return rc == 0, (out + err).strip()


def confirmed():
    if tool == "toxiproxy":
        status, answer = toxi("GET", f"/proxies/{fault['proxy']}/toxics")
        return status == 200 and isinstance(answer, list) and any(t.get("name") == fault["toxic"]["name"] for t in answer)
    found, _ = mesh_object()
    conditions = ((found or {}).get("status") or {}).get("conditions") or []
    return any(c.get("type") == "AllInjected" and c.get("status") == "True" for c in conditions)


def remove():
    """Remove the fault and verify it is gone. Runs on every path once anything was injected."""
    global injected
    if not injected or tool == "go-test":
        return
    injected = False
    if tool == "toxiproxy":
        status, answer = toxi("DELETE", f"/proxies/{fault['proxy']}/toxics/{fault['toxic']['name']}")
        listing, toxics = toxi("GET", f"/proxies/{fault['proxy']}/toxics")
        gone = listing == 200 and isinstance(toxics, list) and not any(t.get("name") == fault["toxic"]["name"] for t in toxics)
        removal.update(verified=gone, detail=f"DELETE answered {status}; the proxy {'no longer lists' if gone else 'may still list'} the toxic")
        return
    rc, out, err = kubectl("delete", manifest["kind"], manifest["metadata"]["name"], "-n", manifest["metadata"]["namespace"],
                           "--wait=true", "--timeout=120s")
    found, err2 = mesh_object()
    gone = found is None and "NotFound" in err2
    removal.update(verified=gone, detail=f"kubectl delete exit {rc}; the object is {'gone (Chaos Mesh recovers the fault before it removes the object)' if gone else 'still there or unreadable: ' + (err2 or 'present')}")


def finish(verdict, reasons, code):
    remove()
    if not removal["verified"] and removal["detail"] != "nothing was injected":
        reasons = reasons + [f"THE FAULT MAY STILL BE ACTIVE: its removal could not be verified ({removal['detail']}). "
                             "Remove it by hand now: " + how_to_remove]
        code = 5
    os.makedirs(out_dir, exist_ok=True)
    phases = {}
    for phase in ("before", "during", "after"):
        value, count = sli(phase)
        phases[phase] = {"sli": None if value is None else round(value, 4), "requests": count}
    result = {
        "experiment_id": exp_id, "verdict": verdict, "reasons": reasons, "pattern": exp["pattern"], "hypothesis": exp["hypothesis"],
        "blast_radius": exp["blast_radius"], "fault": fault, "abort": abort, "steady_state": steady, "target": target,
        "sli_by_phase": phases, "fault_header_answers": marked, "removal": removal, "retries": 0, "does_not_prove": NOT_PROVEN + list(exp.get("does_not_prove", [])),
        "started": started_at, "ended": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    path = os.path.join(out_dir, f"{exp_id}-result.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=1)
    print(f"== {verdict}: chaos experiment {exp_id} ({target['environment']}); result in {path}")
    for reason in reasons:
        print(f"   {reason}")
    print(f"   Fault removal: {removal['detail']}")
    sys.exit(code)


started_at = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
out_dir = args.get("out") or os.path.join(os.environ.get("E2E_RESULTS_DIR", "chaos-evidence"), "chaos")
how_to_remove = ""
manifest = None
if tool == "chaos-mesh":
    rc, out, err = kubectl("create", "--dry-run=client", "-o", "json", "-f", fault["manifest"])
    try:
        manifest = json.loads(out) if rc == 0 else None
    except ValueError:
        manifest = None
    if manifest is None:
        stop(2, f"ERROR: cannot read the Chaos Mesh manifest {fault['manifest']}: {err.strip()}")
    spec, meta = manifest.get("spec") or {}, manifest.get("metadata") or {}
    errors = []
    if manifest.get("kind") not in MESH_KINDS:
        errors.append(f"kind {manifest.get('kind')} is not one this script confirms ({', '.join(MESH_KINDS)})")
    if "scheduler" in spec:
        errors.append("spec.scheduler was removed in Chaos Mesh 2.0; a repeated fault is a Schedule resource")
    if not meta.get("namespace") or not meta.get("name"):
        errors.append("metadata.name and metadata.namespace are required")
    selector = spec.get("selector") or {}
    if selector.get("namespaces") != [meta.get("namespace")]:
        errors.append("spec.selector.namespaces must be exactly the experiment's own namespace")
    if not selector.get("labelSelectors"):
        errors.append("spec.selector.labelSelectors must name the pods the blast radius allows")
    if spec.get("action") not in ONE_SHOT and not spec.get("duration"):
        errors.append("spec.duration is required: it bounds a sustained fault even if this script dies")
    if errors:
        stop(2, "MANIFEST ERROR in " + fault["manifest"] + ":\n  " + "\n  ".join(errors))
    how_to_remove = f"kubectl delete {manifest['kind']} {meta['name']} -n {meta['namespace']}"

# -------------------------------------------------------- go-test and pytest
if tool in TEST_TOOLS:
    env = dict(os.environ, CHAOS_EXPERIMENT_ID=exp_id)
    command = fault["command"]
    if tool == "pytest":
        env.pop("PYTEST_ADDOPTS", None)
        os.makedirs(out_dir, exist_ok=True)
        junit = os.path.join(os.path.abspath(out_dir), f"{exp_id}-junit.xml")
        if os.path.exists(junit):
            os.remove(junit)
        command += " --junitxml=" + shlex.quote(junit)
    print(f"== chaos experiment {exp_id} ({tool}, {target['environment']})", flush=True)
    child = subprocess.Popen(["/bin/bash", "-c", command], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, env=env, start_new_session=True)
    lines = []
    for line in child.stdout:
        print(line, end="")
        lines.append(line)
        if interrupted:
            os.killpg(child.pid, signal.SIGINT)
    child.wait()
    output = "".join(lines)
    reset = fault.get("reset_toxiproxy")
    if reset:
        toxi_base = address(reset)
        status, proxies = toxi("POST", "/reset")
        listing, proxies = toxi("GET", "/proxies")
        left = [n for n, p in (proxies or {}).items() if isinstance(p, dict) and p.get("toxics")] if listing == 200 else ["unknown"]
        removal.update(verified=not left, detail=f"Toxiproxy reset answered {status}; toxics left on: {left or 'none'}")
        injected = False
    marks = lambda tag: list(dict.fromkeys(m.strip() for m in re.findall(tag + r": (.*)", output)))
    if interrupted:
        finish("INVALID", [f"interrupted: the {tool} run was stopped; nothing is concluded"], 130)
    if marks("CHAOS-FAULT-LEFT"):
        removal.update(verified=False, detail="; ".join(marks("CHAOS-FAULT-LEFT")))
        how_to_remove = "reset the Toxiproxy of the run (POST /reset) or let the environment run delete the cluster"
        finish("INVALID", [f"the {tool} run could not verify its fault's removal"], 5)
    if marks("CHAOS-REFUSED"):
        finish("REFUSED", marks("CHAOS-REFUSED"), 3)
    if marks("CHAOS-INVALID"):
        finish("INVALID", marks("CHAOS-INVALID"), 4)
    if tool == "pytest":
        # pytest's own report, not its exit status alone: 0 is also what an all-skipped run gives.
        if child.returncode == 5:
            finish("INVALID", ["pytest collected no test (exit 5): the selection matched nothing"], 4)
        try:
            suites = list(xml.etree.ElementTree.parse(junit).getroot().iter("testsuite"))
            count = lambda key: sum(int(s.get(key, 0)) for s in suites)
            tests, failed, errors, skipped = count("tests"), count("failures"), count("errors"), count("skipped")
        except (OSError, ValueError, xml.etree.ElementTree.ParseError) as exc:
            finish("INVALID", [f"pytest exited {child.returncode} and wrote no readable report ({exc}): nothing is concluded"], 4)
        if child.returncode not in (0, 1):
            finish("INVALID", [f"pytest exited {child.returncode} outside a test (2 = interrupted or a collection error, "
                               "3 = internal error, 4 = usage error): nothing is concluded"], 4)
        if failed or errors or child.returncode != 0:
            finish("FAIL", [f"pytest: {failed} failed, {errors} error(s) of {tests}: a pattern assertion failed (see the output above)"], 1)
        if tests == 0:
            finish("INVALID", ["pytest ran no test: the selection matched nothing"], 4)
        if skipped:
            finish("INVALID", [f"pytest skipped {skipped} of {tests} test(s): a skipped experiment proves nothing"], 4)
        finish("PASS", [f"every pattern assertion held ({tests} pytest test(s))"], 0)
    if child.returncode != 0:
        finish("FAIL", [f"go test exited {child.returncode}: a pattern assertion failed (see the output above)"], 1)
    if not [l for l in output.splitlines() if l.startswith("ok") and "[no tests to run]" not in l]:
        finish("INVALID", ["go test ran no test: the selection matched nothing"], 4)
    finish("PASS", ["every pattern assertion held"], 0)

# ------------------------------------------------- toxiproxy and chaos-mesh
probe_base = address(steady["endpoint"])
if tool == "toxiproxy":
    toxi_base = address(fault["endpoint"])
    how_to_remove = f"curl -X DELETE {toxi_base}/proxies/{fault['proxy']}/toxics/{fault['toxic']['name']}"
print(f"== chaos experiment {exp_id}: {tool} fault, {target['environment']}", flush=True)

# The published port can accept connections before the cluster routes them: poll until the
# endpoint gives any HTTP answer (60 s at most) before the steady state is measured.
deadline = time.monotonic() + 60
while not interrupted:
    try:
        opener.open(probe_base + steady["path"], timeout=5).close()
        break
    except urllib.error.HTTPError:
        break
    except (OSError, urllib.error.URLError) as exc:
        if time.monotonic() > deadline:
            finish("INVALID", [f"{probe_base} gave no HTTP answer within 60 s ({exc}); nothing was injected"], 4)
        time.sleep(0.5)  # poll interval inside a deadline

window = steady["window_seconds"]
end = time.monotonic() + window
while time.monotonic() < end and not interrupted:
    probe_once("before")
if interrupted:
    finish("INVALID", ["interrupted before injection"], 130)
before, count = sli("before")
if before is None or before < steady["objective"]:
    finish("INVALID", [f"the steady state did not hold before injection: {steady['sli']} was "
                       f"{'none' if before is None else f'{before:.3f}'} over {count} requests, below the objective "
                       f"{steady['objective']} ({steady['slo_id']}); nothing was injected"], 4)

injected = True  # from here on every path removes it, even if the inject call failed half way
ok, detail = inject()
if not ok:
    finish("INVALID", [f"the fault was never injected: {detail}"], 4)
deadline = time.monotonic() + 60
while not confirmed():
    if time.monotonic() > deadline or interrupted:
        finish("INVALID", ["the fault was never confirmed active (Toxiproxy did not list the toxic, or Chaos Mesh did not "
                           "report AllInjected within 60 s): the experiment proves nothing"], 130 if interrupted else 4)
    time.sleep(1)  # poll interval inside a deadline
injected_at = time.monotonic()
print(f"   fault confirmed active; watching abort: {steady['sli']} below {abort['sli_below']} over {abort['over_seconds']} s, "
      f"or {abort['max_seconds']} s in all", flush=True)

aborted = None
stop_at = injected_at + min(exp["fault_seconds"], abort["max_seconds"])
while time.monotonic() < stop_at and not interrupted:
    probe_once("during")
    now = time.monotonic()
    if now - injected_at >= abort["over_seconds"]:
        recent, n = sli("during", since=now - abort["over_seconds"])
        if recent is not None and recent < abort["sli_below"]:
            aborted = f"abort condition: {steady['sli']} was {recent:.3f} over the last {abort['over_seconds']} s, below {abort['sli_below']}"
            break
if interrupted:
    finish("INVALID", ["interrupted while the fault was active; nothing is concluded"], 130)
remove()
if not removal["verified"]:
    finish("INVALID", ["the fault's removal could not be verified"], 5)
print(f"   fault removed and verified: {removal['detail']}", flush=True)

recovered = False
paced = False  # did the probe ever keep its own pace for a whole window after removal?
recovery_end = time.monotonic() + exp["recovery"]["within_seconds"]
while time.monotonic() < recovery_end and not interrupted:
    probe_once("after")
    recent = [g for p, t, g in samples if p == "after" and t >= time.monotonic() - window]
    if len(recent) >= window * steady["probe_per_second"] * 0.8:
        paced = True
        if sum(recent) / len(recent) >= steady["objective"]:
            recovered = True
            break
if interrupted:
    finish("INVALID", ["interrupted during recovery; the fault was already removed"], 130)

during, n = sli("during")
if steady.get("fault_header") and not marked["during"] and not aborted:
    finish("INVALID", [f"no answer during the fault carried {steady['fault_header']}: the fault never reached the path the "
                       "steady state measures, so the experiment proves nothing"], 4)
reasons = []
if aborted:
    reasons.append(aborted + "; the fault was removed at once")
elif during is None or during < steady["objective"]:
    reasons.append(f"{steady['sli']} was {'none' if during is None else f'{during:.3f}'} during the fault over {n} requests, "
                   f"below the objective {steady['objective']}")
if not recovered and not paced and not reasons:
    # A slow probe (a busy machine, a slow network) must not be read as a product that did not recover.
    finish("INVALID", [f"after removing the fault the probe never kept its own pace of {steady['probe_per_second']} a second "
                       f"for a whole {window} s window, so recovery could not be judged; lower probe_per_second or run on a "
                       "less busy machine"], 4)
if not recovered:
    reasons.append(f"the steady state did not return within {exp['recovery']['within_seconds']} s of removing the fault")
if reasons:
    finish("FAIL", reasons, 1)
finish("PASS", [f"{steady['sli']} was {before:.3f} before, {during:.3f} during the fault ({n} requests), and recovered"], 0)
PY
