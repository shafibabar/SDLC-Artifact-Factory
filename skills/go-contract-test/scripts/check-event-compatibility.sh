#!/bin/bash
# check-event-compatibility.sh --schemas <dir> (--baseline <dir> | --first-release)
#     --registry http://127.0.0.1:<port>
#
# The event schema gate. <dir> holds one folder per event with its JSON Schema
# versions, and the compatibility mode the event design declares for each:
#   <dir>/<context>/<event>/1.json, 2.json, ...
#   <dir>/modes.txt        lines of "<context>/<event> <MODE>"
# --baseline is the same folder as it is deployed, for example
#   git archive "$DEPLOYED_REF" schemas/events | tar -x -C deployed
# Checks, in order:
#   1. every event has a mode; NONE, or an unknown mode, fails;
#   2. no deployed event or version file is missing or edited in place; versions
#      are numbered 1..n without gaps;
#   3. pass "declared": every version is checked against the earlier ones by
#      a schema registry under the declared mode;
#   4. pass "add-only": the same again on copies with additionalProperties:false
#      written into every object that has properties, under BACKWARD_TRANSITIVE.
#      It fails a removed or renamed field, which pass 3 lets through when the
#      schema is open.
# The registry is a throwaway one this run may write to: only a loopback
# address is accepted. Subjects get a random prefix.
# Not detected by either pass: a change of meaning or unit, a changed format,
# and (under BACKWARD) an added enum value.
# Exit 0 = compatible, 1 = a check failed, 2 = usage error, unreadable input or
# no registry.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import json, os, re, sys, urllib.error, urllib.parse, urllib.request, uuid

MODES = {"BACKWARD", "BACKWARD_TRANSITIVE", "FORWARD", "FORWARD_TRANSITIVE", "FULL", "FULL_TRANSITIVE"}
args = sys.argv[1:]
opts, first_release = {}, False

def stop(code, message):
    print(message)
    sys.exit(code)

while args:
    flag = args.pop(0)
    if flag == "--first-release":
        first_release = True
    elif flag in ("--schemas", "--baseline", "--registry") and args:
        opts[flag[2:]] = args.pop(0)
    else:
        stop(2, "usage: check-event-compatibility.sh --schemas <dir> (--baseline <dir> | --first-release)"
                " --registry http://127.0.0.1:<port>")
if "schemas" not in opts or "registry" not in opts or first_release == ("baseline" in opts):
    stop(2, "usage: give --schemas, --registry and exactly one of --baseline or --first-release")

registry = opts["registry"].rstrip("/")
host = urllib.parse.urlsplit(registry).hostname
if host not in ("127.0.0.1", "localhost", "::1"):
    stop(2, f"ERROR: {registry} is not a loopback address. This check registers throwaway subjects,"
            " so it only talks to a registry started for the run.")

def load_tree(root, what):
    """{event: {version number: schema}} and {event: mode} for one folder."""
    if not os.path.isdir(root):
        stop(2, f"ERROR: {what} folder {root} does not exist. A missing folder is a failure, never a pass.")
    events, problems = {}, []
    for base, dirs, names in os.walk(root):
        dirs.sort()
        versions = {}
        for name in sorted(names):
            if not name.endswith(".json"):
                continue
            path = os.path.join(base, name)
            if not re.fullmatch(r"[1-9][0-9]*\.json", name):
                problems.append(f"{path}: a version file is named <number>.json")
                continue
            try:
                with open(path, encoding="utf-8") as handle:
                    versions[int(name[:-5])] = json.load(handle)
            except (OSError, ValueError) as exc:
                problems.append(f"{path}: not readable JSON ({exc})")
        if versions:
            events[os.path.relpath(base, root).replace(os.sep, "/")] = versions
    modes = {}
    try:
        with open(os.path.join(root, "modes.txt"), encoding="utf-8") as handle:
            for line in handle:
                parts = line.split("#")[0].split()
                if len(parts) == 2:
                    modes[parts[0]] = parts[1].upper()
                elif parts:
                    problems.append(f"{root}/modes.txt: cannot read line '{line.strip()}'")
    except OSError:
        problems.append(f"{root}/modes.txt is missing: each event's mode comes from the event design")
    return events, modes, problems

events, modes, failures = load_tree(opts["schemas"], "schemas")
if not events:
    stop(2, f"ERROR: no <event>/<number>.json under {opts['schemas']}; nothing was checked")
baseline = {}
if not first_release:
    baseline, baseline_modes, baseline_problems = load_tree(opts["baseline"], "baseline")
    failures += [p for p in baseline_problems if "modes.txt" not in p]
    for event, mode in sorted(baseline_modes.items()):
        if event in modes and modes[event] != mode:
            print(f"WARN {event}: mode changed from {mode} to {modes[event]}; it must match the event design")

for event, versions in sorted(events.items()):
    mode = modes.get(event)
    if mode is None:
        failures.append(f"{event}: no mode in modes.txt")
    elif mode == "NONE":
        failures.append(f"{event}: mode NONE switches the check off and is never allowed on a published event")
    elif mode not in MODES:
        failures.append(f"{event}: unknown mode {mode}")
    if sorted(versions) != list(range(1, len(versions) + 1)):
        failures.append(f"{event}: versions {sorted(versions)} are not 1..{len(versions)}")
for event, versions in sorted(baseline.items()):
    if event not in events:
        failures.append(f"{event}: deployed event is missing; a published schema is never deleted")
        continue
    for number, schema in sorted(versions.items()):
        if number not in events[event]:
            failures.append(f"{event}/{number}.json: deployed version is missing; a published schema is never deleted")
        elif events[event][number] != schema:
            failures.append(f"{event}/{number}.json: deployed version was edited in place; add a new version file instead")

SINGLE = ("items", "additionalProperties", "additionalItems", "unevaluatedProperties", "unevaluatedItems",
          "not", "if", "then", "else", "contains", "propertyNames")
MAPS = ("properties", "patternProperties", "$defs", "definitions", "dependentSchemas")
LISTS = ("allOf", "anyOf", "oneOf", "prefixItems")

def closed(schema):
    """A copy with additionalProperties:false in every object schema that lists properties."""
    if not isinstance(schema, dict):
        return schema
    out = dict(schema)
    for key in SINGLE:
        if isinstance(out.get(key), dict):
            out[key] = closed(out[key])
        elif key == "items" and isinstance(out.get(key), list):
            out[key] = [closed(item) for item in out[key]]
    for key in MAPS:
        if isinstance(out.get(key), dict):
            out[key] = {name: closed(sub) for name, sub in out[key].items()}
    for key in LISTS:
        if isinstance(out.get(key), list):
            out[key] = [closed(sub) for sub in out[key]]
    if isinstance(schema.get("properties"), dict) and not isinstance(schema.get("additionalProperties"), dict):
        out["additionalProperties"] = False
    return out

def call(method, path, body=None):
    request = urllib.request.Request(registry + path, method=method,
                                     data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/vnd.schemaregistry.v1+json"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as exc:
        try:
            return exc.code, json.loads(exc.read() or b"{}")
        except ValueError:
            return exc.code, {}
    except (urllib.error.URLError, OSError, ValueError) as exc:
        stop(2, f"ERROR: no schema registry answered at {registry} ({exc}). The check did not run.")

run_id = uuid.uuid4().hex[:8]

def check(event, versions, mode, label, transform):
    subject = urllib.parse.quote(f"gc-{run_id}-{label}-{event.replace('/', '.')}", safe="")
    status, body = call("PUT", f"/config/{subject}", {"compatibility": mode})
    if status != 200:
        failures.append(f"{event} [{label}]: registry refused mode {mode} (HTTP {status} {body.get('message', '')})")
        return
    for number in sorted(versions):
        payload = {"schemaType": "JSON", "schema": json.dumps(transform(versions[number]))}
        if number > 1:
            status, body = call("POST", f"/compatibility/subjects/{subject}/versions/latest?verbose=true", payload)
            if status != 200 or body.get("is_compatible") is not True:
                detail = "; ".join(str(m) for m in body.get("messages", [])) or body.get("message", f"HTTP {status}")
                failures.append(f"{event}/{number}.json [{label}, {mode}]: not compatible with the earlier versions: {detail[:300]}")
                return
        status, body = call("POST", f"/subjects/{subject}/versions", payload)
        if status != 200:
            failures.append(f"{event}/{number}.json [{label}]: registry refused the schema (HTTP {status} {body.get('message', '')})")
            return
    print(f"ok {event} [{label}, {mode}]: {len(versions)} version(s)")

if not failures:
    for event, versions in sorted(events.items()):
        check(event, versions, modes[event], "declared", lambda schema: schema)
        check(event, versions, "BACKWARD_TRANSITIVE", "add-only", closed)

for failure in failures:
    print(f"FAIL {failure}")
if first_release:
    print("first release: no deployed schemas exist, so in-place edits and deletions were not checked")
print(f"checked {len(events)} event(s): {len(failures)} FAIL")
print("RESULT: FAIL" if failures else "RESULT: PASS (shape only: meaning, unit and format changes are not detected)")
sys.exit(1 if failures else 0)
PY
