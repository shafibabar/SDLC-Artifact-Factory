#!/bin/bash
# run-python-mutation.sh [--changed-since <ref>] [--out <dir>] [--mutmut-version <X.Y.Z>]
#                        [--recheck-multiplier <n>] [--max-children <n>] [<project-dir>]
#
# Runs mutmut once over a Python project at one clean commit, rechecks what
# mutmut cannot settle, and writes, in <out> (default <project-dir>/mutation-out):
#   mutmut.log    mutmut run's console output
#   results.txt   `mutmut results --all true` (one `<mutant name>: <status>` line
#                 per planted mutant; plain `--all` is refused by mutmut 3.8.1)
#   recheck.txt   one line per mutant that timed out: `<name> timeout -> <status>`,
#                 the status mutmut gave it when run again, alone, with
#                 timeout_multiplier <n> (default 60; mutmut's own default is 15)
#   show.txt      `mutmut show <name>` for every mutant not killed (its diff is the
#                 fingerprint the record uses)
#   typecheck.txt `<name>: <type checker message>` for each `caught by type check`
#                 (read from mutmut's own state; empty when none)
#   scope.txt     with --changed-since: the mutant-name globs of the functions and
#                 methods changed since <ref>, one per line
#   run.txt       commit, source id (a hash of the tracked .py files, pyproject.toml,
#                 uv.lock, setup.cfg and mutation/, which a commit that only adds a
#                 waiver row to a report does not change), mode (full or changed),
#                 tool versions, mutmut's exit code; written last, so a missing
#                 run.txt means the run did not finish
# Why: mutmut keeps verdicts in mutants/ and does not reset them when a test
# changes (observed), so mutants/ is deleted before every run; and a mutant that
# timed out may only be slow, so each is run again with a longer limit, in a copy
# of the project (changing the limit in place would reset every timed-out verdict).
#
# Refuses (exit 2, nothing to judge): no pyproject.toml with [tool.mutmut];
# uncommitted or untracked changes; PYTEST_ADDOPTS set (it changes every test run);
# no mutmut on PATH, or not the pinned version (default 3.8.1); mutmut run exiting
# non-zero (a failing or uncollectable test, no test reaching any mutant); no
# mutant listed. With --changed-since, nothing changed is a finished run with an
# empty scope (mutmut refuses a name filter that matches nothing: observed).
# Exit 0 = the run finished (the verdict is check-python-mutation.sh's); 2 = no result.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import ast, fnmatch, hashlib, json, os, re, shutil, subprocess, sys, tempfile

def die(message):
    print(f"NO RESULT: {message}")
    sys.exit(2)

args = sys.argv[1:]
opts = {"--changed-since": "", "--out": "", "--mutmut-version": "3.8.1", "--recheck-multiplier": "60",
        "--max-children": ""}
root = None
while args:
    a = args.pop(0)
    if a in opts:
        if not args:
            die(f"{a} needs a value")
        opts[a] = args.pop(0)
    elif a.startswith("-") or root is not None:
        die(f"unknown argument: {a}")
    else:
        root = a
root = os.path.realpath(root or ".")
if not re.fullmatch(r"\d+\.\d+\.\d+", opts["--mutmut-version"]):
    die("--mutmut-version must be an exact version such as 3.8.1")
try:
    multiplier = float(opts["--recheck-multiplier"])
    assert multiplier > 0
except (ValueError, AssertionError):
    die("--recheck-multiplier must be a number above 0")
if opts["--max-children"] and not re.fullmatch(r"[1-9]\d*", opts["--max-children"]):
    die("--max-children must be a whole number above 0")
out = os.path.realpath(opts["--out"] or os.path.join(root, "mutation-out"))
pyproject = os.path.join(root, "pyproject.toml")
try:
    import tomllib
except ImportError:
    die("needs Python 3.11 or later (tomllib)")
try:
    with open(pyproject, "rb") as f:
        table = tomllib.load(f).get("tool", {}).get("mutmut")
except (OSError, ValueError) as exc:
    die(f"cannot read pyproject.toml: {exc}")
if not isinstance(table, dict):
    die("no [tool.mutmut] table in pyproject.toml")
if os.environ.get("PYTEST_ADDOPTS"):
    die("PYTEST_ADDOPTS is set; it changes every test mutmut runs: unset it")

def git(*a):
    r = subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True)
    if r.returncode != 0:
        die(f"git {' '.join(a)} failed: {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout

top = os.path.realpath(git("rev-parse", "--show-toplevel").strip())
pathspec = ["--", ".", ":(exclude)mutants"]
if out == root or out.startswith(root + os.sep):
    pathspec.append(":(exclude)" + os.path.relpath(out, root))
dirty = git("status", "--porcelain", *pathspec).strip()
if dirty:
    die("uncommitted or untracked changes; commit first so the result belongs to one commit:\n" + dirty)
commit = git("rev-parse", "HEAD").strip()
digest = hashlib.sha256()
for name in sorted(git("ls-files").splitlines()):
    if name.endswith(".py") or name in ("pyproject.toml", "uv.lock", "setup.cfg") or name.startswith("mutation/"):
        digest.update(name.encode() + b"\0" + open(os.path.join(root, name), "rb").read() + b"\0")
source_id = digest.hexdigest()[:16]

mutmut = shutil.which("mutmut")
if not mutmut:
    die(f"mutmut is not on PATH; run through the project's environment (uv run), pinned mutmut=={opts['--mutmut-version']}")
ver = subprocess.run([mutmut, "--version"], capture_output=True, text=True, cwd=root)
found = re.search(r"version\s+(\S+)", ver.stdout)
if not found:
    die(f"cannot read the mutmut version ({ver.stdout.strip() or ver.stderr.strip()})")
if found.group(1) != opts["--mutmut-version"]:
    die(f"mutmut is {found.group(1)}, pinned is {opts['--mutmut-version']}")
pyver = "unknown"
try:  # the interpreter mutmut runs under: its launcher names it on the first line or two
    head = open(mutmut, "rb").read(2048).decode(errors="replace")
    found_py = re.search(r"^#!\s*(\S*python[\d.]*)\b|^'''exec' '([^']*python[\d.]*)'", head, re.M)
    interp = (found_py.group(1) or found_py.group(2)) if found_py else ""
    if interp:
        pyver = subprocess.run([interp, "--version"], capture_output=True, text=True).stdout.strip() or "unknown"
except OSError:
    pass

# --- changed-code scope: the functions and methods changed since <ref> -----------
globs = []
if opts["--changed-since"]:
    ref = opts["--changed-since"]
    sources = table.get("source_paths") or ["src"]
    diff = git("-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false", "diff", "--unified=0",
               "--no-color", "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/", ref, "--",
               *sources)  # pathspecs are relative to the project; the +++ paths to the repository top
    changed, current = {}, None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else None
            if current and current.endswith(".py"):
                changed.setdefault(current, set())
            else:
                current = None
        elif line.startswith("@@") and current:
            m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
            start, count = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            changed[current].update(range(start, start + count) if count else (start, start + 1))
    for path, lines in sorted(changed.items()):
        full = os.path.join(top, path)
        rel = os.path.relpath(full, root).replace(os.sep, "/")
        module = rel[:-3].replace("/", ".")
        module = module[4:] if module.startswith("src.") else module
        module = module[:-9] if module.endswith(".__init__") else module
        try:
            tree = ast.parse(open(full, encoding="utf-8").read())
        except (OSError, SyntaxError) as exc:
            die(f"cannot read {rel}: {exc}")
        def span(node):
            first = min([node.lineno] + [d.lineno for d in node.decorator_list])
            return set(range(first, node.end_lineno + 1))
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and span(node) & lines:
                globs.append(f"{module}.x_{node.name}__mutmut_*")
            elif isinstance(node, ast.ClassDef):
                for item in node.body:
                    if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)) and span(item) & lines:
                        globs.append(f"{module}.xǁ{node.name}ǁ{item.name}__mutmut_*")

os.makedirs(out, exist_ok=True)
for name in ("mutmut.log", "results.txt", "recheck.txt", "show.txt", "typecheck.txt", "scope.txt", "run.txt"):
    try:
        os.remove(os.path.join(out, name))
    except FileNotFoundError:
        pass
shutil.rmtree(os.path.join(root, "mutants"), ignore_errors=True)

def mutmut_cmd(cwd, *a, log=None):
    p = subprocess.Popen([mutmut, *a], cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         errors="replace")
    text = []
    for line in p.stdout:
        text.append(line)
        if log:
            log.write(line)
    return p.wait(), "".join(text)

run_args = ["run"] + (["--max-children", opts["--max-children"]] if opts["--max-children"] else [])
code, nothing = 0, False
if opts["--changed-since"] and not globs:
    nothing = True
    print(f"Nothing changed since {opts['--changed-since']} in a function or method mutmut mutates.")
else:
    print("Running: mutmut " + " ".join(run_args + globs))
    with open(os.path.join(out, "mutmut.log"), "w") as log:
        code, text = mutmut_cmd(root, *(run_args + globs), log=log)
    if code != 0 and globs and "but nothing matches" in text:
        code, nothing = 0, True
        print("No mutant in the changed functions (mutmut refuses a filter that matches nothing).")
    if code != 0:
        tail = [l for l in text.replace("\r", "\n").splitlines() if l.strip()][-3:]
        die(f"mutmut run exited {code} (a failing or uncollectable test, coverage flags without --no-cov, or no "
            f"test reaching any mutant); see mutmut.log: {' / '.join(tail)}")

results = []
if os.path.isdir(os.path.join(root, "mutants")):
    rc, text = mutmut_cmd(root, "results", "--all", "true")
    if rc != 0:
        die(f"mutmut results exited {rc}")
    results = [l.strip() for l in text.splitlines() if re.fullmatch(r"\s*\S+__mutmut_\d+: .+", l)]
if not results and not nothing:
    die("mutmut listed no mutant")
with open(os.path.join(out, "results.txt"), "w") as f:
    f.write("".join(l + "\n" for l in results))
status = dict(l.split(": ", 1) for l in results)
in_scope = lambda n: not opts["--changed-since"] or any(fnmatch.fnmatchcase(n, g) for g in globs)

# --- recheck every timed-out mutant with a longer limit, in a copy --------------
timeouts = [n for n, s in status.items() if s == "timeout" and in_scope(n)]
recheck = []
if timeouts:
    print(f"Rechecking {len(timeouts)} timed-out mutants with timeout_multiplier {multiplier:g}...")
    work = tempfile.mkdtemp(prefix="python-mutation-recheck-")
    try:
        copy = os.path.join(work, "project")
        skip = {".git", ".venv", ".mypy_cache", ".pytest_cache", ".ruff_cache", "node_modules"}
        shutil.copytree(root, copy, symlinks=True, ignore=lambda d, names: [
            n for n in names if n in skip or os.path.join(d, n) == out])
        text = open(os.path.join(copy, "pyproject.toml"), encoding="utf-8").read()
        head, sep, rest = text.partition("[tool.mutmut]\n")
        rest = re.sub(r"(?m)^timeout_multiplier\s*=.*\n", "", rest, count=1)
        open(os.path.join(copy, "pyproject.toml"), "w", encoding="utf-8").write(
            head + sep + f"timeout_multiplier = {multiplier:g}\n" + rest)
        rc, text = mutmut_cmd(copy, *(run_args + timeouts))
        if rc != 0:
            die(f"the recheck run exited {rc}: {text.strip().splitlines()[-1:] if text.strip() else ''}")
        rc, text = mutmut_cmd(copy, "results", "--all", "true")
        again = dict(l.strip().split(": ", 1) for l in text.splitlines() if re.fullmatch(r"\s*\S+__mutmut_\d+: .+", l))
        for n in timeouts:
            recheck.append(f"{n} timeout -> {again.get(n, 'not checked')}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
with open(os.path.join(out, "recheck.txt"), "w") as f:
    f.write("".join(l + "\n" for l in recheck))
final = dict(status)
for l in recheck:
    n, _, s = l.partition(" timeout -> ")
    final[n] = s

# --- the diff of every mutant not killed, and type-checker messages -------------
with open(os.path.join(out, "show.txt"), "w") as f:
    for n, s in status.items():
        if final[n] != "killed" and in_scope(n):
            rc, text = mutmut_cmd(root, "show", n)
            if rc != 0:
                die(f"mutmut show {n} exited {rc}")
            f.write(text if text.endswith("\n") else text + "\n")
typed = []
for d, _, files in os.walk(os.path.join(root, "mutants")):
    for meta in files:
        if meta.endswith(".meta"):
            try:
                errors = json.load(open(os.path.join(d, meta))).get("type_check_error_by_key", {})
            except (OSError, ValueError):
                continue
            typed += [f"{k}: {' '.join(str(v).split())}" for k, v in errors.items() if status.get(k) == "caught by type check"]
with open(os.path.join(out, "typecheck.txt"), "w") as f:
    f.write("".join(l + "\n" for l in sorted(typed)))
if opts["--changed-since"]:
    with open(os.path.join(out, "scope.txt"), "w") as f:
        f.write("".join(g + "\n" for g in globs))
with open(os.path.join(out, "run.txt"), "w") as f:
    f.write(f"commit={commit}\nsource={source_id}\nmode={'changed' if opts['--changed-since'] else 'full'}\n"
            f"changed_since={opts['--changed-since']}\nmutmut={found.group(1)}\npython={pyver}\n"
            f"mutmut_exit={code}\nrecheck_multiplier={multiplier:g}\n")
counts = {}
for n in status:
    if in_scope(n):
        counts[final[n]] = counts.get(final[n], 0) + 1
print(f"Run finished for {commit[:12]} ({'changed since ' + opts['--changed-since'] if opts['--changed-since'] else 'whole project'}): "
      + (", ".join(f"{v} {k}" for k, v in sorted(counts.items())) or "no mutant in scope"))
print(f"Next: check-python-mutation.sh --commit {commit} --out {out} ...")
PY
