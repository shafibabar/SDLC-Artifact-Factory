#!/bin/bash
# validate-python-mutation-setup.sh [<project-root>]
#
# Checks a Python product's mutation-testing setup against python-mutation-test
# (decision D048 and the mutation decisions of 2026-11-28), before any run. Reads,
# under <project-root>: pyproject.toml, uv.lock, mutation/mutant-record.txt,
# mutation/exclusions.txt, Makefile, .github/workflows/*.y*ml, scripts/*.sh and
# every .py file under src/ (or under source_paths when there is no src/).
# FAIL (exit 1):
#   - no [tool.mutmut]; a key mutmut 3.8.1 does not read (ignored silently:
#     runner, backup, ...); the deprecated paths_to_mutate or tests_dir; no
#     source_paths; a source path that is missing or under tests/;
#     mutate_only_covered_lines = true; --no-cov missing from pytest_add_cli_args;
#     coverage flags in pytest's addopts
#   - code hidden from mutation without an approved mutation/exclusions.txt entry:
#     product code under src/ outside source_paths, a do_not_mutate or
#     only_mutate setting leaving out a file, a `# pragma: no mutate` (any form)
#     or a do_not_mutate_patterns match (generated files are exempt)
#   - mutmut not pinned to an exact version (mutmut==X.Y.Z) in pyproject.toml,
#     uv.lock holding another version, an unpinned install (pip install mutmut,
#     uvx mutmut, @latest), mutmut run called directly instead of through
#     run-python-mutation.sh, mutmut's badge or export-cicd-stats used as a gate
#   - a percentage on a mutation line; a masked exit status (|| true,
#     continue-on-error)
#   - a mutation workflow triggered by release (that runs after publication), no
#     scheduled run, a schedule less often than monthly, no workflow_call, or no
#     workflow whose publishing job needs the mutation job
#   - make mutation missing, using --changed-since, or not judging with
#     --mode release; a malformed record or exclusion line; the runner or the
#     verdict script not copied into scripts/
# WARN (exit 0): timeout_multiplier under 15; type_check_command set (each
#   mutant it rejects needs a record line); a pull_request trigger; checkout
#   without fetch-depth: 0; pending exclusions; mutants/ or mutation-out/ not in
#   .gitignore.
# Exit 0 = no FAIL, 1 = at least one FAIL, 2 = usage.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, fnmatch, hashlib, os, re, sys

if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1].startswith("-")):
    print("usage: validate-python-mutation-setup.sh [<project-root>]")
    sys.exit(2)
root = os.path.realpath(sys.argv[1] if len(sys.argv) == 2 else ".")
try:
    import tomllib
except ImportError:
    print("usage: needs Python 3.11 or later (tomllib)")
    sys.exit(2)
if not os.path.isfile(os.path.join(root, "pyproject.toml")):
    print(f"usage: no pyproject.toml in {root}")
    sys.exit(2)
fails, warns = [], []
def fail(where, msg): fails.append(f"FAIL: {where}: {msg}")
def warn(where, msg): warns.append(f"WARN: {where}: {msg}")
def rel(p): return os.path.relpath(p, root)
def text(path):
    try:
        return open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        return None

try:
    data = tomllib.loads(text(os.path.join(root, "pyproject.toml")) or "")
except ValueError as exc:
    print(f"FAIL: pyproject.toml: not valid TOML: {exc}")
    print("1 FAIL, 0 WARN")
    sys.exit(1)

KNOWN = {"also_copy", "only_mutate", "do_not_mutate", "do_not_mutate_patterns", "max_stack_depth", "debug",
         "source_paths", "pytest_add_cli_args", "pytest_add_cli_args_test_selection", "mutate_only_covered_lines",
         "timeout_multiplier", "timeout_constant", "type_check_command", "use_setproctitle", "track_dependencies",
         "dependency_tracking_depth", "cache_invalidation_files", "cache_invalidation_exclude",
         "on_dependency_change", "use_git_change_detection", "process_isolation", "forkserver_warmup",
         "max_forkserver_restarts", "preload_modules_file", "log_to_file", "log_file_path"}
cfg = data.get("tool", {}).get("mutmut")
if not isinstance(cfg, dict):
    fail("pyproject.toml", "no [tool.mutmut] table")
    cfg = {}
for key in sorted(cfg):
    if key in ("paths_to_mutate", "tests_dir"):
        fail("pyproject.toml", f"[tool.mutmut] {key} is deprecated in mutmut 3 (a string value crashes it): use "
             + ("source_paths" if key == "paths_to_mutate" else "pytest_add_cli_args_test_selection"))
    elif key not in KNOWN:
        fail("pyproject.toml", f"[tool.mutmut] {key} is not a mutmut 3.8.1 setting and is ignored without a warning")
for key in ("source_paths", "pytest_add_cli_args", "do_not_mutate", "only_mutate", "do_not_mutate_patterns",
            "type_check_command"):
    if key in cfg and not (isinstance(cfg[key], list) and all(isinstance(x, str) for x in cfg[key])):
        fail("pyproject.toml", f"[tool.mutmut] {key} must be a list of strings (mutmut does not convert values)")
sources = [s.rstrip("/") for s in cfg.get("source_paths") or [] if isinstance(s, str)]
if cfg and not sources:
    fail("pyproject.toml", "[tool.mutmut] has no source_paths: mutmut then guesses; name the package, e.g. [\"src/<pkg>\"]")
for s in sources:
    if not os.path.exists(os.path.join(root, s)):
        fail("pyproject.toml", f"source path {s} does not exist")
    if s == "tests" or s.startswith("tests/"):
        fail("pyproject.toml", f"source path {s} is test code; test support is never mutated")
if cfg.get("mutate_only_covered_lines") is True:
    fail("pyproject.toml", "mutate_only_covered_lines = true leaves every line coverage excludes unmutated; remove it")
if cfg and "--no-cov" not in (cfg.get("pytest_add_cli_args") or []):
    fail("pyproject.toml", "pytest_add_cli_args lacks --no-cov: coverage flags make mutmut's stats run fail")
addopts = data.get("tool", {}).get("pytest", {}).get("ini_options", {}).get("addopts", "")
if "--cov" in (" ".join(addopts) if isinstance(addopts, list) else str(addopts)):
    fail("pyproject.toml", "coverage flags in pytest addopts: python-unit-test keeps them out of shared settings")
tm = cfg.get("timeout_multiplier")
if isinstance(tm, (int, float)) and tm < 15:
    warn("pyproject.toml", f"timeout_multiplier {tm} is under mutmut's default 15: more mutants time out and need the recheck")
if cfg.get("type_check_command"):
    warn("pyproject.toml", "type_check_command is set: every mutant it rejects is 'caught by type check' and needs "
         "its own not-viable record line, although a test would often kill it")

# --- the pin ------------------------------------------------------------------------
deps = []
proj = data.get("project", {})
deps += proj.get("dependencies", []) or []
for group in (proj.get("optional-dependencies", {}) or {}).values():
    deps += group
for group in (data.get("dependency-groups", {}) or {}).values():
    deps += [d for d in group if isinstance(d, str)]
pins = [d for d in deps if re.match(r"\s*mutmut\b", d)]
pinned = None
if not pins:
    fail("pyproject.toml", "mutmut is not a pinned dependency (add mutmut==3.8.1 to the dev group)")
for d in pins:
    m = re.fullmatch(r"\s*mutmut\s*==\s*(\d+\.\d+\.\d+)\s*", d)
    if not m:
        fail("pyproject.toml", f"'{d}' is not an exact pin: write mutmut==3.8.1")
    else:
        pinned = m.group(1)
lock = text(os.path.join(root, "uv.lock"))
if lock and pinned:
    m = re.search(r'\[\[package\]\]\s*\nname = "mutmut"\s*\nversion = "([^"]+)"', lock)
    if m and m.group(1) != pinned:
        fail("uv.lock", f"locks mutmut {m.group(1)}, pyproject.toml pins {pinned}: run uv lock")

# --- exclusions and the record --------------------------------------------------------
approved, pending, lines_ok = [], [], set()
for n, l in enumerate((text(os.path.join(root, "mutation", "exclusions.txt")) or "").splitlines(), 1):
    if not l.strip() or l.lstrip().startswith("#"):
        continue
    p = [x.strip() for x in l.split("|")]
    ok = (len(p) == 4 and p[0] and len(p[3]) >= 10 and re.fullmatch(r"file|folder|lines [0-9a-f]{12}", p[1])
          and (p[2] == "pending" or re.fullmatch(r"approved \d{4}-\d{2}-\d{2}", p[2])))
    if ok and p[2] != "pending":
        try:
            datetime.date.fromisoformat(p[2][9:])
        except ValueError:
            ok = False
    if not ok:
        fail(f"mutation/exclusions.txt:{n}", "write <path> | file|folder|lines <fingerprint> | approved YYYY-MM-DD | <reason>, "
             "or | pending | while awaiting the product owner")
        continue
    if p[2] == "pending":
        pending.append(p[0])
        warn(f"mutation/exclusions.txt:{n}", f"{p[0]} awaits the product owner and is not excluded until approved")
    elif p[1].startswith("lines"):
        lines_ok.add((p[0], p[1][6:]))
    else:
        approved.append(p[0].rstrip("/") + ("/" if p[1] == "folder" else ""))
for n, l in enumerate((text(os.path.join(root, "mutation", "mutant-record.txt")) or "").splitlines(), 1):
    if not l.strip() or l.lstrip().startswith("#"):
        continue
    p = [x.strip() for x in l.split("|")]
    ok = (len(p) == 5 and re.fullmatch(r"\S+__mutmut_\d+", p[0]) and p[1] in ("equivalent", "timeout", "not-viable")
          and re.fullmatch(r"[0-9a-f]{12}", p[2]) and len(p[3]) >= 10 and not p[3].startswith("<")
          and re.fullmatch(r".+ \d{4}-\d{2}-\d{2}", p[4]))
    if not ok:
        fail(f"mutation/mutant-record.txt:{n}", "write <mutant name> | equivalent|timeout|not-viable | "
             "<fingerprint from check-python-mutation.sh> | <reason> | <who> <YYYY-MM-DD>")

GENERATED = re.compile(r"@generated|generated.*do not edit|do not edit.*generated", re.I)
def generated(src):
    for line in src.splitlines():
        s = line.strip()
        if not s:
            continue
        if not s.startswith("#"):
            return False
        if GENERATED.search(s):
            return True
    return False

def covered(path):
    return any(path == a or (a.endswith("/") and path.startswith(a)) for a in approved)
def awaiting(path):
    return any(path == a.rstrip("/") or path.startswith(a.rstrip("/") + "/") for a in pending)

only, never = cfg.get("only_mutate") or [], cfg.get("do_not_mutate") or []
patterns = []
for p in cfg.get("do_not_mutate_patterns") or []:
    try:
        patterns.append(re.compile(p))
    except re.error:
        fail("pyproject.toml", f"do_not_mutate_patterns entry does not compile: {p}")
for base in ["src"] if os.path.isdir(os.path.join(root, "src")) else sources:
    for d, dirs, files in os.walk(os.path.join(root, base)):
        dirs[:] = sorted(x for x in dirs if not x.startswith(".") and x != "__pycache__")
        for f in sorted(files):
            if not f.endswith(".py"):
                continue
            path = rel(os.path.join(d, f)).replace(os.sep, "/")
            src = text(os.path.join(d, f)) or ""
            if generated(src) or not re.search(r"^\s*(async\s+)?def\s", src, re.M):
                continue  # generated, or no function or method (mutmut plants nothing there)
            why = None
            if sources and not any(path == s or path.startswith(s + "/") for s in sources):
                why = "is outside source_paths"
            elif only and not any(fnmatch.fnmatch(path, p) for p in only):
                why = "is not matched by only_mutate"
            elif any(fnmatch.fnmatch(path, p) for p in never):
                why = "is matched by do_not_mutate"
            if why:
                if not covered(path):
                    fail(path, f"{why} {'before the product owner approved it' if awaiting(path) else 'without an approved exclusion in mutation/exclusions.txt'}: all product code is in scope")
                continue
            for n, line in enumerate(src.splitlines(), 1):
                if re.search(r"#\s*pragma:.*no mutate", line) or any(p.search(line) for p in patterns):
                    fp = hashlib.sha256(line.strip().encode()).hexdigest()[:12]
                    if (path, fp) not in lines_ok:
                        fail(f"{path}:{n}", "not mutated (pragma or do_not_mutate_patterns) without an approved "
                             f"exclusion; record equivalent mutants in mutation/mutant-record.txt instead, or propose: "
                             f"{path} | lines {fp} | pending | <reason>")

# --- Makefile, workflows, scripts ----------------------------------------------------
files = [os.path.join(root, n) for n in ("Makefile", "makefile", "GNUmakefile") if os.path.isfile(os.path.join(root, n))]
wf_dir = os.path.join(root, ".github", "workflows")
workflows = sorted(os.path.join(wf_dir, f) for f in (os.listdir(wf_dir) if os.path.isdir(wf_dir) else [])
                   if f.endswith((".yml", ".yaml")))
scripts_dir = os.path.join(root, "scripts")
own = ("run-python-mutation.sh", "check-python-mutation.sh", "validate-python-mutation-setup.sh")
for f in own[:2]:
    if not os.path.isfile(os.path.join(scripts_dir, f)):
        fail(f"scripts/{f}", "missing: copy it from python-mutation-test unchanged")
others = sorted(os.path.join(scripts_dir, f) for f in (os.listdir(scripts_dir) if os.path.isdir(scripts_dir) else [])
                if f.endswith(".sh") and f not in own)
for path in files + workflows + others:
    for n, line in enumerate((text(path) or "").splitlines(), 1):
        where, low = f"{rel(path)}:{n}", line.lower()
        if re.search(r"\bpip3?\s+install\b[^\n]*\bmutmut\b(?!\s*==\s*\d+\.\d+\.\d+)", line) or \
                re.search(r"\b(uvx|uv\s+tool\s+(run|install)|pipx\s+(run|install))\s+mutmut\b(?!==\d)", line) or "mutmut@latest" in line:
            fail(where, "mutmut installed unpinned: install the project's locked dev group (uv sync --frozen)")
        if re.search(r"(^|[\s;&|(])mutmut\s+run\b", line):
            fail(where, "mutmut run called directly: run scripts/run-python-mutation.sh, which deletes mutants/, rechecks timeouts and records the commit")
        if re.search(r"\bmutmut\s+(badge|export-cicd-stats)\b", line):
            fail(where, "mutmut's badge and CI stats are not the verdict (they drop type-check and unchecked mutants, the badge counts timeouts as killed)")
        if re.search(r"mutation|mutmut|mutant", low) and re.search(r"\b\d{1,3}(\.\d+)?\s*%", line):
            fail(where, "a percentage on a mutation line: the target is 100%, with no lower percentage; every mutant is killed or recorded")
        if ("mutation" in low or "mutmut" in low) and re.search(r"\|\|\s*true|;\s*true\s*$", line):
            fail(where, "the exit status is masked")

make_src = "\n".join(text(p) or "" for p in files)
target = re.search(r"^mutation\s*:[^\n=]*\n((?:\t[^\n]*\n?)+)", make_src, re.M)
if not target:
    fail("Makefile", "no mutation target (the full run before each release)")
else:
    recipe = target.group(1)
    if "--changed-since" in recipe:
        fail("Makefile", "make mutation uses --changed-since: the release run covers the whole project")
    if "run-python-mutation.sh" not in recipe or not re.search(r"check-python-mutation\.sh[^\n]*--mode\s+release", recipe):
        fail("Makefile", "make mutation must run scripts/run-python-mutation.sh, then scripts/check-python-mutation.sh --mode release")

mut_wf = []
for path in workflows:
    src = text(path) or ""
    if not re.search(r"make\s+mutation|run-python-mutation\.sh", src):
        continue
    mut_wf.append(path)
    on = re.search(r"^on:\s*\n((?:[ \t]+[^\n]*\n?)+)", src, re.M)
    triggers = on.group(1) if on else ""
    if re.search(r"^\s{2}release\s*:", triggers, re.M) or re.search(r"^on:\s*\[?[^\n]*\brelease\b", src, re.M):
        fail(rel(path), "a release trigger fires after the release is published; the publishing workflow calls this one and its publish job needs it")
    if re.search(r"^\s{2}pull_request(_target)?\s*:", triggers, re.M):
        warn(rel(path), "runs on pull requests: allowed only as the product's chosen extra cadence, never instead of the release run")
    if "workflow_call" not in triggers:
        fail(rel(path), "no workflow_call: the publishing workflow cannot run it as a job its publish job needs")
    crons = re.findall(r"cron:\s*['\"]([^'\"]+)['\"]", src)
    if not crons:
        fail(rel(path), "no schedule: a scheduled run between releases is the default cadence (monthly)")
    for c in crons:
        f = c.split()
        if len(f) != 5 or f[3] != "*":
            fail(rel(path), f"cron '{c}' runs less often than monthly; a product may run more often, never less")
    if re.search(r"continue-on-error:\s*true", src):
        fail(rel(path), "continue-on-error hides an INVALID run")
    if "actions/checkout" in src and not re.search(r"fetch-depth:\s*0", src):
        warn(rel(path), "checkout without fetch-depth: 0: the scheduled changed-code run needs the last release tag")
if workflows and not mut_wf:
    fail(".github/workflows", "no workflow runs make mutation")
callers = []
for path in workflows:
    src = text(path) or ""
    for m in re.finditer(r"^  ([A-Za-z0-9_-]+):\s*\n((?:    [^\n]*\n?)+)", src, re.M):
        if re.search(r"uses:\s*\./\.github/workflows/\S+", m.group(2)) and any(
                os.path.basename(w) in m.group(2) for w in mut_wf):
            callers.append(bool(re.search(r"needs:\s*\[?[^\n\]]*\b" + re.escape(m.group(1)) + r"\b", src)))
if mut_wf and not any(callers):
    fail(".github/workflows", "no publishing workflow runs the mutation workflow as a job its publish job needs; "
         "the release must wait for the full run to finish")

gi = text(os.path.join(root, ".gitignore")) or ""
for entry in ("mutants", "mutation-out"):
    if entry not in gi:
        warn(".gitignore", f"add {entry}/ so run output is never committed")

for line in fails + warns:
    print(line)
print(f"{len(fails)} FAIL, {len(warns)} WARN")
sys.exit(1 if fails else 0)
PY
