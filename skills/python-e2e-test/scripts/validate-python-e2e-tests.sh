#!/bin/bash
# validate-python-e2e-tests.sh <product-root-or-path>...
#
# Text checks on a product's Python end-to-end suite and what runs it: the
# Python files under tests/e2e/, the shell scripts there (and any script that
# creates a kind cluster), the e2e targets of a Makefile, pytest settings in
# pyproject.toml, pytest.ini and setup.cfg, and the workflows that run the
# suite. It needs no pytest, Docker or cluster and runs nothing: it finds the
# known dangerous mistakes, it does not prove a suite is good.
#
# FAIL rules: LAYOUT (a test outside journeys/ and smoke/), SMOKEWRITE (a smoke
# file that can write, or that uses journey code), UPSERT, SLEEP, ENVADDR (an
# address read from the environment), RAWCLIENT (an HTTP client that is not the
# bound one), INPROCESS (the product run inside the test process), KUBECLIENT
# (a Kubernetes client loading the caller's kubeconfig), SKIP,
# QUARANTINEMARK (quarantine by marker), RERUN (a rerun plugin, a rerun loop,
# pytest called without the suite runner), TIMEOUTTHREAD, KUBECONFIG (kind,
# helm or kubectl without the run's kubeconfig; use-context), HELMWAIT,
# TRAPONLY (cluster deleted by an exit trap before the tests run), NOTEARDOWN,
# SWEEP (clusters deleted by pattern or all at once), ENVFILE, CLOUD, COMPOSE,
# PERMISSIONS, PRTRIGGER, RELEASE, CREDENTIALS. WARN rules: NOCRITERION,
# UNPINNED, NOALWAYS.
# Exit 0 = no FAIL (each WARN needs judgement); 1 = at least one FAIL;
# 2 = usage, a missing path, or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-python-e2e-tests.sh <product-root-or-path>..." >&2
  exit 2
fi
exec python3 -I - "$@" << 'PY'
import ast, io, os, re, sys, tokenize

found = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        found.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in {".git", ".venv", "venv", "node_modules", "e2e-evidence", "__pycache__",
                                                          ".mypy_cache", ".pytest_cache", ".ruff_cache"})
            found += [os.path.join(base, n) for n in sorted(names)]
    else:
        print(f"ERROR: no such path: {arg}")
        sys.exit(2)


def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}")
        sys.exit(2)


def norm(path):
    return os.path.abspath(path).replace(os.sep, "/")


fails = warns = 0


def report(level, rule, path, line, message):
    global fails, warns
    fails += level == "FAIL"
    warns += level == "WARN"
    print(f"{level} {rule} {path}:{line}: {message}")


def line_of(text, index):
    return text[:index].count("\n") + 1


# ------------------------------------------------------------ Python files
def split_source(text):
    """Returns (code, strings): the source with comments removed and string
    contents blanked, and the list of (line, text) of every string literal."""
    code_lines = text.splitlines()
    strings, edits = [], []
    try:
        for token in tokenize.generate_tokens(io.StringIO(text).readline):
            if token.type == tokenize.COMMENT:
                edits.append((token.start, token.end, ""))
            elif token.type == tokenize.STRING or token.type == getattr(tokenize, "FSTRING_MIDDLE", -1):
                strings.append((token.start[0], token.string))
                if token.type == tokenize.STRING:
                    edits.append((token.start, token.end, '""'))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return text, [(number, line) for number, line in enumerate(code_lines, 1)]
    for (srow, scol), (erow, ecol), replacement in sorted(edits, reverse=True):
        if srow == erow:
            code_lines[srow - 1] = code_lines[srow - 1][:scol] + replacement + code_lines[srow - 1][ecol:]
        else:
            code_lines[srow - 1] = code_lines[srow - 1][:scol] + replacement
            for row in range(srow, erow - 1):
                code_lines[row] = ""
            code_lines[erow - 1] = code_lines[erow - 1][ecol:]
    return "\n".join(code_lines), strings


SQL_WRITE = re.compile(r"(?i)\b(INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|TRUNCATE|DROP\s+TABLE)\b")
UPSERT = re.compile(r"(?i)\bON\s+CONFLICT\b[^;]*\bDO\s+UPDATE\b|\bINSERT\s+OR\s+REPLACE\b|\bREPLACE\s+INTO\b|\bMERGE\s+INTO\b|\bON\s+DUPLICATE\s+KEY\b")
HTTP_WRITE_CALL = re.compile(r"\.(post|put|patch|delete)\(")
HTTP_WRITE_WORD = re.compile(r"""^[rbuf]*["'](POST|PUT|PATCH|DELETE)["']$""", re.I)
ENV_ADDRESS = re.compile(r"^[rbuf]*[\"']([A-Z0-9_]*(URL|HOST|ADDR|ADDRESS|DSN|ENDPOINT|BOOTSTRAP|BROKERS?)[A-Z0-9_]*)[\"']$")
RAW_CLIENT = re.compile(r"\bhttpx\.(Client|AsyncClient|get|post|put|patch|delete|head|options|request|stream)\(|"
                        r"^\s*(import|from)\s+(requests|aiohttp|urllib3|http\.client)\b|\burllib\.request\b|\burlopen\(", re.M)
INPROCESS = re.compile(r"\b(ASGITransport|WSGITransport|TestClient)\(|^\s*from\s+(fastapi|starlette)\.testclient\s+import", re.M)
KUBECLIENT = re.compile(r"\b(load_kube_config|new_client_from_config|load_config)\((?![^)]*\bconfig_file\s*=)[^)]*\)|\bload_incluster_config\(")
SKIP = re.compile(r"\bpytest\.(skip|importorskip|xfail)\(|\bmark\.(skip|skipif|xfail)\b|\bunittest\.skip")
SLEEP = re.compile(r"\b(time|asyncio|anyio|trio)\.sleep\(|(?<![\w.])sleep\(")

py_files = [f for f in found if f.endswith(".py") and "/tests/e2e/" in norm(f)]
for path in py_files:
    raw = read(path)
    code, strings = split_source(raw)
    lines = raw.splitlines()
    try:
        tree = ast.parse(raw)
    except SyntaxError:
        tree = None
    # A docstring is prose about the code, not code: the SQL and HTTP words in it are not checked.
    docstrings = set()
    for node in ast.walk(tree) if tree else []:
        body = getattr(node, "body", None)
        if (isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) and body
                and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) and isinstance(body[0].value.value, str)):
            docstrings.add(body[0].lineno)
    strings = [(where, text) for where, text in strings if where not in docstrings]
    inside = norm(path).split("/tests/e2e/", 1)[1]
    folder = inside.split("/")[0] if "/" in inside else ""
    name = os.path.basename(path)
    is_test = name.startswith("test_") or name.endswith("_test.py")
    in_smoke = folder == "smoke"

    def source_line(number):
        return lines[number - 1] if 0 < number <= len(lines) else ""

    if is_test and folder not in ("journeys", "smoke"):
        report("FAIL", "LAYOUT", path, 1, "a test under tests/e2e/ that is in neither journeys/ nor smoke/: nothing decides whether it may write, "
               "and neither runner selection collects it. Move it into tests/e2e/journeys/ or tests/e2e/smoke/")
    if in_smoke:
        for match in HTTP_WRITE_CALL.finditer(code):
            where = line_of(code, match.start())
            if "smoke-refusal-check" not in source_line(where):
                report("FAIL", "SMOKEWRITE", path, where, f"an HTTP {match.group(1).upper()} in a smoke file. Smoke is read-only: a test that creates, "
                       "changes or deletes data is a journey in tests/e2e/journeys/")
        for where, text in strings:
            if "smoke-refusal-check" in source_line(where):
                continue
            if HTTP_WRITE_WORD.match(text):
                report("FAIL", "SMOKEWRITE", path, where, "an HTTP write method in a smoke file. Smoke is read-only")
            elif SQL_WRITE.search(text):
                report("FAIL", "SMOKEWRITE", path, where, "a database write in a smoke file. Smoke is read-only")
        for match in re.finditer(r"^\s*(?:from|import)\s+([\w.]*\bjourneys\b[\w.]*|asyncpg|psycopg\w*|sqlalchemy|aiokafka)\b", code, re.M):
            report("FAIL", "SMOKEWRITE", path, line_of(code, match.start()), f"a smoke file imports {match.group(1)}: journey code, a database "
                   "driver or a broker client gives a smoke test a way to write. Smoke uses the `smoke` client only")
        for node in ast.walk(tree) if tree else []:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test"):
                for argument in node.args.args + node.args.kwonlyargs:
                    if re.fullmatch(r"env|api|ref|throwaway_db|(create|insert|seed|make)_\w+", argument.arg):
                        report("FAIL", "SMOKEWRITE", path, node.lineno, f"{node.name} asks for the journey fixture `{argument.arg}`; "
                               "smoke tests use the `smoke` client only")
    for where, text in strings:
        if UPSERT.search(text):
            report("FAIL", "UPSERT", path, where, "an upsert overwrites rows that already exist; seed with a plain INSERT so a clash fails")
    for match in SLEEP.finditer(code):
        where = line_of(code, match.start())
        if "e2e-poll-interval" not in source_line(where):
            report("FAIL", "SLEEP", path, where, "sleeping as a wait; poll for the effect with a deadline (eventually, eventually_async)")
    for where, text in strings:
        found_env = ENV_ADDRESS.match(text)
        if not found_env or not re.search(r"\b(environ|getenv)\b", source_line(where)):
            continue
        if found_env.group(1) == "E2E_SMOKE_URL" and (in_smoke or name == "conftest.py" and folder == ""):
            continue
        report("FAIL", "ENVADDR", path, where, f"an address read from the environment ({found_env.group(1)}); journeys take addresses only from "
               "the run marker of the throwaway cluster, and smoke tests only from E2E_SMOKE_URL through the `smoke` client")
    if not (name == "support.py" and folder == ""):
        for match in RAW_CLIENT.finditer(code):
            report("FAIL", "RAWCLIENT", path, line_of(code, match.start()), "an HTTP client that is not the bound one: it can reach any address, an "
                   "absolute URL included, and sends no traceparent. Use env.client(...), env.async_client(...) or the `smoke` fixture")
    for match in INPROCESS.finditer(code):
        report("FAIL", "INPROCESS", path, line_of(code, match.start()), "the product runs inside the test process here, so no network hop is crossed: "
               "that is an integration test. An end-to-end test reaches the deployed Pods over the network")
    for match in KUBECLIENT.finditer(code):
        report("FAIL", "KUBECLIENT", path, line_of(code, match.start()), "a Kubernetes client loaded without the run's own kubeconfig file: it "
               "then reads the caller's kubeconfig and current context, and by default writes the file back. Read the run marker with "
               "kubectl --kubeconfig <the run's file>, or pass config_file=, context= and persist_config=False")
    for match in SKIP.finditer(code):
        report("FAIL", "SKIP", path, line_of(code, match.start()), "a skipped or expected-to-fail end-to-end test is a deletion without a record; "
               "list it in quarantine-python.txt with an issue and a deadline")
    for match in re.finditer(r"\bmark\.quarantine\w*\b", code):
        report("FAIL", "QUARANTINEMARK", path, line_of(code, match.start()), "quarantine by marker carries no issue and no deadline; name the test in "
               "tests/e2e/quarantine-python.txt instead")
    for match in re.finditer(r"\bmark\.flaky\b|\breruns\s*=", code):
        report("FAIL", "RERUN", path, line_of(code, match.start()), "a rerun set in the test itself; the suite runner retries a failed test once and "
               "reports it as flaky")
    if is_test and folder == "journeys":
        for node in ast.walk(tree) if tree else []:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test_journey"):
                above = "\n".join(lines[max(0, node.lineno - 4):node.lineno - 1])
                if not re.search(r"\bAC-US-\d+\.\d+\b", (ast.get_docstring(node) or "") + above):
                    report("WARN", "NOCRITERION", path, node.lineno, f"{node.name} names no acceptance criterion (AC-US-n.m) in its docstring")

# --------------------------------------------------------- pytest settings
settings_checked = 0
for path in found:
    if os.path.basename(path) not in ("pyproject.toml", "pytest.ini", "setup.cfg", "tox.ini"):
        continue
    text = read(path)
    if not re.search(r"\[tool\.pytest|\[pytest\]|\[tool:pytest\]", text):
        continue
    settings_checked += 1
    for number, line in enumerate(text.splitlines(), 1):
        line = re.sub(r"(^|\s)#.*$", "", line)
        if re.search(r"--reruns\b|^\s*reruns\s*=|--only-rerun\b|--force-reruns\b", line):
            report("FAIL", "RERUN", path, number, "a rerun setting for every pytest run: retries exist at the end-to-end layer only "
                   "(test-pyramid), where the suite runner does the one retry itself")
        if re.search(r"timeout_method\s*=\s*[\"']?thread|--timeout-method[ =]thread", line):
            report("FAIL", "TIMEOUTTHREAD", path, number, "pytest-timeout's thread method ends the process: no teardown runs and no report is written. "
                   "Use the signal method, or leave the limit to the suite runner")

# ------------------------------------------------- shell, make and workflows
def commands(text):
    """Logical command lines with their first line number: continuations joined, comments dropped."""
    out, buffer, start = [], "", 0
    for number, line in enumerate(text.splitlines(), 1):
        stripped = re.sub(r"(^|\s)#.*$", "", line) if not buffer else line
        if not buffer:
            start = number
        if stripped.rstrip().endswith("\\"):
            buffer += stripped.rstrip()[:-1] + " "
            continue
        out.append((start, buffer + stripped))
        buffer = ""
    if buffer:
        out.append((start, buffer))
    return out


# kind, helm or kubectl as a command word anywhere on the line (behind a wrapper
# such as `run`, `sudo` or `exec` too), but not inside the text of an echo.
TOOL = re.compile(r"(?<![\w./$-])(kubectl|helm|kind)\s+([^;&|)]*)")
ECHOED = re.compile(r"(^|[;&|()]|\bthen\b|\bdo\b|\belse\b)\s*(echo|printf|say)\b[^;&|]*$")
PYTEST = re.compile(r"(?<![\w./-])(pytest|py\.test)(\s|$)")


def check_commands(path, lines, e2e_only):
    for number, line in lines:
        for match in TOOL.finditer(line):
            tool, rest = match.group(1), match.group(2)
            if ECHOED.search(line[:match.start()]) or re.match(r"(is|are|was|without|with|and|or|[,.:])(\s|$)", rest):
                continue
            if tool == "kubectl":
                if re.search(r"\bconfig\s+(use-context|set-context|set-cluster|set-credentials)\b", rest):
                    report("FAIL", "KUBECONFIG", path, number, "kubectl config changes the kubeconfig every other terminal uses; pass --kubeconfig and --context instead")
                elif "--kubeconfig" not in rest and not re.match(r"version\b", rest):
                    report("FAIL", "KUBECONFIG", path, number, "kubectl without --kubeconfig acts on the caller's current context; name the kubeconfig file created for this run")
            elif tool == "helm":
                if re.match(r"(version|lint|template|package|dependency|repo|show|create)\b", rest):
                    continue
                if "--kubeconfig" not in rest:
                    report("FAIL", "KUBECONFIG", path, number, "helm without --kubeconfig acts on the caller's current context; name the kubeconfig file created for this run")
            else:
                if re.match(r"delete\s+clusters?\b", rest) and re.search(r"--all\b", rest):
                    report("FAIL", "SWEEP", path, number, "deletes every kind cluster on the machine, other people's and other runs' included; "
                           "a run deletes the one cluster it created, by name")
                elif re.match(r"(create|delete)\s+clusters?\b|export\s+kubeconfig\b", rest):
                    if "--kubeconfig" not in rest:
                        report("FAIL", "KUBECONFIG", path, number, "kind without --kubeconfig writes the caller's kubeconfig and switches its current context")
                    if not re.search(r"--name\b", rest):
                        report("FAIL", "KUBECONFIG", path, number, "kind without --name acts on the default cluster 'kind'; name this run's cluster")
        if re.search(r"\bkind\s+get\s+clusters\b[^;&]*\|[^;&]*(xargs|while\s+read)\b[^;&]*\bdelete\b|\bfor\s+\w+\s+in\s+\$\(\s*kind\s+get\s+clusters", line):
            report("FAIL", "SWEEP", path, number, "deletes clusters by pattern: one of them may belong to a run in progress. "
                   "A run deletes the one cluster it created, by name; a leftover is reported, not removed")
        if (re.search(r"\bhelm\b[^;|&]*\s(install|upgrade)\s|\bupgrade\s+--install\b", line)
                and not re.search(r"--wait(\s|=|$)|--rollback-on-failure|--atomic", line)):
            report("FAIL", "HELMWAIT", path, number, "helm install or upgrade without --wait: Helm 4 then waits only for hooks and succeeds before any Pod is ready")
        if re.search(r"(^|[;&|]\s*|\bdo\s+|\bthen\s+)sleep\s+[\d$\"']", line):
            report("FAIL", "SLEEP", path, number, "sleep as a wait; poll for the condition with a deadline (kubectl rollout status, kubectl wait, a polling loop with a limit)")
        if re.search(r"--reruns\b|--only-rerun\b|--force-reruns\b|\buntil\s+[^;]*\bpytest\b|\bpytest\b[^|;&]*\|\|[^|;&]*\bpytest\b|--lf\b|--last-failed\b", line):
            report("FAIL", "RERUN", path, number, "a rerun plugin or a rerun loop: pytest exits 0 when a test passes on its rerun, so a flaky test "
                   "would be reported as green. run-python-e2e-suite.sh retries a failed test once and reports it as flaky")
        elif (PYTEST.search(line) and not ECHOED.search(line[:PYTEST.search(line).start()])
              and (e2e_only or re.search(r"tests/e2e\b|-m\s+[\"']?[^\"']*\b(e2e|smoke)\b", line))):
            report("FAIL", "RERUN", path, number, "pytest called directly for the end-to-end tests: its exit status is 0 when every test was skipped "
                   "and it does no retry or quarantine. Call tests/e2e/run-python-e2e-suite.sh <journeys|smoke|quarantine>")
        if re.search(r"\|\s*tee\b[^|;&]*\$\{?GITHUB_(ENV|OUTPUT|PATH)\b", line):
            report("FAIL", "ENVFILE", path, number, "the whole output of a command is appended to a GitHub Actions file; any line that is not KEY=value "
                   "breaks it, and an address then travels between steps in a variable. One script provisions, tests and tears down")
        if re.search(r"(^|[;&|(]\s*)(aws|gcloud|az|doctl|tofu|terraform|eksctl)\s", line):
            report("FAIL", "CLOUD", path, number, "a cloud command in the end-to-end path; the suite creates and deletes nothing outside the local container runtime")
        if re.search(r"\bdocker[ -]compose\b", line):
            report("FAIL", "COMPOSE", path, number, "Docker Compose is a second description of the deployment; install the product's charts into the throwaway cluster")


RUNS_TESTS = re.compile(r"\bgo\s+test\b|\bpytest\b|\bplaywright\b|E2E_SUITES|run-go-e2e-suite|run-python-e2e-suite")
shell_checked = make_checked = workflow_checked = 0
for path in found:
    full = norm(path)
    name = os.path.basename(path)
    if name.endswith(".sh") and ("/e2e/" in full or re.search(r"\bkind\s+create\s+cluster\b", read(path))):
        text = read(path)
        if "exec python3 -I - " in text and name in ("run-python-e2e-suite.sh", "run-go-e2e-suite.sh"):
            shell_checked += 1          # the shipped runners are Python programs in a shell wrapper
            continue
        shell_checked += 1
        lines = commands(text)
        check_commands(path, lines, True)
        joined = "\n".join(line for _, line in lines)
        if re.search(r"\bkind\s+create\s+cluster\b", joined):
            created = next(n for n, line in lines if re.search(r"\bkind\s+create\s+cluster\b", line))
            if not re.search(r"\bkind\s+delete\s+clusters?\b", joined):
                report("FAIL", "NOTEARDOWN", path, created, "creates a cluster and never deletes it")
            elif not RUNS_TESTS.search(joined) and re.search(r"\btrap\b[^\n]*\bEXIT\b", joined):
                report("FAIL", "TRAPONLY", path, created,
                       "the exit trap deletes the cluster when this script ends, which is before the tests run; one script must create, test and delete")
            elif not RUNS_TESTS.search(joined):
                report("FAIL", "TRAPONLY", path, created,
                       "this script creates the cluster but does not run the tests; teardown then depends on a later step. One script must create, test and delete")
    elif name in ("Makefile", "makefile", "GNUmakefile") or name.endswith(".mk"):
        text = read(path)
        target, picked = None, []
        for number, line in enumerate(text.splitlines(), 1):
            head = re.match(r"^([A-Za-z0-9_.-]+)\s*:(?!=)", line)
            if head:
                target = head.group(1)
            elif line.startswith("\t") and target and "e2e" in target:
                picked.append((number, line.strip().lstrip("@-")))
        if picked:
            make_checked += 1
            check_commands(path, picked, True)
    elif "/.github/workflows/" in full and name.endswith((".yml", ".yaml")):
        text = read(path)
        if not re.search(r"\bmake\s+e2e\b|run-e2e-environment|run-python-e2e-suite|tests/e2e\b|-m\s+[\"']?(e2e|smoke)\b", text):
            continue
        workflow_checked += 1
        lines = commands(text)
        stripped = "\n".join(line for _, line in lines)
        check_commands(path, [(n, re.sub(r"^\s*(-\s*)?(run:\s*)?", "", line)) for n, line in lines], False)
        if not re.search(r"^\s*permissions\s*:", stripped, re.M):
            report("FAIL", "PERMISSIONS", path, 1, "no permissions block: the token gets the repository default. Declare `permissions: contents: read` and add only what a job needs")
        for match in re.finditer(r"^\s*permissions\s*:\s*write-all\b", stripped, re.M):
            report("FAIL", "PERMISSIONS", path, line_of(stripped, match.start()), "write-all gives the token every scope")
        triggers = re.search(r"^(?:on|\"on\"|'on')\s*:(.*?)(?=^\S)", stripped + "\nEND:", re.M | re.S)
        on = triggers.group(1) if triggers else ""
        on_line = line_of(stripped, triggers.start()) if triggers else 1
        if re.search(r"\bpull_request(_target)?\b", on):
            report("FAIL", "PRTRIGGER", path, on_line, "the end-to-end suite must not run on a pull request: nightly, before a release and by hand")
        if re.search(r"^\s*release\s*:", on, re.M):
            report("FAIL", "RELEASE", path, on_line,
                   "a release trigger fires after the release exists, so this run cannot stop it. Call the suite from the workflow that publishes, as a job the publish job needs")
        for match in re.finditer(r"\$\{\{\s*secrets\.(\w+)", stripped):
            if match.group(1) != "GITHUB_TOKEN":
                report("FAIL", "CREDENTIALS", path, line_of(stripped, match.start()),
                       f"secret {match.group(1)} in the end-to-end workflow: the suite needs no stored credential, because everything it touches lives in the job's own runner")
        for match in re.finditer(r"^\s*-?\s*uses:\s*([\w./-]+)@([\w.-]+)", stripped, re.M):
            if not re.fullmatch(r"[0-9a-f]{40}", match.group(2)) and not match.group(1).startswith("./"):
                report("WARN", "UNPINNED", path, line_of(stripped, match.start()), f"{match.group(1)}@{match.group(2)} is not pinned to a commit")
        if re.search(r"upload-artifact", stripped) and not re.search(r"if:\s*(\$\{\{\s*)?(always\(\)|!\s*cancelled\(\)|failure\(\))", stripped):
            report("WARN", "NOALWAYS", path, 1, "evidence upload has no `if:`; after a failed step it is skipped")

total = len(py_files) + settings_checked + shell_checked + make_checked + workflow_checked
if len(py_files) + shell_checked + make_checked + workflow_checked == 0:
    print("ERROR: no end-to-end Python file, script, make target or workflow found; nothing was checked")
    sys.exit(2)
print(f"checked {len(py_files)} Python file(s), {settings_checked} pytest settings file(s), {shell_checked} script(s), "
      f"{make_checked} Makefile(s), {workflow_checked} workflow(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
