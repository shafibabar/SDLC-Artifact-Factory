#!/bin/bash
# run-go-mutation.sh [--diff <ref>] [--tags <tags>] [--out <dir>]
#                    [--gremlins-version <vX.Y.Z>] [--recheck-timeout <seconds>]
#                    [<module-dir>]
#
# Runs Gremlins once over a whole Go module at one clean commit, then checks
# what Gremlins cannot tell apart. It writes, in <out> (default
# <module-dir>/mutation-out):
#   gremlins.json  Gremlins' own per-mutant output (--output)
#   gremlins.log   Gremlins' console output
#   recheck.txt    one line per KILLED or TIMED OUT mutant:
#                  <file>:<line>:<col> <TYPE> <STATUS> -> <result>
#                  KILLED    -> compiles | rejected: <compiler message>
#                  TIMED OUT -> killed | lived | timed-out | rejected: <message>
#   run.txt        commit, source id (a hash of the tracked .go files, go.mod,
#                  go.sum, .gremlins.yaml and mutation/, which a commit that only
#                  adds a waiver row to a report does not change), mode (full or
#                  diff), diff ref, tool versions, Gremlins' exit code; written
#                  last, so a missing run.txt means the run did not finish
# Why the recheck: Gremlins v0.6.0 marks a mutant KILLED whenever `go test`
# exits 1, and a mutant that does not compile exits 1 too; and it times each
# mutant out at (coverage run time x coefficient), which on a fast module marks
# real survivors TIMED OUT. Each KILLED mutant is compiled on its own (go test
# -c); each TIMED OUT one is compiled and its package's tests are run again with
# --recheck-timeout seconds (default 120).
#
# Refuses (exit 2, nothing to judge): no go.mod or .gremlins.yaml; uncommitted
# or untracked changes; GREMLINS_* environment variables (they override the
# committed configuration); a Gremlins binary that is not the pinned version
# (default v0.6.0, read with `go version -m`); --diff when the module is not the
# repository root (Gremlins then skips every mutant). Gremlins is always given
# --config <module-dir>/.gremlins.yaml, because a user-level ~/.gremlins or
# /etc/gremlins file otherwise replaces the committed one, and never a path
# argument, so the whole module is planted and file names stay module-relative.
# Exit 0 = the run finished (the verdict is check-go-mutation.sh's);
#      2 = no result.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import os, re, shutil, signal, subprocess, sys, tempfile

def die(message):
    print(f"NO RESULT: {message}")
    sys.exit(2)

args = sys.argv[1:]
opts = {"--diff": "", "--tags": "", "--out": "", "--gremlins-version": "v0.6.0", "--recheck-timeout": "120"}
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
if not os.path.isfile(os.path.join(root, "go.mod")):
    die(f"no go.mod in {root}")
config = os.path.join(root, ".gremlins.yaml")
if not os.path.isfile(config):
    die("no .gremlins.yaml at the module root")
try:
    recheck_timeout = int(opts["--recheck-timeout"])
    assert recheck_timeout > 0
except (ValueError, AssertionError):
    die("--recheck-timeout must be a whole number of seconds above 0")
if not re.fullmatch(r"v\d+\.\d+\.\d+", opts["--gremlins-version"]):
    die("--gremlins-version must be an exact version such as v0.6.0")
out = os.path.realpath(opts["--out"] or os.path.join(root, "mutation-out"))

stray = sorted(k for k in os.environ if k.startswith("GREMLINS_"))
if stray:
    die("GREMLINS_* environment variables override .gremlins.yaml: unset " + ", ".join(stray))

def git(*a):
    r = subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True)
    if r.returncode != 0:
        die(f"git {' '.join(a)} failed: {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout.strip()

top = os.path.realpath(git("rev-parse", "--show-toplevel"))
if opts["--diff"] and top != root:
    die("--diff needs the module at the repository root: Gremlins compares repository paths "
        "with module paths, finds no match and skips every mutant")
pathspec = ["--", "."]
if out == root or out.startswith(root + os.sep):
    pathspec.append(":(exclude)" + os.path.relpath(out, root))
dirty = git("status", "--porcelain", *pathspec)
if dirty:
    die("uncommitted or untracked changes; commit first so the result belongs to one commit:\n" + dirty)
commit = git("rev-parse", "HEAD")
# The source id names what was judged: every tracked .go file, go.mod, go.sum,
# .gremlins.yaml and mutation/ (record, exclusions). A later commit that changes
# only reports (a waiver row, say) keeps the same source id.
import hashlib
digest = hashlib.sha256()
for name in sorted(git("ls-files").splitlines()):
    if name.endswith(".go") or name in ("go.mod", "go.sum", ".gremlins.yaml") or name.startswith("mutation/"):
        digest.update(name.encode() + b"\0" + open(os.path.join(root, name), "rb").read() + b"\0")
source_id = digest.hexdigest()[:16]

gremlins = shutil.which("gremlins")
if not gremlins:
    die("gremlins is not on PATH; install the pinned version: "
        f"go install github.com/go-gremlins/gremlins/cmd/gremlins@{opts['--gremlins-version']}")
info = subprocess.run(["go", "version", "-m", gremlins], capture_output=True, text=True)
found = re.search(r"^\s*mod\s+github\.com/go-gremlins/gremlins\s+(\S+)", info.stdout, re.M)
if not found:
    die(f"cannot read the Gremlins version from {gremlins} (go version -m)")
if found.group(1) != opts["--gremlins-version"]:
    die(f"Gremlins is {found.group(1)}, pinned is {opts['--gremlins-version']}")
go_version = subprocess.run(["go", "env", "GOVERSION"], capture_output=True, text=True).stdout.strip()

os.makedirs(out, exist_ok=True)
for name in ("gremlins.json", "gremlins.log", "recheck.txt", "run.txt"):
    try:
        os.remove(os.path.join(out, name))
    except FileNotFoundError:
        pass
report = os.path.join(out, "gremlins.json")
env = dict(os.environ)
# An uncached coverage run gives Gremlins a real time to scale its timeout from.
env["GOFLAGS"] = (env.get("GOFLAGS", "") + " -count=1").strip()
cmd = ["gremlins", "unleash", "--config", config, "--output", report]
if opts["--diff"]:
    cmd += ["--diff", opts["--diff"]]
    # Gremlins v0.6.0 reads each hunk's added lines as one block after the leading
    # context, so a changed line further down the hunk is SKIPPED (observed). Diffs
    # without context make every hunk one block; the other settings keep the format
    # its parser expects, whatever the user's Git configuration says.
    n = int(env.get("GIT_CONFIG_COUNT", "0") or "0")
    for key, value in (("diff.context", "0"), ("diff.noprefix", "false"),
                       ("diff.mnemonicPrefix", "false"), ("color.diff", "false")):
        env[f"GIT_CONFIG_KEY_{n}"], env[f"GIT_CONFIG_VALUE_{n}"] = key, value
        n += 1
    env["GIT_CONFIG_COUNT"] = str(n)
if opts["--tags"]:
    cmd += ["--tags", opts["--tags"]]
print("Running: " + " ".join(cmd))
with open(os.path.join(out, "gremlins.log"), "w") as log:
    proc = subprocess.Popen(cmd, cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        sys.stdout.write(line)
        log.write(line)
    code = proc.wait()
if code != 0:
    die(f"Gremlins exited {code} (10 or 11 means a threshold is set in .gremlins.yaml: set both to 0; "
        "1 means it failed, for example failing tests): see gremlins.log")
if not os.path.isfile(report) or os.path.getsize(report) == 0:
    die("Gremlins wrote no report (it writes none when it plants no mutant or is interrupted)")

import json
try:
    data = json.load(open(report))
    mutants = [(f["file_name"], m["line"], m["column"], m["type"], m["status"])
               for f in data["files"] for m in f["mutations"]]
except (ValueError, KeyError, TypeError) as exc:
    die(f"gremlins.json is not Gremlins' report: {exc}")

TEXT = {"ADD": "+", "SUB": "-", "MUL": "*", "QUO": "/", "REM": "%", "AND": "&", "OR": "|",
        "XOR": "^", "SHL": "<<", "SHR": ">>", "AND_NOT": "&^", "ADD_ASSIGN": "+=",
        "SUB_ASSIGN": "-=", "MUL_ASSIGN": "*=", "QUO_ASSIGN": "/=", "REM_ASSIGN": "%=",
        "AND_ASSIGN": "&=", "OR_ASSIGN": "|=", "XOR_ASSIGN": "^=", "SHL_ASSIGN": "<<=",
        "SHR_ASSIGN": ">>=", "AND_NOT_ASSIGN": "&^=", "LAND": "&&", "LOR": "||", "INC": "++",
        "DEC": "--", "EQL": "==", "NEQ": "!=", "LSS": "<", "GTR": ">", "LEQ": "<=", "GEQ": ">=",
        "ASSIGN": "=", "BREAK": "break", "CONTINUE": "continue"}
# Gremlins v0.6.0 internal/engine/mappings.go, tokenMutations.
SWAP = {
    "ARITHMETIC_BASE": {"ADD": "SUB", "MUL": "QUO", "QUO": "MUL", "REM": "MUL", "SUB": "ADD"},
    "CONDITIONALS_BOUNDARY": {"GEQ": "GTR", "GTR": "GEQ", "LEQ": "LSS", "LSS": "LEQ"},
    "CONDITIONALS_NEGATION": {"EQL": "NEQ", "GEQ": "LSS", "GTR": "LEQ", "LEQ": "GTR", "LSS": "GEQ", "NEQ": "EQL"},
    "INCREMENT_DECREMENT": {"DEC": "INC", "INC": "DEC"},
    "INVERT_ASSIGNMENTS": {"ADD_ASSIGN": "SUB_ASSIGN", "MUL_ASSIGN": "QUO_ASSIGN", "QUO_ASSIGN": "MUL_ASSIGN",
                           "REM_ASSIGN": "REM_ASSIGN", "SUB_ASSIGN": "ADD_ASSIGN"},
    "INVERT_BITWISE": {"AND": "OR", "OR": "AND", "XOR": "AND", "AND_NOT": "AND", "SHL": "SHR", "SHR": "SHL"},
    "INVERT_BWASSIGN": {"AND_ASSIGN": "OR_ASSIGN", "OR_ASSIGN": "AND_ASSIGN", "XOR_ASSIGN": "AND_ASSIGN",
                        "AND_NOT_ASSIGN": "AND_ASSIGN", "SHL_ASSIGN": "SHR_ASSIGN", "SHR_ASSIGN": "SHL_ASSIGN"},
    "INVERT_LOGICAL": {"LAND": "LOR", "LOR": "LAND"},
    "INVERT_LOOPCTRL": {"BREAK": "CONTINUE", "CONTINUE": "BREAK"},
    "INVERT_NEGATIVES": {"SUB": "ADD"},
    "REMOVE_SELF_ASSIGNMENTS": {k: "ASSIGN" for k in ("ADD_ASSIGN", "AND_ASSIGN", "AND_NOT_ASSIGN", "MUL_ASSIGN",
                                "OR_ASSIGN", "QUO_ASSIGN", "REM_ASSIGN", "SHL_ASSIGN", "SHR_ASSIGN",
                                "SUB_ASSIGN", "XOR_ASSIGN")},
}
OPERATORS = sorted({t for t in TEXT.values() if not t.isalpha()}, key=len, reverse=True)

def mutate(src, line, col, mtype):
    """Return src (bytes) with the mutation applied, as Gremlins applies it."""
    lines = src.split(b"\n")
    if mtype not in SWAP or not 1 <= line <= len(lines):
        return None
    row = lines[line - 1]
    at = col - 1
    word = re.match(rb"[A-Za-z_]+", row[at:])
    actual = word.group(0).decode() if word else next(
        (op for op in OPERATORS if row[at:at + len(op)] == op.encode()), None)
    key = next((k for k, v in TEXT.items() if v == actual), None)
    if key not in SWAP[mtype]:
        return None
    lines[line - 1] = row[:at] + TEXT[SWAP[mtype][key]].encode() + row[at + len(actual):]
    return b"\n".join(lines)

def run(cmd, cwd, timeout):
    p = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         start_new_session=True)
    try:
        output, _ = p.communicate(timeout=timeout)
        return p.returncode, output.decode(errors="replace")
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
        p.communicate()
        return None, ""

tags = ["-tags", opts["--tags"]] if opts["--tags"] else []
work = tempfile.mkdtemp(prefix="go-mutation-recheck-")
# A go command killed at the recheck timeout cannot remove its build folder; keep
# those folders inside this run's temporary folder, which is removed at the end.
os.makedirs(os.path.join(work, "gotmp"))
env["GOTMPDIR"] = os.path.join(work, "gotmp")
lines = []
try:
    copy = os.path.join(work, "module")
    shutil.copytree(root, copy, symlinks=True,
                    ignore=lambda d, names: [n for n in names if n == ".git" or os.path.join(d, n) == out])
    todo = [m for m in mutants if m[4] in ("KILLED", "TIMED OUT")]
    if todo:
        print(f"Rechecking {len(todo)} KILLED or TIMED OUT mutants one by one...")
    for name, line, col, mtype, status in todo:
        path = os.path.join(copy, name)
        try:
            original = open(path, "rb").read()
        except OSError:
            die(f"{name}: not in the module; the report is not from this module")
        mutated = mutate(original, line, col, mtype)
        if mutated is None:
            die(f"{name}:{line}:{col}: no {mtype} operator at that position; the report does not match the source")
        pkg = "./" + (os.path.dirname(name) or ".")
        try:
            open(path, "wb").write(mutated)
            rc, text = run(["go", "test", "-c", "-o", os.path.join(work, "mutant.test")] + tags + [pkg],
                           copy, recheck_timeout)
            if rc is None:
                result = "timed-out" if status == "TIMED OUT" else "rejected: compile timed out"
            elif rc != 0:
                msg = next((l.strip() for l in text.splitlines() if re.search(r"\.go:\d+:\d+: ", l)),
                           text.strip().splitlines()[-1] if text.strip() else "build failed")
                result = "rejected: " + msg.replace(copy + os.sep, "")
            elif status == "KILLED":
                result = "compiles"
            else:
                rc, _ = run(["go", "test", "-count=1", "-failfast", "-timeout=0"] + tags + [pkg],
                            copy, recheck_timeout)
                result = "timed-out" if rc is None else ("lived" if rc == 0 else "killed")
        finally:
            open(path, "wb").write(original)
        lines.append(f"{name}:{line}:{col} {mtype} {status} -> {result}")
finally:
    shutil.rmtree(work, ignore_errors=True)

with open(os.path.join(out, "recheck.txt"), "w") as f:
    f.write("".join(l + "\n" for l in lines))
with open(os.path.join(out, "run.txt"), "w") as f:
    f.write(f"commit={commit}\nsource={source_id}\nmode={'diff' if opts['--diff'] else 'full'}\ndiff_ref={opts['--diff']}\n"
            f"gremlins={found.group(1)}\ngo={go_version}\ngremlins_exit={code}\ntags={opts['--tags']}\n"
            f"recheck_timeout={recheck_timeout}\n")
counts = {}
for l in lines:
    counts[l.split(" -> ")[1].split(":")[0]] = counts.get(l.split(" -> ")[1].split(":")[0], 0) + 1
print(f"Run finished for {commit[:12]} ({'diff against ' + opts['--diff'] if opts['--diff'] else 'whole module'}); "
      f"recheck: " + (", ".join(f"{v} {k}" for k, v in sorted(counts.items())) or "nothing to recheck"))
print(f"Next: check-go-mutation.sh --commit {commit} --out {out} ...")
PY
