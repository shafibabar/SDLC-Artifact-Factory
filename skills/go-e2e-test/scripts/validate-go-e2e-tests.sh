#!/bin/bash
# validate-go-e2e-tests.sh <product-root-or-path>...
#
# Text checks on a product's Go end-to-end suite and what runs it: the Go files
# under an e2e/ folder, the shell scripts there (and any script that creates a
# kind cluster), the e2e targets of a Makefile, and the workflows that run the
# suite. It needs no Go, Docker or cluster and runs nothing: it finds the known
# dangerous mistakes, it does not prove a suite is good.
#
# FAIL rules: TAG (a file without the e2e or smoke build tag, or a non-test Go
# file), SMOKEWRITE (a file compiled into the smoke build that can write),
# UPSERT, SLEEP, ENVADDR (journey address read from the environment), SKIP,
# KUBECONFIG (kind, helm or kubectl without the run's kubeconfig; use-context),
# HELMWAIT, TRAPONLY (cluster deleted by an exit trap before the tests run),
# NOTEARDOWN, RERUN, CLOUD, COMPOSE, PERMISSIONS, PRTRIGGER, RELEASE,
# CREDENTIALS. WARN rules: NOCRITERION, UNPINNED, NOALWAYS.
# Exit 0 = no FAIL (each WARN needs judgement); 1 = at least one FAIL;
# 2 = usage, a missing path, or nothing to check.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: validate-go-e2e-tests.sh <product-root-or-path>..." >&2
  exit 2
fi
exec python3 -I - "$@" << 'PY'
import os, re, sys

found = []
for arg in sys.argv[1:]:
    if os.path.isfile(arg):
        found.append(arg)
    elif os.path.isdir(arg):
        for base, dirs, names in os.walk(arg):
            dirs[:] = sorted(d for d in dirs if d not in {".git", "vendor", "testdata", "node_modules", "e2e-evidence"})
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


# ---------------------------------------------------------------- Go files
GO_TOKEN = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|`[^`]*`', re.S)


def blank(text):
    return "\n" * text.count("\n")


def strip_comments(match):
    text = match.group(0)
    return blank(text) if text.startswith("/") else text


def strip_all(match):
    text = match.group(0)
    return blank(text) if text.startswith("/") else '""' + blank(text)


def included(constraint, tags):
    """Evaluates a //go:build expression for a set of tags."""
    expr = re.sub(r"[A-Za-z_][\w.]*", lambda m: str(m.group(0) in tags), constraint)
    expr = expr.replace("&&", " and ").replace("||", " or ").replace("!", " not ")
    try:
        return bool(eval(expr, {"__builtins__": {}}, {}))  # only True, False, and, or, not, ( )
    except Exception:
        return True


WRITES = [
    (r'http\.Method(Post|Put|Patch|Delete)\b|"(POST|PUT|PATCH|DELETE)"', "an HTTP write"),
    (r'(?i)["`][^"`]*\b(INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|TRUNCATE)\b', "a database write"),
    (r"\.(Exec|ExecContext)\(", "a database statement"),
]
go_files = [f for f in found if f.endswith(".go") and "/e2e/" in norm(f)]
for path in go_files:
    raw = read(path)
    kept = GO_TOKEN.sub(strip_comments, raw)
    code = GO_TOKEN.sub(strip_all, raw)
    head = re.split(r"^package\s", raw, maxsplit=1, flags=re.M)[0]
    tag = re.search(r"^//go:build\s+(.+)$", head, re.M)
    if not path.endswith("_test.go"):
        report("FAIL", "TAG", path, 1, "a Go file here that is not a _test.go file: the coverage gates cannot measure it and it can ship. "
               "Keep every end-to-end helper in _test.go files")
    if not tag or not re.search(r"\b(e2e|smoke)\b", tag.group(1)):
        report("FAIL", "TAG", path, 1, "no e2e or smoke build tag: this file compiles into make ci, the coverage gate and every smoke run")
        constraint = None
    else:
        constraint = tag.group(1).strip()
    in_smoke = constraint is None or included(constraint, {"smoke"}) or included(constraint, {"smoke", "e2e"})
    in_journeys = constraint is None or included(constraint, {"e2e"})
    if in_smoke:
        for pattern, what in WRITES:
            for match in re.finditer(pattern, kept):
                where = line_of(kept, match.start())
                source = raw.splitlines()[where - 1] if where <= len(raw.splitlines()) else ""
                if "smoke-refusal-check" in source:
                    continue
                report("FAIL", "SMOKEWRITE", path, where,
                       f"{what} in a file the smoke build compiles (build tag: {constraint or 'none'}). Smoke is read-only: "
                       "tag files that create or delete data `e2e && !smoke`")
    for match in re.finditer(r"(?i)\bON\s+CONFLICT\b[^;`\"]*\bDO\s+UPDATE\b|\bINSERT\s+OR\s+REPLACE\b|\bREPLACE\s+INTO\b|\bMERGE\s+INTO\b|\bON\s+DUPLICATE\s+KEY\b", kept):
        report("FAIL", "UPSERT", path, line_of(kept, match.start()),
               "an upsert overwrites rows that already exist; seed with a plain INSERT so a clash fails")
    for match in re.finditer(r"\btime\.Sleep\(", code):
        report("FAIL", "SLEEP", path, line_of(code, match.start()), "sleeping as a wait; poll for the effect with a deadline")
    if in_journeys and not included(constraint or "smoke", {"smoke"}):
        for match in re.finditer(r'\bos\.(Getenv|LookupEnv)\(\s*"[A-Z0-9_]*(URL|HOST|ADDR|ADDRESS|DSN|ENDPOINT)[A-Z0-9_]*"', kept):
            report("FAIL", "ENVADDR", path, line_of(kept, match.start()),
                   "a journey address read from the environment; take addresses only from the run marker of the throwaway cluster")
    for match in re.finditer(r"\b\w+\.Skip(f|Now)?\(", code):
        report("FAIL", "SKIP", path, line_of(code, match.start()),
               "a skipped end-to-end test is a deletion without a record; list it in quarantine.txt with an issue and a deadline")
    for match in re.finditer(r"^func (TestJourney\w*)\(", raw, re.M):
        comment = re.search(r"((?:^//[^\n]*\n)+)\Z", raw[:match.start()], re.M)
        if not comment or not re.search(r"\bAC-US-\d+\.\d+\b", comment.group(1)):
            report("WARN", "NOCRITERION", path, line_of(raw, match.start()),
                   f"{match.group(1)} names no acceptance criterion (AC-US-n.m) in its comment")

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


def check_commands(path, lines):
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
                if re.match(r"(create|delete)\s+clusters?\b|export\s+kubeconfig\b", rest):
                    if "--kubeconfig" not in rest:
                        report("FAIL", "KUBECONFIG", path, number, "kind without --kubeconfig writes the caller's kubeconfig and switches its current context")
                    if not re.search(r"--name\b|--all\b", rest):
                        report("FAIL", "KUBECONFIG", path, number, "kind without --name acts on the default cluster 'kind'; name this run's cluster")
        if (re.search(r"\bhelm\b[^;|&]*\s(install|upgrade)\s|\bupgrade\s+--install\b", line)
                and not re.search(r"--wait(\s|=|$)|--rollback-on-failure|--atomic", line)):
            report("FAIL", "HELMWAIT", path, number, "helm install or upgrade without --wait: Helm 4 then waits only for hooks and succeeds before any Pod is ready")
        if re.search(r"(^|[;&|]\s*|\bdo\s+|\bthen\s+)sleep\s+[\d$\"']", line):
            report("FAIL", "SLEEP", path, number, "sleep as a wait; poll for the condition with a deadline (kubectl rollout status, kubectl wait, a polling loop with a limit)")
        if re.search(r"\bgo\s+test\b[^|]*\|\|\s*go\s+test\b|\buntil\s+go\s+test\b", line):
            report("FAIL", "RERUN", path, number, "a rerun of the whole suite on failure; retry only the failed tests, once, by exact name (run-go-e2e-suite.sh)")
        if re.search(r"(^|[;&|(]\s*)(aws|gcloud|az|doctl|tofu|terraform|eksctl)\s", line):
            report("FAIL", "CLOUD", path, number, "a cloud command in the end-to-end path; the suite creates and deletes nothing outside the local container runtime")
        if re.search(r"\bdocker[ -]compose\b", line):
            report("FAIL", "COMPOSE", path, number, "Docker Compose is a second description of the deployment; install the product's charts into the throwaway cluster")


RUNS_TESTS = re.compile(r"\bgo\s+test\b|\bpytest\b|\bplaywright\b|E2E_SUITES|run-go-e2e-suite")
shell_checked = make_checked = workflow_checked = 0
for path in found:
    full = norm(path)
    name = os.path.basename(path)
    if name.endswith(".sh") and ("/e2e/" in full or re.search(r"\bkind\s+create\s+cluster\b", read(path))):
        text = read(path)
        shell_checked += 1
        lines = commands(text)
        check_commands(path, lines)
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
            check_commands(path, picked)
    elif "/.github/workflows/" in full and name.endswith((".yml", ".yaml")):
        text = read(path)
        if not re.search(r"\bmake\s+e2e\b|run-e2e-environment|run-go-e2e-suite|tests/e2e\b|-tags[ =]\"?e2e", text):
            continue
        workflow_checked += 1
        lines = commands(text)
        stripped = "\n".join(line for _, line in lines)
        check_commands(path, [(n, re.sub(r"^\s*(-\s*)?(run:\s*)?", "", line)) for n, line in lines])
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

total = len(go_files) + shell_checked + make_checked + workflow_checked
if total == 0:
    print("ERROR: no end-to-end Go file, script, make target or workflow found; nothing was checked")
    sys.exit(2)
print(f"checked {len(go_files)} Go file(s), {shell_checked} script(s), {make_checked} Makefile(s), "
      f"{workflow_checked} workflow(s): {fails} FAIL, {warns} WARN")
sys.exit(1 if fails else 0)
PY
