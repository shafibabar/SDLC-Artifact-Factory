#!/bin/bash
# check-go-line-coverage.sh [--tags <tags>] [--exclusions <file>]
#                           [--out <file>] [<module-dir>]
#
# Statement-block gate: every block in the Go coverage profile must have run.
# It runs, in <module-dir>:
#   go test -count=1 -race -covermode=atomic -coverpkg=./... -coverprofile=<tmp> ./...
# --out keeps a copy of that profile. A production file the build leaves out
# (build constraints) is unmeasured, so there is no result.
# Left out: files ending _moq.go (by name), files with the generated-code marker
# before the package clause, and approved entries of --exclusions, one per line:
#   <module-relative path> | approved YYYY-MM-DD | <reason>
# Any non-zero exit blocks the build.
# Exit 0 = every block ran; 1 = at least one did not; 2 = no result (usage,
# failed tests, unreadable or empty profile, unmeasured files): nothing to waive.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, os, re, shutil, subprocess, sys, tempfile

def die(message):
    print(f"NO RESULT: {message}")
    print("This blocks the build: change the code so it can be measured, or list an exception "
          "for the product owner's approval.")
    sys.exit(2)

args, opts, root = sys.argv[1:], {"--tags": "", "--exclusions": "", "--out": ""}, None
while args:
    arg = args.pop(0)
    if arg in opts:
        if not args:
            die(f"{arg} needs a value")
        opts[arg] = args.pop(0)
    elif arg.startswith("-") or root is not None:
        die(f"unknown argument: {arg} (usage: [--tags t] [--exclusions f] [--out f] [module-dir])")
    else:
        root = arg
root = os.path.realpath(root or ".")
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

def unbuilt(root, built):
    """Production files of this module that the build left out: nothing measures them."""
    missing = []
    for base, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ("vendor", "testdata") and d[0] not in "._"
                         and not os.path.isfile(os.path.join(base, d, "go.mod")))
        for name in sorted(names):
            path = os.path.join(base, name)
            rel = os.path.relpath(path, root)
            if (not name.endswith(".go") or name.endswith(("_test.go", "_moq.go")) or name[0] in "._"
                    or path in built or rel in approved):
                continue
            head = re.split(r"^package\s", open(path, encoding="utf-8", errors="replace").read(),
                            maxsplit=1, flags=re.M)[0]
            if not re.search(r"^//go:build ignore\b|^// Code generated .* DO NOT EDIT\.\r?$", head, re.M):
                missing.append(rel)
    return missing

tmp = tempfile.TemporaryDirectory()
profile = os.path.join(tmp.name, "cover.out")
tags = ["-tags", opts["--tags"]] if opts["--tags"] else []
try:
    listed = subprocess.run(["go", "list", *tags, "-f",
        "{{$d := .Dir}}{{range .GoFiles}}{{$d}}/{{.}}\n{{end}}{{range .CgoFiles}}{{$d}}/{{.}}\n{{end}}", "./..."],
        cwd=root, capture_output=True, text=True)
    if listed.returncode:
        die("go list failed: " + listed.stderr.strip())
    unmeasured = unbuilt(root, {os.path.realpath(p) for p in listed.stdout.splitlines() if p})
    if unmeasured:
        die("production files left out of this build by constraints, so unmeasured: "
            + ", ".join(unmeasured))
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
print("PASS: every measured statement block ran (statement blocks only; branches are a separate gate)"
      + (f". NOT measured, by approved exception: {', '.join(sorted(approved))}" if approved else ""))
PY
