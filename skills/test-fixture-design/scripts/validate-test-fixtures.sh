#!/bin/bash
# validate-test-fixtures.sh <file-or-directory>...
# Text-pattern checks on Go and Python test code. Directories are filtered to
# test and fixture files; a file named directly is always checked.
# Exit 0 = no FAIL (WARNs need judgement), 1 = at least one FAIL,
# 2 = usage error, missing path or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-test-fixtures.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import os, re, sys

SKIP = {".git", ".venv", "venv", "node_modules", "vendor", "__pycache__", "testdata"}

def is_test_file(path):
    name = os.path.basename(path)
    parts = path.replace("\\", "/").split("/")
    if name.endswith(".go"):
        return name.endswith("_test.go") or "internal/test/" in "/".join(parts)
    if name.endswith(".py"):
        return (name == "conftest.py" or name.startswith("test_")
                or name.endswith("_test.py") or "tests" in parts[:-1])
    return False

files = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        files.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in SKIP)
            files += [p for p in (os.path.join(base, n) for n in sorted(names)) if is_test_file(p)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)
if not files:
    print("ERROR: no test or fixture files found; nothing was checked")
    sys.exit(2)

# (level, rule, language or None, pattern, message)
CHECKS = [
    ("FAIL", "F5", None, r"(?i)\bTRUNCATE\s+(TABLE\s+)?[\w\"{%$]|\bDROP\s+(SCHEMA|DATABASE|TABLE)\b",
     "resets shared tables; roll back, or delete only this test's rows"),
    ("FAIL", "F5", None, r"(?i)\bDELETE\s+FROM\s+[\w.\"]+\s*;?\s*[\"'`]",
     "unfiltered DELETE removes other tests' rows"),
    ("FAIL", "F4", "go", r"(^|[{;]|\bdefer\b)\s*_\s*(,\s*_\s*)?=\s*[\w.]+\.(Exec|Rollback|Terminate)\(",
     "cleanup or write error discarded; report it"),
    ("FAIL", "F4", "py", r"suppress\(\s*(Base)?Exception\s*\)|^\s*except(\s+(Base)?Exception)?\s*:\s*pass\b",
     "error swallowed; report it"),
    ("FAIL", "F6", "go", r"\btime\.Now\(\)", "wall clock in test data; inject a fixed time"),
    ("FAIL", "F6", "py", r"\b(datetime\.(now|utcnow|today)|date\.today|time\.time)\(",
     "wall clock in test data; inject a fixed time"),
    ("FAIL", "F6", "go", r"\brand\.(Int|Intn|IntN|Int31n|Int63n|Int64N|Float64|Perm|Shuffle|N)\(",
     "global random generator; inject a seeded one"),
    ("FAIL", "F6", "py", r"\brandom\.(random|randint|randrange|choice|choices|shuffle|sample|uniform)\(|\bRandom\(\s*\)",
     "unseeded randomness; use random.Random(seed)"),
    ("FAIL", "F8", None, r"go\s+test\s+\./\.\.\..*\s-update\b",
     "bulk golden update; update one test in one package and read the diff"),
    ("WARN", "F7", None, r"DATABASE_URL",
     "confirm this is set FROM the throwaway instance, never read as the target"),
]
DEADLINE = re.compile(r"(?i)deadline|timeout|\.Since\(|elapsed|\.Before\(|\.After\(")

fails = warns = 0
def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")

for path in files:
    lang = "go" if path.endswith(".go") else "py" if path.endswith(".py") else None
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)
    helper = False
    previous = ""
    for number, text in enumerate(lines, 1):
        stripped = text.strip()
        if stripped.startswith("//") or (lang == "py" and stripped.startswith("#")):
            continue
        for level, rule, only, pattern, message in CHECKS:
            if only and only != lang:
                continue
            if not re.search(pattern, text):
                continue
            if rule == "F6" and "wall clock" in message and DEADLINE.search(text):
                continue
            report(level, rule, path, number, message)
        if lang == "py" and stripped == "pass" and re.match(r"except(\s+(Base)?Exception(\s+as\s+\w+)?)?\s*:$", previous):
            report("FAIL", "F4", path, number, "error swallowed; report it")
        if lang == "go":
            if text.startswith("func "):
                helper = False
            if "t.Helper()" in text:
                helper = True
            if helper and re.match(r"\tdefer\s", text):
                report("WARN", "F4", path, number,
                       "defer in a helper runs when the helper returns; use t.Cleanup if the test still needs it")
        if stripped:
            previous = stripped

print(f"checked {len(files)} file(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
