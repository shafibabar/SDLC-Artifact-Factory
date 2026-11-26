#!/bin/bash
# check-go-branch-coverage.sh [--tags <tags>] [--exclusions <file>] [<module-dir>]
#
# Branch gate: runs gobco v1.3.4 -branch once per package of the module and
# requires both outcomes of every condition it measures. gobco itself has no
# threshold and exits 0 when coverage is incomplete.
# Needs `go` and `gobco` on PATH (GOBCO=<path> overrides the gobco binary).
# Left out: files ending _moq.go, files with the generated-code marker, and
# approved entries of --exclusions: <path> | approved YYYY-MM-DD | <reason>
# Not measured by gobco: select; range loops, including zero iterations; boolean
# expressions outside if/for conditions and switch cases; functions without
# conditions. Each package counts only its own tests.
# Do not add -race: gobco's counters are unsynchronised.
# Exit 0 = all measured outcomes seen; 1 = a gap; 2 = no result for at least
# one package: nothing to waive.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, json, os, re, shutil, subprocess, sys, tempfile

PINNED = "1.3.4"

def die(message):
    print(f"NO RESULT: {message}")
    sys.exit(2)

args, opts, root = sys.argv[1:], {"--tags": "", "--exclusions": ""}, None
while args:
    arg = args.pop(0)
    if arg in opts:
        if not args:
            die(f"{arg} needs a value")
        opts[arg] = args.pop(0)
    elif arg.startswith("-") or root is not None:
        die(f"unknown argument: {arg} (usage: [--tags t] [--exclusions f] [module-dir])")
    else:
        root = arg
root = os.path.realpath(root or ".")
if not os.path.isfile(os.path.join(root, "go.mod")):
    die(f"no go.mod in {root}")

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

gobco = shutil.which(os.environ.get("GOBCO") or "gobco")
if not gobco:
    die("gobco is not installed: go install github.com/rillig/gobco@v" + PINNED)
version = subprocess.run([gobco, "-version"], capture_output=True, text=True).stdout.strip()
if version != PINNED:
    die(f"gobco version is '{version}', the pinned version is {PINNED}")

tags = ["-tags", opts["--tags"]] if opts["--tags"] else []
fields = '{{.Dir}}|{{join .GoFiles ","}},{{join .CgoFiles ","}}|{{join .IgnoredGoFiles ","}}'
try:
    listed = subprocess.run(["go", "list", *tags, "-f", fields, "./..."],
                            cwd=root, capture_output=True, text=True)
except FileNotFoundError:
    die("go is not installed or not on PATH")
if listed.returncode or not listed.stdout.strip():
    die("go list failed or found no packages: " + listed.stderr.strip())

def head_of(text):
    return re.split(r"^package\s", text, maxsplit=1, flags=re.M)[0]

def has_condition(text):
    """True when the source holds a construct gobco should have counted."""
    code = re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|`[^`]*`',
                  " ", text, flags=re.S)
    if re.search(r"\bif\b", code) or (re.search(r"\bswitch\b", code) and re.search(r"\bcase\b", code)):
        return True
    for header in re.findall(r"\bfor\b([^{\n]*)\{", code):
        if re.search(r"\brange\b", header):
            continue
        parts = header.split(";")
        if (parts[1] if len(parts) == 3 else header).strip():
            return True
    return False

covered = total = 0
gaps, broken = [], []
work = tempfile.TemporaryDirectory()
for number, row in enumerate(listed.stdout.strip().splitlines()):
    directory, built, ignored = row.split("|")
    rel_dir = os.path.relpath(os.path.realpath(directory), root)
    label = "." if rel_dir == "." else "./" + rel_dir
    sources = {}
    for name in filter(None, (built + "," + ignored).split(",")):
        if name.endswith("_test.go"):
            continue
        rel = os.path.normpath(os.path.join(rel_dir, name))
        text = open(os.path.join(directory, name), encoding="utf-8", errors="replace").read()
        if rel in approved:
            print(f"excluded {rel}: approved: {approved[rel]}")
        elif name.endswith("_moq.go"):
            print(f"excluded {rel}: generated mock (by name)")
        elif re.search(r"^// Code generated .* DO NOT EDIT\.\r?$", head_of(text), re.M):
            print(f"excluded {rel}: generated marker")
        elif name in ignored.split(","):
            if not re.search(r"^//go:build ignore\b", head_of(text), re.M):
                broken.append(f"{rel}: left out of this build by constraints, so unmeasured")
        else:
            sources[name] = (rel, text)
    if not sources:
        continue
    stats = os.path.join(work.name, f"stats-{number}.json")  # fresh: gobco adds to an old file
    extra = [f"-test=-tags={opts['--tags']}"] if opts["--tags"] else []
    run = subprocess.run([gobco, "-branch", "-stats", stats, *extra, label],
                         cwd=root, capture_output=True, text=True)
    output = run.stdout + run.stderr
    if run.returncode or "Branch coverage:" not in run.stdout:
        reason = [l for l in output.splitlines() if re.match(r"(panic:|# |go test |--- FAIL)", l)
                  or "invalid" in l or "nothing to instrument" in l or "DATA RACE" in l]
        broken.append(f"{label}: gobco gave no result (exit {run.returncode}): "
                      + ("; ".join(reason[:4]) or output.strip()[-300:]))
        continue
    try:
        conditions = json.load(open(stats, encoding="utf-8")) or []
        rows = [(os.path.basename(c["Start"].rsplit(":", 2)[0]), c["Start"].rsplit(":", 2)[1:],
                 c["Code"], int(c["TrueCount"]), int(c["FalseCount"])) for c in conditions]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        broken.append(f"{label}: unreadable gobco statistics: {exc}")
        continue
    for name, (rel, text) in sorted(sources.items()):
        mine = [r for r in rows if r[0] == name]
        if not mine and has_condition(text):
            broken.append(f"{rel}: has conditions but gobco measured none (a custom build tag does this)")
        for _, position, code, true, false in mine:
            total += 2
            covered += (true > 0) + (false > 0)
            missing = [word for word, count in (("true", true), ("false", false)) if not count]
            if missing:
                what = "never evaluated" if len(missing) == 2 else "never " + missing[0]
                gaps.append(f"  {rel}:{':'.join(position)}: '{code}' {what}")

for line in gaps:
    print(line)
print(f"Branch coverage (gobco {PINNED}): {covered}/{total} outcomes")
print("Not measured: select; range loops, including zero iterations; boolean expressions outside "
      "if/for conditions and switch cases; functions without conditions.")
if broken:
    for line in broken:
        print("NO RESULT " + line)
    print("NO RESULT: the branch figure is incomplete, so there is nothing to waive. "
          "Take it to the product owner; do not fall back to statement coverage only.")
    sys.exit(2)
if gaps:
    print("FAIL: the gate is 100% of measured branches. "
          + ("Above 90%: the product owner may waive this result after review."
             if covered * 10 > total * 9 else "90% or below: no waiver."))
    sys.exit(1)
print("PASS: every measured outcome was seen" if total else
      "PASS: no package holds a condition (0/0 checked against the source)")
PY
