#!/bin/bash
# validate-python-integration-tests.sh <file-or-directory>...
# Static checks on Python integration test code. In scope: .py files in a
# directory named "integration" below a "tests" directory, and any .py file
# named on the command line that lies below "tests". A pyproject.toml or
# pytest.ini that is named, or sits in a named directory, is checked for
# settings that deselect or retry tests. Other .py files given are SHIPPED code:
# they must not import the "tests" package. Hidden folders, virtualenvs,
# node_modules and build folders are skipped. Needs only python3; imports and
# runs nothing under check. It finds known mistakes and does not prove a test is
# good: a clean result says only that nothing matched.
# Exit 0 = no FAIL (WARNs need judgement), 1 = at least one FAIL,
# 2 = usage error, missing path, unparseable file or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-python-integration-tests.sh <file-or-directory>..." >&2
  exit 2
fi
exec python3 -I - "$@" <<'PY'
import ast, os, re, sys

SKIP_DIRS = {"node_modules", "venv", "build", "dist", "__pycache__", "site-packages"}
SETTINGS = ("pyproject.toml", "pytest.ini")
CONTAINERS = {"PostgresContainer", "RedpandaContainer", "KafkaContainer", "MongoDbContainer",
              "RedisContainer", "DockerContainer"}
ADDRESS = re.compile(r"DATABASE_URL|DB_URL|DB_DSN|POSTGRES_(URL|DSN)|MONGO\w*_URI|BROKERS?\b|BOOTSTRAP")

def die(message):
    print(f"ERROR: {message}")
    sys.exit(2)

named, walked = [], []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        named.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
            walked += [os.path.join(base, n) for n in sorted(names)]
    else:
        die(f"no such path: {arg}")

def folders(path):
    return os.path.abspath(path).replace(os.sep, "/").split("/")[:-1]

def integration_folder(path):
    parts = folders(path)
    return "tests" in parts and "integration" in parts[parts.index("tests") + 1:]

scope, shipped = [], []
for path, explicit in [(p, True) for p in named] + [(p, False) for p in walked]:
    if not path.endswith(".py"):
        continue
    if integration_folder(path) or (explicit and "tests" in folders(path)):
        scope.append(path)
    elif "tests" not in folders(path):
        shipped.append(path)
settings = [p for p in named + walked if os.path.basename(p) in SETTINGS]
scope, shipped = sorted(set(scope)), sorted(set(shipped))

fails = warns = 0
def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")

def parse(path):
    try:
        return ast.parse(open(path, encoding="utf-8").read(), path)
    except (OSError, SyntaxError, ValueError) as exc:
        die(f"cannot read or parse {path}: {exc}")

def dotted(node):
    parts = []
    while isinstance(node, ast.Attribute):
        parts.append(node.attr)
        node = node.value
    if isinstance(node, ast.Name):
        parts.append(node.id)
    return ".".join(reversed(parts))

def text_of(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    return None

def imports(tree):
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                yield node.lineno, alias.name, []
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            yield node.lineno, node.module, [a.name for a in node.names]

for path in shipped:
    for line, module, _ in imports(parse(path)):
        if module == "tests" or module.startswith("tests."):
            report("FAIL", "SHIPPED", path, line, "code outside tests/ imports tests; test support must not ship")

marked_folders = []
for path in scope:
    if os.path.basename(path) == "conftest.py":
        source = open(path, encoding="utf-8", errors="replace").read()
        if re.search(r"add_marker\(\s*pytest\.mark\.integration", source):
            marked_folders.append(os.path.dirname(os.path.abspath(path)) + os.sep)

tests_found = 0
for path in scope:
    tree = parse(path)
    name = os.path.basename(path)
    is_test = name.startswith("test_") or name.endswith("_test.py")
    tests_found += is_test
    support = name in ("conftest.py", "harness.py", "broker.py")

    in_loop, docstrings = set(), set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.While, ast.For, ast.AsyncFor)):
            in_loop.update(id(n) for stmt in node.body for n in ast.walk(stmt))
        if isinstance(node, ast.Expr) and text_of(node.value) is not None:
            docstrings.add(id(node.value))
        if isinstance(node, ast.JoinedStr):
            docstrings.update(id(v) for v in node.values)

    sleep_names = set()
    for line, module, names in imports(tree):
        top = module.split(".")[0]
        if top in ("asyncio", "time") and "sleep" in names:
            sleep_names.add("sleep")
        if top in ("mongomock", "mongomock_motor", "fakeredis"):
            report("FAIL", "FAKEDB", path, line, "a substitute engine in place of the real dependency")
        if top in ("sqlite3", "aiosqlite"):
            report("WARN", "SQLITE", path, line, "allowed only if SQLite is the product's real engine")
        if module.startswith("testcontainers.") and module.split(".")[1] in ("postgres", "kafka", "redpanda", "mongodb"):
            report("WARN", "OLDAPI", path, line, "deprecated import path; use testcontainers.community.<name>")
        if "wait_for_logs" in names:
            report("WARN", "OLDAPI", path, line, "wait_for_logs is deprecated; use the container's wait strategy")
        fakes = {"FakeRepository", "FakeUnitOfWork", "FakeCommandLog"} & set(names)
        if fakes:
            report("WARN", "DOUBLE", path, line, f"{', '.join(sorted(fakes))}: your own database is verified by its real state")
        if "TestClient" in names:
            report("WARN", "TESTCLIENT", path, line, "TestClient runs the app on another event loop; use httpx.AsyncClient with ASGITransport")

    for node in ast.walk(tree):
        line = getattr(node, "lineno", 1)
        if isinstance(node, ast.Subscript) and dotted(node.value) in ("os.environ", "environ") \
                and isinstance(node.ctx, ast.Load) and ADDRESS.search(text_of(node.slice) or ""):
            report("FAIL", "DBURL", path, line, "address read from the environment; use only the container this run started")
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and id(node) not in docstrings:
            value = node.value
        elif isinstance(node, ast.JoinedStr):
            value = "".join(text_of(v) if text_of(v) is not None else "x" for v in node.values)
        else:
            value = None
        if value is not None:
            if re.search(r"(?is)(^|;)\s*(TRUNCATE\s+(TABLE\s+)?[\w.\"]+|DROP\s+SCHEMA\s)", value) \
                    or re.fullmatch(r"(?is)\s*DELETE\s+FROM\s+[\w.\"]+\s*;?\s*", value):
                report("FAIL", "RESET", path, line, "resets a shared table; roll back, or delete only this test's rows")
            if re.fullmatch(r"[\w./-]*(postgres|redpanda|mongo|redis|cp-kafka):latest[\w.-]*", value):
                report("FAIL", "IMAGE", path, line, "unpinned image; give an exact version tag")
            if re.search(r"(localhost|127\.0\.0\.1):(5432|9092|27017|6379)\b", value):
                report("WARN", "FIXEDPORT", path, line, "fixed port; ask the container for its mapped address")
        if isinstance(node, ast.Call):
            called = dotted(node.func)
            last = called.split(".")[-1]
            first = text_of(node.args[0]) if node.args else None
            if called in ("os.getenv", "os.environ.get", "environ.get", "getenv") and ADDRESS.search(first or ""):
                report("FAIL", "DBURL", path, line, "address read from the environment; use only the container this run started")
            if last in CONTAINERS:
                image = node.args[0] if node.args else next((k.value for k in node.keywords if k.arg == "image"), None)
                literal = text_of(image) if image is not None else None
                if image is None or (literal is not None and ":" not in literal.split("/")[-1] and "@" not in literal):
                    report("FAIL", "IMAGE", path, line, "unpinned image; give an exact version tag")
            if (called in ("time.sleep", "asyncio.sleep") or called in sleep_names) and id(node) not in in_loop:
                zero = node.args and isinstance(node.args[0], ast.Constant) and node.args[0].value == 0
                if not zero:
                    report("FAIL", "SLEEP", path, line, "sleeping; poll for the effect with a deadline")
            if called in ("pytest.skip", "pytest.importorskip", "pytest.mark.skipif", "pytest.mark.skip"):
                if support:
                    report("FAIL", "DOCKERSKIP", path, line, "the harness skips; a missing Docker or broker must fail the run")
                else:
                    report("WARN", "SKIP", path, line, "a skipped test proves nothing; never skip because a container is missing")
            if called == "pytest.mark.flaky":
                report("FAIL", "RETRY", path, line, "test retries; no test below end-to-end is retried")
            if last == "suppress" and any(dotted(a) in ("Exception", "BaseException") for a in node.args):
                report("FAIL", "SWALLOW", path, line, "errors suppressed; report cleanup errors on the test")
            if last == "with_bind_ports" and len(node.args) > 1:
                report("WARN", "FIXEDPORT", path, line, "fixed host port; publish a random one")
            if last in ("AsyncMock", "MagicMock", "Mock", "create_autospec"):
                report("WARN", "DOUBLE", path, line, "a double is only for a third party's port, never your database or broker")
        if isinstance(node, ast.ExceptHandler) and all(isinstance(s, ast.Pass) for s in node.body) \
                and (node.type is None or dotted(node.type) in ("Exception", "BaseException")):
            report("FAIL", "SWALLOW", path, line, "errors swallowed; report cleanup errors on the test")

    if is_test and integration_folder(path):
        full = os.path.abspath(path)
        has_mark = any(dotted(n) == "pytest.mark.integration" for n in ast.walk(tree) if isinstance(n, ast.Attribute))
        if not has_mark and not any(full.startswith(f) for f in marked_folders):
            report("WARN", "NOMARK", path, 1, "no integration marker found here or in a checked conftest.py")

for path in settings:
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as exc:
        die(f"cannot read {path}: {exc}")
    for match in re.finditer(r"(?m)^[ \t]*addopts\s*=\s*(\[[^\]]*\]|\"\"\"[\s\S]*?\"\"\"|[^\n]*)", text):
        line = text[:match.start()].count("\n") + 1
        plain = re.sub(r"[\"',\[\]]", " ", match.group(1))
        if re.search(r"-m\s+.*\bnot\b.*\bintegration\b", plain) or re.search(r"--ignore\S*integration", plain):
            report("FAIL", "DESELECT", path, line, "integration tests deselected for every run, including the full check")
        if "--reruns" in plain:
            report("FAIL", "RETRY", path, line, "test retries; no test below end-to-end is retried")

if not scope and not fails:
    die("no integration test code found (tests/**/integration/**/*.py); nothing was checked")
print(f"checked {len(scope)} file(s), {tests_found} of them test files: {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
