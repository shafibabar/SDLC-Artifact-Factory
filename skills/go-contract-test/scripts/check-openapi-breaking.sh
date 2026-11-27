#!/bin/bash
# check-openapi-breaking.sh --base <deployed spec> --revision <new spec>
#     [--exceptions <file>] [--retirements <file>] [--severity-levels <file>]
#     [--oasdiff-version <x.y.z>] [--today YYYY-MM-DD]
# check-openapi-breaking.sh --first-release --revision <new spec>
#
# The API breaking-change gate. It compares the description that is deployed
# with the one about to merge, using oasdiff:
#   oasdiff breaking --fail-on WARN --severity-levels <file> --config <empty>
# and adds what oasdiff alone lets through:
#   - a baseline that is empty, has no paths or is not an OpenAPI description
#     is refused (oasdiff exits 0 on all three);
#   - a stray .oasdiff.yaml cannot switch checks off (an empty --config is passed);
#   - the severity file raises two changes oasdiff rates as information only:
#     an optional response field removed or renamed, and a documented error
#     response removed;
#   - every line of the exceptions file is printed on every run and must carry
#     "approved-by:" and "approved-on: YYYY-MM-DD";
#   - a removed endpoint needs a line in the retirements file, even after its
#     sunset date (oasdiff then reports nothing):
#       GET /v1/x | sunset: YYYY-MM-DD | no-caller-evidence: <text> | approved-by: <name> | approved-on: YYYY-MM-DD
#     ("*" as the method covers every method of the path.)
# Both spec arguments are files; write the deployed one first with
#   git show "$DEPLOYED_REF:api/openapi.yaml" > deployed.yaml
# Exit 0 = no breaking change, 1 = breaking change or a missing or incomplete
# record, 2 = usage error, unreadable input or oasdiff problem.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -I - "$HERE/../resources/oasdiff-severity.txt" "$@" <<'PY'
import datetime, json, os, re, subprocess, sys, tempfile

default_severity = sys.argv[1]
args = sys.argv[2:]
opts = {"severity-levels": default_severity, "oasdiff-version": "1.39.0",
        "today": datetime.date.today().isoformat()}
first_release = False

def stop(code, message):
    print(message)
    sys.exit(code)

while args:
    flag = args.pop(0)
    if flag == "--first-release":
        first_release = True
    elif flag in ("--base", "--revision", "--exceptions", "--retirements",
                  "--severity-levels", "--oasdiff-version", "--today") and args:
        opts[flag[2:]] = args.pop(0)
    else:
        stop(2, "usage: check-openapi-breaking.sh (--base <deployed spec> | --first-release) --revision <new spec>"
                " [--exceptions <file>] [--retirements <file>]")

if "revision" not in opts or first_release == ("base" in opts):
    stop(2, "usage: give --revision and exactly one of --base or --first-release")

DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

def read(path, what):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError as exc:
        stop(2, f"ERROR: cannot read {what} {path}: {exc.strerror}. A missing file is a failure, never a pass.")

def looks_like_openapi(text):
    try:
        document = json.loads(text)
    except ValueError:
        document = None
    if document is not None:
        paths = document.get("paths") if isinstance(document, dict) else None
        return bool(isinstance(paths, dict) and paths and "openapi" in document)
    has_version = re.search(r'(?m)^\s*["\']?openapi["\']?\s*:', text)
    has_paths = re.search(r'(?m)^\s*["\']?paths["\']?\s*:', text)
    has_a_path = re.search(r'(?m)^\s*["\']?/[^\s"\':]*["\']?\s*:', text) or re.search(r'"paths"\s*:\s*\{\s*"/', text)
    return bool(has_version and has_paths and has_a_path)

for name in ("base", "revision"):
    if name in opts and not looks_like_openapi(read(opts[name], name + " spec")):
        stop(2, f"ERROR: {opts[name]} is empty, has no paths or is not an OpenAPI description."
                " oasdiff would report no breaking change against it, so the gate refuses it.")

def approved(line):
    by = re.search(r"approved-by:\s*\S", line)
    on = re.search(r"approved-on:\s*(\S+)", line)
    return bool(by and on and DATE.match(on.group(1).rstrip("|,;")))

ENUM_ADDED = re.compile(r"added the new .+ enum value to .*response")

exceptions = []
if "exceptions" in opts:
    for number, line in enumerate(read(opts["exceptions"], "exceptions file").splitlines(), 1):
        if line.strip() and not line.lstrip().startswith("#"):
            exceptions.append((number, line.strip()))
print(f"exceptions in force: {len(exceptions)}")
bad = False
for number, line in exceptions:
    print(f"  EXCEPTION line {number}: {line}")
    if not approved(line):
        print(f"  FAIL line {number}: no 'approved-by:' and 'approved-on: YYYY-MM-DD'; an exception counts only once the product owner approved it")
        bad = True
    # An exception covers one thing only: a new enum value in a response, in
    # the words oasdiff prints for it. A removed or renamed response field, a
    # removed error response or any other breaking change has no exception; it
    # ships as a new major version beside the old one (api-contract-design).
    if not ENUM_ADDED.search(line.split("|", 1)[0]):
        print(f"  FAIL line {number}: an exception covers only a new enum value in a response "
              "('added the new `x` enum value to the `y` response property'); any other breaking change "
              "has no exception and ships as a new major version")
        bad = True
if bad:
    sys.exit(1)

if first_release:
    print("first release: no deployed description exists, so nothing was compared. Say so in the report.")
    sys.exit(0)

def run(command):
    try:
        return subprocess.run(command, capture_output=True, text=True)
    except OSError as exc:
        stop(2, f"ERROR: cannot run oasdiff: {exc.strerror}. Install the pinned version; the gate never passes without it.")

version = run(["oasdiff", "--version"])
if opts["oasdiff-version"] not in version.stdout + version.stderr:
    stop(2, f"ERROR: oasdiff {opts['oasdiff-version']} is required, found: {(version.stdout + version.stderr).strip() or 'nothing'}")

failed = False
with tempfile.TemporaryDirectory() as work:
    config = os.path.join(work, "empty.yaml")
    with open(config, "w", encoding="utf-8") as handle:
        handle.write("{}\n")
    command = ["oasdiff", "breaking", "--fail-on", "WARN", "--config", config,
               "--severity-levels", opts["severity-levels"]]
    if "exceptions" in opts:
        command += ["--err-ignore", opts["exceptions"], "--warn-ignore", opts["exceptions"]]
    result = run(command + [opts["base"], opts["revision"]])
    print((result.stdout + result.stderr).rstrip())
    if result.returncode == 1:
        failed = True
        print("FAIL: breaking change. Keep the change additive, or publish it as a new major version beside the old one.")
    elif result.returncode != 0:
        stop(2, f"ERROR: oasdiff exited {result.returncode}; the comparison did not run")

    listing = run(["oasdiff", "diff", "--format", "json", "--config", config, opts["base"], opts["revision"]])
    if listing.returncode != 0:
        stop(2, f"ERROR: oasdiff diff exited {listing.returncode}: {listing.stderr.strip()}")
    try:
        paths = (json.loads(listing.stdout or "{}") or {}).get("paths", {})
    except ValueError:
        stop(2, "ERROR: oasdiff diff did not print JSON; removed endpoints could not be listed")

removed = [("*", path) for path in paths.get("deleted", [])]
for path, change in sorted(paths.get("modified", {}).items()):
    removed += [(method.upper(), path) for method in (change.get("operations") or {}).get("deleted", [])]

records = []
if "retirements" in opts:
    for line in read(opts["retirements"], "retirements file").splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            fields = [part.strip() for part in line.split("|")]
            head = fields[0].split()
            values = dict(part.split(":", 1) for part in fields[1:] if ":" in part)
            records.append((head, {key.strip(): value.strip() for key, value in values.items()}, line.strip()))

for method, path in removed:
    label = path if method == "*" else f"{method} {path}"
    match = [r for r in records if len(r[0]) == 2 and r[0][1] == path and (method == "*" or r[0][0].upper() in (method, "*"))]
    if not match:
        failed = True
        print(f"FAIL: {label} was removed and has no retirement record. Removal needs the product owner's"
              " recorded sign-off with the evidence that no caller remains, even after the sunset date.")
        continue
    for head, values, line in match:
        problems = []
        if not DATE.match(values.get("sunset", "")) or values["sunset"] > opts["today"]:
            problems.append("sunset date missing or not yet passed")
        if not values.get("no-caller-evidence"):
            problems.append("no-caller-evidence missing")
        if not values.get("approved-by") or not DATE.match(values.get("approved-on", "")):
            problems.append("approved-by or approved-on missing")
        if problems:
            failed = True
            print(f"FAIL: retirement record for {label} is incomplete ({'; '.join(problems)}): {line}")
        else:
            print(f"RETIRED with sign-off: {line}")

print(f"removed endpoints: {len(removed)}")
print("RESULT: FAIL" if failed else "RESULT: PASS (shape only: a change of meaning, unit or behaviour is not detected)")
sys.exit(1 if failed else 0)
PY
