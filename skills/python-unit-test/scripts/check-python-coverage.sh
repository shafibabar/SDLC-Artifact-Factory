#!/bin/bash
# check-python-coverage.sh [--source <dir>]... [--exclusions <file>]
#                          [--skip-suite e2e|chaos|performance|load]...
#                          [--python <exe>] [--out <file>] [<project-dir>]
#
# Line and branch gate for the full run. In <project-dir> it runs:
#   <python> -m pytest tests -o addopts= --cov=<dir> --cov-branch
#       --cov-config=<its own file> --cov-report=json:<tmp> --junitxml=<tmp>
# The product's coverage settings are not read, and addopts and PYTEST_ADDOPTS
# are cleared, so nothing there can narrow the run or hide code. The report is
# written fresh. --source defaults to src. --out keeps a copy of the report.
#
# Left out: files whose leading comments carry a generated-code marker
# ("@generated", or "generated" with "DO NOT EDIT"), and approved entries of
# --exclusions, one per line:
#   <path> | file | approved YYYY-MM-DD | <reason>
#   <path> | lines <fingerprint> | approved YYYY-MM-DD | <reason>
# "file" leaves a whole file out. "lines" accepts the lines coverage.py leaves
# out of one file ("# pragma: no cover", "..." bodies, "if TYPE_CHECKING:",
# "# pragma: no branch"); the fingerprint changes when those lines change.
#
# Any non-zero exit blocks the build.
# Exit 0 = every line and branch ran; 1 = a gap; 2 = no result (usage, failed
# or deselected tests, no tests, no report, unmeasured file, unapproved
# exclusion): nothing to waive.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, hashlib, json, os, re, shutil, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

def die(message):
    print(f"NO RESULT: {message}")
    print("This blocks the build: change the code or tests so it can be measured, or list an "
          "exception for the product owner's approval.")
    sys.exit(2)

SKIPPABLE = ("e2e", "chaos", "performance", "load")
args = sys.argv[1:]
sources, skips, opts, root = [], [], {"--exclusions": "", "--out": "", "--python": "python3"}, None
while args:
    arg = args.pop(0)
    if arg in opts or arg in ("--source", "--skip-suite"):
        if not args:
            die(f"{arg} needs a value")
        value = args.pop(0)
        if arg == "--source":
            sources.append(value)
        elif arg == "--skip-suite":
            if value not in SKIPPABLE:
                die(f"--skip-suite accepts only {', '.join(SKIPPABLE)}; a run without unit, "
                    "integration or contract tests gives no coverage verdict")
            skips.append(value)
        else:
            opts[arg] = value
    elif arg.startswith("-") or root is not None:
        die(f"unknown argument: {arg} (test selection is not accepted: a partial run gives no verdict)")
    else:
        root = arg
root = os.path.realpath(root or ".")
sources = sources or ["src"]
tests = os.path.join(root, "tests")
if not os.path.isdir(tests):
    die(f"no tests folder in {root}")
source_dirs = []
for source in sources:
    path = os.path.realpath(os.path.join(root, source))
    if not os.path.isdir(path) or not path.startswith(root + os.sep):
        die(f"--source must be a folder inside the project: {source}")
    source_dirs.append(path)

approved_files, approved_lines = {}, {}
if opts["--exclusions"]:
    try:
        lines = open(opts["--exclusions"], encoding="utf-8").read().splitlines()
    except OSError as exc:
        die(f"cannot read exclusions: {exc}")
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|", 3)]
        ok = len(parts) == 4 and parts[0] and parts[3]
        kind = re.fullmatch(r"file|lines ([0-9a-f]{12})", parts[1]) if ok else None
        date = re.fullmatch(r"approved (\d{4}-\d{2}-\d{2})", parts[2]) if ok else None
        try:
            datetime.date.fromisoformat(date.group(1) if date else "")
        except ValueError:
            kind = None
        if not kind:
            die("exclusion not approved or malformed (path | file or lines <fingerprint> | "
                f"approved YYYY-MM-DD | reason): {line}")
        name = os.path.normpath(parts[0])
        if kind.group(1):
            approved_lines[(name, kind.group(1))] = parts[3]
        else:
            approved_files[name] = parts[3]

with tempfile.TemporaryDirectory() as tmp:
    config = os.path.join(tmp, "coveragerc")
    with open(config, "w", encoding="utf-8") as handle:
        handle.write("[run]\nbranch = True\ndata_file = %s\n[report]\ninclude_namespace_packages = True\n"
                     % os.path.join(tmp, "data").replace("%", "%%"))
    report_path, junit_path = os.path.join(tmp, "coverage.json"), os.path.join(tmp, "junit.xml")
    command = [opts["--python"], "-m", "pytest", "tests", "-o", "addopts=", "--cov-branch",
               f"--cov-config={config}", "--cov-report=", f"--cov-report=json:{report_path}",
               f"--junitxml={junit_path}"]
    command += [f"--cov={d}" for d in source_dirs]
    command += [f"--ignore=tests/{name}" for name in skips]
    env = {k: v for k, v in os.environ.items() if k != "PYTEST_ADDOPTS"}
    try:
        run = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, errors="replace")
    except OSError as exc:
        die(f"cannot run {opts['--python']}: {exc}")
    print(run.stdout, end="")
    print(run.stderr, end="")
    if run.returncode == 5:
        die("pytest collected no tests (exit 5)")
    if run.returncode:
        die(f"pytest exited {run.returncode}; a failed run gives no coverage result "
            "(exit 4 can mean pytest-cov is not installed)")
    deselected = re.search(r"\b(\d+) deselected\b", run.stdout)
    if deselected:
        die(f"{deselected.group(1)} test(s) deselected; a partial run gives no coverage verdict")
    try:
        report = json.load(open(report_path, encoding="utf-8"))
        suite = ET.parse(junit_path).getroot()
    except (OSError, ValueError, ET.ParseError) as exc:
        die(f"missing or unreadable report: {exc}")
    skipped = sum(int(s.get("skipped", 0)) for s in suite.iter("testsuite"))
    ran = sum(int(s.get("tests", 0)) for s in suite.iter("testsuite")) - skipped
    if ran <= 0:
        die("no test ran (all skipped or none collected)")
    if opts["--out"]:
        try:
            shutil.copyfile(report_path, opts["--out"])
        except OSError as exc:
            die(f"cannot write report: {exc}")

if report.get("meta", {}).get("branch_coverage") is not True:
    die("the report has no branch data")
measured = {os.path.realpath(os.path.join(root, k)): v for k, v in report.get("files", {}).items()}

def generated(text):
    head = []
    for line in text.splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            break
        head.append(line)
    return any("@generated" in l or (re.search(r"(?i)generated", l) and "DO NOT EDIT" in l) for l in head)

totals = {"statements": [0, 0], "branches": [0, 0]}   # covered, total
gaps, left_out, unmeasured, unapproved = [], [], [], []
paths = sorted({os.path.join(base, name) for source in source_dirs
                for base, _, names in os.walk(source) for name in names if name.endswith(".py")})
for path in paths:
    rel = os.path.relpath(path, root)
    if rel in approved_files:
        left_out.append(f"{rel}: approved file: {approved_files[rel]}")
        continue
    text = open(path, encoding="utf-8", errors="replace").read()
    if generated(text):
        left_out.append(f"{rel}: generated-code marker")
        continue
    entry = measured.get(os.path.realpath(path))
    if entry is None:
        unmeasured.append(rel)
        continue
    source_lines = text.split("\n")
    hidden = set(entry.get("excluded_lines", []))
    hidden |= {n for n, l in enumerate(source_lines, 1) if re.search(r"#.*pragma[:\s]*no\s*branch", l, re.I)}
    if hidden:
        content = "\n".join(source_lines[n - 1].strip() for n in sorted(hidden))
        mark = hashlib.sha256(content.encode()).hexdigest()[:12]
        shown = ", ".join(str(n) for n in sorted(hidden))
        if (rel, mark) in approved_lines:
            left_out.append(f"{rel}: approved lines {shown}: {approved_lines[(rel, mark)]}")
        else:
            unapproved.append(f"{rel} lines {shown}; entry to propose: {rel} | lines {mark} | pending | <reason>")
    summary = entry["summary"]
    for key, count, missing in (("statements", "num_statements", "missing_lines"),
                                ("branches", "num_branches", "missing_branches")):
        totals[key][0] += summary[count] - summary[missing]
        totals[key][1] += summary[count]
    if entry.get("missing_lines"):
        gaps.append(f"  {rel}: line(s) not run: {', '.join(map(str, entry['missing_lines']))}")
    for start, end in entry.get("missing_branches", []):
        target = f"line {end}" if end > 0 else "the exit"
        gaps.append(f"  {rel}: branch from line {start} to {target} not taken")

for item in left_out:
    print(f"excluded {item}")
print(f"tests: {ran} ran, {skipped} skipped or expected to fail (they prove nothing)"
      + (f"; suites not run: {', '.join(skips)}" if skips else ""))
for item in gaps:
    print(item)
(sc, st), (bc, bt) = totals["statements"], totals["branches"]
print(f"Line coverage: {sc}/{st} statements")
print(f"Branch coverage: {bc}/{bt} branches")
if unmeasured:
    die("product files the run did not measure: " + ", ".join(unmeasured)
        + ". The counts above are not a verdict.")
if unapproved:
    for item in unapproved:
        print(f"unapproved exclusion: {item}")
    die("lines are left out without the product owner's approval. The counts above are not a verdict.")
if st == 0:
    die("no statements left to measure")
failed = False
for name, covered, total in (("line", sc, st), ("branch", bc, bt)):
    if covered < total:
        failed = True
        waivable = covered * 10 > total * 9
        print(f"FAIL ({name}): the gate is 100%. "
              + ("Above 90%: the product owner may waive this result after review."
                 if waivable else "90% or below: no waiver."))
if failed:
    sys.exit(1)
print("PASS: every measured line and branch ran"
      + (f". NOT measured, by approved exception: {', '.join(sorted(approved_files))}" if approved_files else ""))
PY
