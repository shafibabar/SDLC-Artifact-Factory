#!/bin/bash
# validate-go-integration-tests.sh <file-or-directory>...
# Text-pattern checks on Go integration test code: *_test.go files and the
# harness (.go files under an internal/test/ folder). vendor/, testdata/ and
# .git are skipped. It needs neither Go nor Docker and runs nothing: it finds
# known mistakes, it does not prove a test is good. A clean result on a
# directory that holds no integration test says only that nothing matched; the
# count of *_integration_test.go files is printed.
# SHIPPED applies to the other .go files given: code that is not a test and not
# in internal/test/ must not import it, and nothing in it may be package main
# (the folder is left out of coverage as test support). The coverage gates of
# go-unit-test check the same for the whole module.
# Exit 0 = no FAIL (WARNs need judgement), 1 = at least one FAIL,
# 2 = usage error, missing path or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-go-integration-tests.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import os, re, sys

found = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        found.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in {".git", "vendor", "testdata", "node_modules"})
            found += [os.path.join(base, n) for n in sorted(names)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)

def in_scope(path):
    full = os.path.abspath(path).replace(os.sep, "/")
    return full.endswith("_test.go") or (full.endswith(".go") and "/internal/test/" in full)

files = [f for f in found if in_scope(f)]
others = [f for f in found if f.endswith(".go") and not in_scope(f)]

def imports_support(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    code = re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|`[^`]*`',
                  lambda m: " " if m.group(0).startswith("/") else m.group(0), text, flags=re.S)
    clauses = re.findall(r'^\s*import\b\s*(\([^)]*\)|[^\n]*)', code, re.M)
    for clause in clauses:
        found_at = re.search(r'["`][^"`\n]*/internal/test(/[^"`\n]*)?["`]', clause)
        if found_at:
            return code[:code.find(found_at.group(0))].count("\n") + 1
    return 0

shipped = [(f, line, "non-test code imports internal/test; test support must not ship")
           for f in others for line in [imports_support(f)] if line]
shipped += [(f, 1, "package main under internal/test can be built and shipped")
            for f in files if not f.endswith("_test.go")
            and re.search(r"^package\s+main\b", open(f, encoding="utf-8", errors="replace").read(), re.M)]
if not files and not shipped:
    print("ERROR: no *_test.go or internal/test/*.go files; nothing was checked")
    sys.exit(2)

TOKEN = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|`[^`]*`', re.S)

def newlines(text):
    return "\n" * text.count("\n")

def no_comments(match):
    text = match.group(0)
    return newlines(text) if text.startswith("/") else text

def no_strings(match):
    text = match.group(0)
    return newlines(text) if text.startswith("/") else '""' + newlines(text)

fails = warns = 0
def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")

def block(code, start):
    """The text of the {...} block opening at or after start."""
    opening = code.find("{", start)
    depth = 0
    for index in range(opening, len(code)):
        depth += {"{": 1, "}": -1}.get(code[index], 0)
        if depth == 0:
            return code[opening:index + 1]
    return code[opening:]

# Checked on code with comments removed and strings kept: (level, rule, pattern, message)
WITH_STRINGS = [
    ("FAIL", "DBURL", r'\bos\.(Getenv|LookupEnv)\(\s*"[A-Z0-9_]*(DATABASE_URL|DB_URL|DB_DSN|POSTGRES_URL|BROKERS?)[A-Z0-9_]*"',
     "address read from the environment; use only the container this run started"),
    ("FAIL", "FAKEDB", r'"(github\.com/DATA-DOG/go-sqlmock|github\.com/pashagolub/pgxmock[^"]*|modernc\.org/sqlite|github\.com/mattn/go-sqlite3|github\.com/alicebob/miniredis[^"]*)"',
     "a mock or substitute engine in place of the real dependency"),
    ("FAIL", "RESET", r'(?i)["`]\s*(TRUNCATE\s|DROP\s+SCHEMA\s)|["`]\s*DELETE\s+FROM\s+[\w."]+\s*;?\s*["`]',
     "resets a shared table; roll back, or delete only this test's rows"),
    ("FAIL", "IMAGE", r'"[\w./-]*(postgres|redpanda|mongo|redis):latest[\w.-]*"|\.Run\(\s*\w+\s*,\s*"[\w./-]*(postgres|redpanda|mongo|redis)"',
     "unpinned image; give an exact version tag"),
    ("WARN", "FIXEDPORT", r'(localhost|127\.0\.0\.1):(5432|9092|27017|6379)\b|\b(5432:5432|9092:9092)\b',
     "fixed port; ask the container for its mapped address"),
]
# Checked on code with comments and strings removed.
BARE = [
    ("FAIL", "SLEEP", r"\btime\.Sleep\(", "sleeping; poll for the effect with a deadline"),
    ("FAIL", "DOCKERSKIP", r"\bSkipIfProviderIsNotHealthy\(", "skips when Docker is missing; the run must fail"),
    ("FAIL", "CLEANERR", r"^\s*_\s*(,\s*_\s*)?=\s*[\w.]+\.(Exec|DeleteTopic\w*)\(", "cleanup error ignored; report it on the test"),
]

for path, line, message in shipped:
    report("FAIL", "SHIPPED", path, line, message)
integration = 0
for path in files:
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)
    kept = TOKEN.sub(no_comments, raw)
    code = TOKEN.sub(no_strings, raw)
    is_integration = path.endswith("_integration_test.go")
    integration += is_integration
    for text, checks in ((kept, WITH_STRINGS), (code, BARE)):
        for level, rule, pattern, message in checks:
            for match in re.finditer(pattern, text, re.M):
                report(level, rule, path, text[:match.start()].count("\n") + 1, message)
    for match in re.finditer(r"\bif\s+(testing\.)?Short\(\)\s*\{", code):
        if "os.Exit(" in block(code, match.start()):
            report("FAIL", "SHORTEXIT", path, code[:match.start()].count("\n") + 1,
                   "-short exits the whole package, unit tests included; skip each integration test")
    if is_integration:
        tag = re.search(r"^//go:build\b", raw, re.M)
        if tag:
            report("FAIL", "BUILDTAG", path, raw[:tag.start()].count("\n") + 1,
                   "build tag on an integration test; it would drop out of make ci and the coverage gates")
        for match in re.finditer(r"^func (Test\w+)\(\w+ \*testing\.T\)", code, re.M):
            body = block(code, match.end())
            if not re.search(r"\bIntegration\(\w+\)|\btesting\.Short\(\)", body):
                report("WARN", "NOSKIP", path, code[:match.start()].count("\n") + 1,
                       f"{match.group(1)} has no -short skip; it would use a container that was not started")

print(f"checked {len(files)} file(s), {integration} of them *_integration_test.go: {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
