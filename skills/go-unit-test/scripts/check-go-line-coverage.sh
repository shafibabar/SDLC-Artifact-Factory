#!/bin/bash
# check-go-line-coverage.sh [--tags <tags>] [--exclusions <file>]
#                           [--profile <file> | --out <file>] [<module-dir>]
#
# Statement-block gate: every block in the Go coverage profile must have run.
# Without --profile it runs, in <module-dir>:
#   go test -count=1 -race -covermode=atomic -coverpkg=./... -coverprofile=<tmp> ./...
# --out keeps a copy of that profile. --profile reads an existing one instead
# (it then cannot see files that build constraints left out).
# Left out: files ending _moq.go (by name), files with the generated-code marker
# before the package clause, and approved entries of --exclusions, one per line:
#   <module-relative path> | approved YYYY-MM-DD | <reason>
# Exit 0 = every block ran; 1 = at least one did not; 2 = no result (usage,
# failed tests, unreadable or empty profile, unmeasured files): nothing to waive.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, os, re, shutil, subprocess, sys, tempfile

def die(message):
    print(f"NO RESULT: {message}")
    sys.exit(2)

args, opts, root = sys.argv[1:], {"--tags": "", "--exclusions": "", "--profile": "", "--out": ""}, None
while args:
    arg = args.pop(0)
    if arg in opts:
        if not args:
            die(f"{arg} needs a value")
        opts[arg] = args.pop(0)
    elif arg.startswith("-") or root is not None:
        die(f"unknown argument: {arg} (usage: [--tags t] [--exclusions f] [--profile f | --out f] [module-dir])")
    else:
        root = arg
root = os.path.abspath(root or ".")
gomod = os.path.join(root, "go.mod")
if not os.path.isfile(gomod):
    die(f"no go.mod in {root}")
found = re.search(r"^module\s+\"?([^\s\"]+)", open(gomod, encoding="utf-8").read(), re.M)
if not found:
    die("go.mod has no module line")
module = found.group(1)

approved = {}
if opts["--exclusions"]:
    try:
        lines = open(opts["--exclusions"], encoding="utf-8").read().splitlines()
    except OSError as exc:
        die(f"cannot read exclusions: {exc}")
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        date = re.fullmatch(r"approved (\d{4}-\d{2}-\d{2})", parts[1]) if len(parts) == 3 else None
        try:
            datetime.date.fromisoformat(date.group(1) if date else "")
        except ValueError:
            die(f"exclusion not approved or malformed (path | approved YYYY-MM-DD | reason): {line}")
        if not parts[0] or not parts[2]:
            die(f"exclusion needs a path and a reason: {line}")
        approved[os.path.normpath(parts[0])] = parts[2]

if opts["--profile"] and opts["--out"]:
    die("--out keeps the profile of a live run; it cannot be used with --profile")
profile = opts["--profile"]
tmp = None
if not profile:
    tmp = tempfile.TemporaryDirectory()
    profile = os.path.join(tmp.name, "cover.out")
    tags = ["-tags", opts["--tags"]] if opts["--tags"] else []
    try:
        listed = subprocess.run(["go", "list", *tags, "-f",
            "{{$d := .Dir}}{{range .IgnoredGoFiles}}{{$d}}/{{.}}\n{{end}}", "./..."],
            cwd=root, capture_output=True, text=True)
        if listed.returncode:
            die("go list failed: " + listed.stderr.strip())
        unmeasured = []
        for path in filter(None, listed.stdout.splitlines()):
            rel = os.path.relpath(path, root)
            if rel.endswith("_test.go") or rel in approved:
                continue
            head = open(path, encoding="utf-8", errors="replace").read().split("\npackage ")[0]
            if not re.search(r"^//go:build ignore\b", head, re.M):
                unmeasured.append(rel)
        if unmeasured:
            die("production files left out of this build by constraints, so unmeasured: "
                + ", ".join(sorted(unmeasured)))
        run = subprocess.run(["go", "test", *tags, "-count=1", "-race", "-covermode=atomic",
            "-coverpkg=./...", f"-coverprofile={profile}", "./..."], cwd=root)
    except FileNotFoundError:
        die("go is not installed or not on PATH")
    sys.stdout.flush()
    if run.returncode:
        die("go test failed; a failed run gives no coverage result")
    if opts["--out"]:
        try:
            shutil.copyfile(profile, opts["--out"])
        except OSError as exc:
            die(f"cannot write profile: {exc}")

try:
    lines = open(profile, encoding="utf-8").read().splitlines()
except OSError as exc:
    die(f"cannot read profile: {exc}")
if not lines or not lines[0].startswith("mode: "):
    die("empty profile or missing 'mode:' line")
blocks = {}
for line in lines[1:]:
    m = re.fullmatch(r"(.+):(\d+\.\d+,\d+\.\d+) (\d+) (\d+)", line)
    if not m:
        die(f"malformed profile line: {line}")
    key = (m.group(1), m.group(2))
    _, count = blocks.get(key, (0, 0))
    # One block appears once per test binary: add the counts.
    blocks[key] = (int(m.group(3)), count + int(m.group(4)))

def excluded(name):
    if not name.startswith(module + "/"):
        die(f"profile file outside module {module}: {name}")
    rel = os.path.normpath(name[len(module) + 1:])
    if rel in approved:
        return rel, "approved: " + approved[rel]
    if rel.endswith("_moq.go"):
        return rel, "generated mock (by name)"
    try:
        text = open(os.path.join(root, rel), encoding="utf-8", errors="replace").read()
    except OSError:
        die(f"profile names a file that is not on disk (stale profile?): {rel}")
    head = re.split(r"^package\s", text, maxsplit=1, flags=re.M)[0]
    if re.search(r"^// Code generated .* DO NOT EDIT\.\r?$", head, re.M):
        return rel, "generated marker"
    return rel, None

seen, total, covered, gaps = {}, 0, 0, []
for (name, span), (statements, count) in sorted(blocks.items()):
    if name not in seen:
        seen[name] = excluded(name)
    rel, why = seen[name]
    if why:
        continue
    total += statements
    if count:
        covered += statements
    else:
        gaps.append(f"  {rel}:{span} ({statements} statement(s)) did not run")
for rel, why in sorted(v for v in seen.values() if v[1]):
    print(f"excluded {rel}: {why}")
if total == 0:
    die("no statements left to measure")
print("\n".join(gaps)) if gaps else None
print(f"Statement coverage: {covered}/{total} statements, {len(gaps)} block(s) not run")
if gaps:
    waivable = covered * 10 > total * 9
    print("FAIL: the gate is 100% of statement blocks. "
          + ("Above 90%: the product owner may waive this result after review."
             if waivable else "90% or below: no waiver."))
    sys.exit(1)
print("PASS: every statement block ran (statement blocks only; branches are a separate gate)")
PY
