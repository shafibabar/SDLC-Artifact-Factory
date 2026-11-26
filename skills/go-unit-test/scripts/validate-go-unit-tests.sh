#!/bin/bash
# validate-go-unit-tests.sh <file-or-directory>...
# Text-pattern checks on Go *_test.go files. vendor/, testdata/ and .git are
# skipped. It does not prove a test is good: it finds known mistakes.
# Exit 0 = no FAIL (WARNs need judgement), 1 = at least one FAIL,
# 2 = usage error, missing path or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-go-unit-tests.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import os, re, sys

files = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        files.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in {".git", "vendor", "testdata", "node_modules"})
            files += [os.path.join(base, n) for n in sorted(names)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)
files = [f for f in files if f.endswith("_test.go")]
if not files:
    print("ERROR: no *_test.go files; nothing was checked")
    sys.exit(2)

# (level, rule, pattern, message)
CHECKS = [
    ("FAIL", "SLEEP", r"\btime\.Sleep\(", "sleeping in a test; inject the time, use testing/synctest or poll"),
    ("FAIL", "BOOL", r"\b(assert|require)\.(True|False)f?\(\s*t\s*,[^,]*(==|!=)(?!\s*nil\b)",
     "comparison collapsed to a boolean; use Equal so both values are printed"),
    ("FAIL", "BARE", r"\bt\.(Fail|FailNow)\(\)", "failure with no message; report the call, got and want"),
    ("FAIL", "ERRTEXT", r"\.Error\(\)\s*(==|!=)|\bstrings\.\w+\(\s*\w*[Ee]rr\w*\.Error\(\)|\b(assert|require)\.(EqualError|ErrorContains)\w*\(",
     "asserting error text; use errors.Is or errors.As"),
    ("WARN", "LOOPCOPY", r"^\s*(\w+)\s*:=\s*(tt|tc|c)\s*$", "loop-variable copy; not needed from Go 1.22"),
    ("WARN", "RAND", r"\brand\.(Int|IntN|Intn|Float64|Perm|Shuffle|N)\(", "global random source; inject a seeded one"),
    ("WARN", "CLOCK", r"\btime\.(Now|Since|Until)\(", "wall clock in a test; pass a fixed time"),
]

fails = warns = 0
def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")

TOKEN = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|`[^`]*`', re.S)
def blank(match):
    text = match.group(0)
    return '""' + "\n" * text.count("\n") if text[0] in "\"'`" else "\n" * text.count("\n")

for path in files:
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)
    code = TOKEN.sub(blank, raw)
    # Inside a testing/synctest bubble the clock is fake: SLEEP and CLOCK do not apply.
    bubbled = set()
    for found in re.finditer(r"^func .*?(?=^func |\Z)", code, re.M | re.S):
        if "synctest.Test(" in found.group(0):
            first = code[:found.start()].count("\n") + 1
            bubbled.update(range(first, first + found.group(0).count("\n") + 1))
    for number, line in enumerate(code.splitlines(), 1):
        for level, rule, pattern, message in CHECKS:
            if rule in ("SLEEP", "CLOCK") and number in bubbled:
                continue
            if re.search(pattern, line):
                report(level, rule, path, number, message)
    # Per top-level test function.
    for found in re.finditer(r"^func (Test\w+|Fuzz\w+)\(.*?(?=^func |\Z)", code, re.M | re.S):
        name, body = found.group(1), found.group(0)
        line = code[:found.start()].count("\n") + 1
        if "t.Parallel()" in body and "t.Setenv(" in body:
            report("WARN", "SETENV", path, line, f"{name} uses t.Setenv and t.Parallel; "
                   "in one test or under a parallel parent this panics")
        if "t.Parallel()" in body and "t.Run(" in body and re.search(r"^\tdefer\b", body, re.M):
            report("WARN", "DEFER", path, line, f"{name}: a defer in the parent runs before its "
                   "parallel subtests; use t.Cleanup")

print(f"checked {len(files)} test file(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
