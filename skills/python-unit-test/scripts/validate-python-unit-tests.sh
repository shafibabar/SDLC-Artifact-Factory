#!/bin/bash
# validate-python-unit-tests.sh <file-or-directory>...
# Syntax-tree checks on Python test files (test_*.py, *_test.py, conftest.py,
# fakes.py). Give it the unit tests, tests/conftest.py and tests/fakes.py.
# It does not run them and does not prove a test is good: it finds known mistakes.
# Exit 0 = no FAIL (WARNs need judgement), 1 = at least one FAIL,
# 2 = usage error, missing path, unparsable file or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-python-unit-tests.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import ast, os, re, sys

def wanted(name):
    return name.endswith(".py") and (name.startswith("test_") or name.endswith("_test.py")
                                     or name in ("conftest.py", "fakes.py"))

files = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        if wanted(os.path.basename(arg)):
            files.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d[0] != "." and d not in ("__pycache__", "node_modules", "venv"))
            files += [os.path.join(base, n) for n in sorted(names) if wanted(n)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)
if not files:
    print("ERROR: no Python test files; nothing was checked")
    sys.exit(2)

fails = warns = 0
def report(level, rule, path, node, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{getattr(node, 'lineno', 0)}: {message}")

def dotted(node):
    parts = []
    while True:
        if isinstance(node, ast.Attribute):
            parts.append(node.attr)
            node = node.value
        elif isinstance(node, ast.Call):
            node = node.func
        elif isinstance(node, ast.Name):
            parts.append(node.id)
            return ".".join(reversed(parts))
        else:
            return ".".join(reversed(parts))

OWNED = re.compile(r"(^|_|\.)(repo|repos|repository|uow|unit_of_work|store)(_|\.|$)", re.I)
CALLS = re.compile(r"\.(assert_(not_)?(called|awaited)\w*|assert_(any|has)_(call|await)s?|called|call_count|call_args\w*|await_count|await_args\w*|mock_calls)$")
CLOCK = {"datetime.now", "datetime.utcnow", "datetime.today", "date.today", "time.time",
         "datetime.datetime.now", "datetime.datetime.utcnow", "datetime.date.today"}
GLOBAL_RANDOM = re.compile(r"^random\.(random|randint|randrange|choice|choices|shuffle|sample|uniform)$")
REAL = re.compile(r"^(testcontainers|requests|socket|psycopg|psycopg2)(\.|$)")

for path in files:
    try:
        tree = ast.parse(open(path, encoding="utf-8").read(), filename=path)
    except (OSError, SyntaxError, ValueError) as exc:
        print(f"ERROR: cannot parse {path}: {exc}")
        sys.exit(2)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            name = dotted(node.func)
            if name in ("time.sleep", "asyncio.sleep"):
                arg = node.args[0] if node.args else None
                if not (isinstance(arg, ast.Constant) and arg.value == 0):
                    report("FAIL", "SLEEP", path, node, "sleeping in a test; inject the time or the sleeper")
            if name in CLOCK:
                report("WARN", "CLOCK", path, node, "wall clock in a test; pass a fixed time")
            if GLOBAL_RANDOM.match(name):
                report("WARN", "RAND", path, node, "global random source; inject random.Random(seed)")
            if name in ("asyncpg.connect", "asyncpg.create_pool"):
                report("FAIL", "REALIO", path, node, "real database in a unit test; use the fake or an integration test")
            if name.endswith("pytest.raises") and node.args and dotted(node.args[0]) in ("Exception", "BaseException") \
                    and not any(k.arg in ("match", "check") for k in node.keywords):
                report("FAIL", "BROAD", path, node, "pytest.raises(Exception) passes for any error; name the exact type")
            if re.match(r"^self\.assert[A-Z]\w*$", name):
                report("FAIL", "UNITTEST", path, node, "unittest assertion; use a plain assert")
            if name.endswith("parametrize") and not any(k.arg == "ids" for k in node.keywords) and len(node.args) > 1:
                rows = node.args[1]
                if isinstance(rows, (ast.List, ast.Tuple)) and not all(
                        isinstance(r, ast.Call) and dotted(r.func).endswith("param")
                        and any(k.arg == "id" for k in r.keywords) for r in rows.elts):
                    report("WARN", "NOID", path, node, "parametrize rows without ids; name each case")
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            modules = [node.module or ""] if isinstance(node, ast.ImportFrom) else [a.name for a in node.names]
            for module in modules:
                if REAL.match(module):
                    report("FAIL", "REALIO", path, node, f"{module} belongs in an integration test")
        if isinstance(node, ast.Attribute) and CALLS.search("." + node.attr):
            base = dotted(node.value)
            if OWNED.search(base):
                report("FAIL", "OWNEDCALL", path, node,
                       f"call assertion on an owned dependency ({base}.{node.attr}); read the state back")
            elif re.match(r"assert_(not_)?called", node.attr):
                report("WARN", "CALLED", path, node,
                       f"{node.attr} passes for an async method that was never awaited; use the awaited form")
        if isinstance(node, ast.Assert):
            if isinstance(node.test, ast.Tuple) and node.test.elts:
                report("FAIL", "TUPLE", path, node, "assert on a tuple is always true")
            for part in ast.walk(node.test):
                if isinstance(part, ast.Attribute) and part.attr.startswith("_") and not part.attr.startswith("__") \
                        and not (isinstance(part.value, ast.Name) and part.value.id in ("self", "cls")):
                    report("FAIL", "PRIVATE", path, node, f"asserts private state ({part.attr}); assert public behaviour")
        if isinstance(node, ast.ClassDef) and any(dotted(b).endswith("TestCase") for b in node.bases):
            report("FAIL", "UNITTEST", path, node, "unittest.TestCase; use functions and fixtures")
        if isinstance(node, (ast.With, ast.AsyncWith)) and any(
                dotted(i.context_expr).endswith("pytest.raises") for i in node.items):
            if any(isinstance(inner, ast.Assert) for stmt in node.body for inner in ast.walk(stmt)):
                report("FAIL", "DEADASSERT", path, node, "assert inside pytest.raises never runs after the raise")
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test_"):
            checks = False
            for part in ast.walk(node):
                if isinstance(part, ast.Assert):
                    checks = True
                if isinstance(part, ast.Call):
                    called = dotted(part.func)
                    if called in ("pytest.raises", "pytest.warns", "pytest.fail") \
                            or called.split(".")[-1].startswith("assert"):
                        checks = True
            if not checks:
                report("FAIL", "NOASSERT", path, node, f"{node.name} asserts nothing")
    seen = {}
    for scope in [tree] + [n for n in tree.body if isinstance(n, ast.ClassDef)]:
        names = {}
        for node in scope.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test_"):
                if node.name in names:
                    report("FAIL", "SHADOWED", path, node, f"{node.name} is defined twice; only the last one runs")
                names[node.name] = node

print(f"checked {len(files)} file(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
