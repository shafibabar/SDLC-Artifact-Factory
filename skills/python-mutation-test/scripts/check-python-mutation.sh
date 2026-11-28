#!/bin/bash
# check-python-mutation.sh --mode release|scheduled --commit <sha>
#                          [--record <file>] [--exclusions <file>]... [--waiver <file>]
#                          [--out <dir>] [<project-dir>]
#
# The verdict on one mutmut run, by decision D048 (never by mutmut's own counts
# or badge): every planted mutant is killed by a test, or recorded individually
# with the reason it cannot be. Reads, from <out> (default
# <project-dir>/mutation-out), what run-python-mutation.sh wrote: run.txt,
# results.txt, recheck.txt, show.txt, typecheck.txt and, for a changed-code run,
# scope.txt; reads pyproject.toml and the source for what was left out.
#
# Each planted mutant (mutmut status) is one of:
#   killed       killed; timeout that the longer recheck killed
#   recordable   survived (or timeout that survived the recheck): kill it with a
#                test, or record it as `equivalent` if no input can tell it apart;
#                timeout that timed out again: record as `timeout`;
#                caught by type check: record as `not-viable`.
#                A record counts only when it matches.
#   not covered  no tests: no test reaches the function. Never recordable: write
#                the test, or list an approved exclusion.
#   no result    suspicious, segfault, check was interrupted by user, skipped, not
#                checked (in scope), an unknown status: the run gives no verdict.
# Left out and listed: files with a generated-code marker in their leading
# comments, approved file/folder exclusions; test support under tests/ is never
# mutated and is listed. Exclusions (--exclusions), one per line:
#   <path> | file|folder|lines <fingerprint> | approved YYYY-MM-DD | <reason>
# (`pending` in place of the approval is refused). A `# pragma: no mutate`, a
# do_not_mutate_patterns match, a do_not_mutate or only_mutate setting, or code
# under src/ outside source_paths hides mutants: each needs an approved entry.
# Record lines (--record), one per mutant:
#   <mutant name> | equivalent|timeout|not-viable | <fingerprint> | <reason> | <who> <YYYY-MM-DD>
# The fingerprint is a hash of the mutant's `mutmut show` diff, printed by this
# script for every unrecorded mutant; a record still matches when the mutant's
# number changed within its function, not when the diff changed.
#
# Result = (killed + recorded) / planted, as counts. Verdicts:
#   PASS           every planted mutant killed or recorded           exit 0
#   WAIVER-NEEDED  more than 90% and under 100%, no matching waiver   exit 3
#                  (with a waiver row for this run and these counts:
#                  PASS, waived)                                      exit 0
#   FAIL           90% or below (no waiver possible), or a stale or   exit 1
#                  wrong record line (never waivable)
#   INVALID        missing, empty or unreadable output; another commit;
#                  mutmut failed; a release run that was not full; a no-result
#                  status; hidden code without approval; a malformed record
#                  or exclusion                                       exit 2
# Waiver rows are read from --waiver (a Markdown file holding the table
# | Measure | Language | Run | Measured | Product owner comments | Reviewed on |),
# row `mutation | python | <run> | <caught>/<planted> | ...`, where <run> names
# this run's commit or source id (run.txt), at least 7 hex characters.
# --mode scheduled reports only: PASS, FAIL and WAIVER-NEEDED exit 0, INVALID 2,
# and no waiver is applied.
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, fnmatch, hashlib, os, re, sys

def invalid(message):
    print(f"INVALID: {message}")
    print("Verdict: INVALID (nothing is judged; fix the run and run again)")
    sys.exit(2)

args = sys.argv[1:]
opts = {"--mode": "", "--commit": "", "--record": "", "--waiver": "", "--out": ""}
exclusion_files, root = [], None
while args:
    a = args.pop(0)
    if a == "--exclusions" and args:
        exclusion_files.append(args.pop(0))
    elif a in opts and args:
        opts[a] = args.pop(0)
    elif a.startswith("-") or root is not None:
        invalid(f"unknown or incomplete argument: {a}")
    else:
        root = a
mode = opts["--mode"]
if mode not in ("release", "scheduled"):
    invalid("--mode must be release or scheduled")
if not re.fullmatch(r"[0-9a-f]{7,40}", opts["--commit"]):
    invalid("--commit must be the commit being judged (git rev-parse HEAD)")
root = os.path.realpath(root or ".")
out = os.path.realpath(opts["--out"] or os.path.join(root, "mutation-out"))

def read(path, what):
    try:
        return open(path, encoding="utf-8").read()
    except OSError:
        invalid(f"{what} is missing: {path}")

run = dict(l.split("=", 1) for l in read(os.path.join(out, "run.txt"), "run.txt (the run did not finish)").splitlines() if "=" in l)
for key in ("commit", "mode", "mutmut", "mutmut_exit"):
    if key not in run:
        invalid(f"run.txt has no {key}")
if not run["commit"].startswith(opts["--commit"]) and not opts["--commit"].startswith(run["commit"]):
    invalid(f"the run is of commit {run['commit'][:12]}, not {opts['--commit'][:12]}")
if run["mutmut_exit"] != "0":
    invalid(f"mutmut run exited {run['mutmut_exit']}")
if mode == "release" and run["mode"] != "full":
    invalid("a release run covers the whole project; this run was changed-code only, since " + run.get("changed_since", "?"))

try:
    import tomllib
    with open(os.path.join(root, "pyproject.toml"), "rb") as f:
        cfg = tomllib.load(f).get("tool", {}).get("mutmut", {})
except ImportError:
    invalid("needs Python 3.11 or later (tomllib)")
except (OSError, ValueError) as exc:
    invalid(f"cannot read pyproject.toml: {exc}")

results = {}
for l in read(os.path.join(out, "results.txt"), "results.txt").splitlines():
    m = re.fullmatch(r"\s*(\S+__mutmut_\d+): (.+?)\s*", l)
    if not m:
        invalid(f"results.txt line not understood: {l}")
    results[m.group(1)] = m.group(2)
scope = None
if run["mode"] == "changed":
    scope = [g for g in read(os.path.join(out, "scope.txt"), "scope.txt").splitlines() if g.strip()]
if not results and scope is None:
    invalid("results.txt lists no mutant")
recheck = {}
for l in read(os.path.join(out, "recheck.txt"), "recheck.txt").splitlines():
    m = re.fullmatch(r"(\S+__mutmut_\d+) timeout -> (.+)", l)
    if not m:
        invalid(f"recheck.txt line not understood: {l}")
    recheck[m.group(1)] = m.group(2)
shows, current = {}, None
for l in read(os.path.join(out, "show.txt"), "show.txt").splitlines():
    m = re.fullmatch(r"# (\S+__mutmut_\d+): .+", l)
    if m:
        current = m.group(1)
        shows[current] = []
    elif current:
        shows[current].append(l)
typecheck = {}
for l in (open(os.path.join(out, "typecheck.txt"), encoding="utf-8").read().splitlines()
          if os.path.isfile(os.path.join(out, "typecheck.txt")) else []):
    name, _, msg = l.partition(": ")
    typecheck[name] = msg

def fingerprint(name):
    if name not in shows:
        invalid(f"show.txt has no diff for {name}")
    body = "\n".join(l for l in shows[name] if not l.startswith("@@"))
    return hashlib.sha256(body.encode()).hexdigest()[:12]

def function(name):
    return name.rsplit("__mutmut_", 1)[0]

def module_file(name):
    parts = function(name).split(".")
    module = "/".join(parts[:-1])
    for c in (f"src/{module}.py", f"{module}.py", f"src/{module}/__init__.py", f"{module}/__init__.py"):
        if os.path.isfile(os.path.join(root, c)):
            return c
    return f"src/{module}.py"

GENERATED = re.compile(r"@generated|generated.*do not edit|do not edit.*generated", re.I)
def generated(path):
    try:
        for line in open(os.path.join(root, path), encoding="utf-8", errors="replace"):
            s = line.strip()
            if not s:
                continue
            if not s.startswith("#"):
                return False
            if GENERATED.search(s):
                return True
    except OSError:
        pass
    return False

# --- exclusions, and code hidden from mutmut ----------------------------------------
approved, lines_ok = [], set()
for path in exclusion_files:
    for l in read(path, "exclusions file").splitlines():
        if not l.strip() or l.lstrip().startswith("#"):
            continue
        p = [x.strip() for x in l.split("|")]
        ok = (len(p) == 4 and p[0] and len(p[3]) >= 10 and re.fullmatch(r"file|folder|lines [0-9a-f]{12}", p[1])
              and re.fullmatch(r"approved \d{4}-\d{2}-\d{2}", p[2]))
        if ok:
            try:
                datetime.date.fromisoformat(p[2][9:])
            except ValueError:
                ok = False
        if not ok:
            invalid(f"exclusion not approved or malformed (<path> | file|folder|lines <fingerprint> | approved YYYY-MM-DD | <reason>): {l}")
        if p[1].startswith("lines"):
            lines_ok.add((p[0], p[1][6:]))
        else:
            approved.append((p[0].rstrip("/") + ("/" if p[1] == "folder" else ""), p[3]))

def excluded(path):
    for where, reason in approved:
        if path == where or (where.endswith("/") and path.startswith(where)):
            return where, reason
    return None

def line_fp(text):
    return hashlib.sha256(text.strip().encode()).hexdigest()[:12]

sources = [s.rstrip("/") for s in (cfg.get("source_paths") or cfg.get("paths_to_mutate") or ["src"])]
if isinstance(cfg.get("paths_to_mutate"), str) or isinstance(cfg.get("tests_dir"), str):
    invalid("paths_to_mutate or tests_dir given as a string: mutmut 3 expects lists (deprecated keys; use source_paths)")
product = []
for base in ["src"] if os.path.isdir(os.path.join(root, "src")) else sources:
    for d, dirs, files in os.walk(os.path.join(root, base)):
        dirs[:] = sorted(x for x in dirs if not x.startswith(".") and x != "__pycache__")
        product += [os.path.relpath(os.path.join(d, f), root).replace(os.sep, "/") for f in sorted(files) if f.endswith(".py")]
hidden, left_out = [], {"generated": set(), "approved": {}, "lines": []}
only, never = cfg.get("only_mutate") or [], cfg.get("do_not_mutate") or []
patterns = [re.compile(p) for p in (cfg.get("do_not_mutate_patterns") or [])]
if cfg.get("mutate_only_covered_lines"):
    hidden.append("mutate_only_covered_lines = true leaves out every line coverage excludes")
for path in product:
    if generated(path):
        left_out["generated"].add(path)
        continue
    body = open(os.path.join(root, path), encoding="utf-8", errors="replace").read()
    if not re.search(r"^\s*(async\s+)?def\s", body, re.M):
        continue  # no function or method: mutmut plants nothing in it
    why = None
    if not any(path == s or path.startswith(s + "/") for s in sources):
        why = "outside source_paths"
    elif only and not any(fnmatch.fnmatch(path, p) for p in only):
        why = "not matched by only_mutate"
    elif any(fnmatch.fnmatch(path, p) for p in never):
        why = "matched by do_not_mutate"
    if why:
        hit = excluded(path)
        if hit:
            left_out["approved"][hit[0]] = hit[1]
        else:
            hidden.append(f"{path} is {why}, with no approved exclusion")
        continue
    for n, text in enumerate(body.splitlines(), 1):
        if re.search(r"#\s*pragma:.*no mutate", text) or any(p.search(text) for p in patterns):
            fp = line_fp(text)
            if (path, fp) in lines_ok:
                left_out["lines"].append(f"{path}:{n}")
            else:
                hidden.append(f"{path}:{n} is not mutated (pragma or do_not_mutate_patterns), with no approved "
                              f"exclusion; to propose one: {path} | lines {fp} | pending | <reason>")
if hidden:
    for h in hidden:
        print(f"Hidden from mutation: {h}")
    invalid("code is left out of mutation without the product owner's approval")

# --- the record -----------------------------------------------------------------------
KINDS = ("equivalent", "timeout", "not-viable")
records = []
if opts["--record"]:
    for n, l in enumerate(read(opts["--record"], "record file").splitlines(), 1):
        if not l.strip() or l.lstrip().startswith("#"):
            continue
        p = [x.strip() for x in l.split("|")]
        who = re.fullmatch(r"(.+) (\d{4}-\d{2}-\d{2})", p[4]) if len(p) == 5 else None
        if (len(p) != 5 or not re.fullmatch(r"\S+__mutmut_\d+", p[0]) or p[1] not in KINDS
                or not re.fullmatch(r"[0-9a-f]{12}", p[2]) or not who):
            invalid(f"record line {n} malformed (<mutant name> | {'|'.join(KINDS)} | <fingerprint> | "
                    f"<reason> | <who> <YYYY-MM-DD>): {l}")
        if len(p[3]) < 10 or p[3].lower().startswith(("<", "todo", "tbd", "equivalent", "n/a", "none")):
            invalid(f"record line {n} gives no reason: {l}")
        records.append({"n": n, "name": p[0], "kind": p[1], "fp": p[2], "reason": p[3], "used": False})

def in_scope(name):
    return scope is None or any(fnmatch.fnmatchcase(name, g) for g in scope)

NO_RESULT = ("suspicious", "segfault", "check was interrupted by user")
planted, skipped = [], 0
for name, status in sorted(results.items()):
    if not in_scope(name):
        skipped += 1
        continue
    if status in NO_RESULT:
        invalid(f"{name} is '{status}': fix the cause and run again; it can never be recorded")
    if status in ("not checked", "skipped"):
        invalid(f"{name} is '{status}': the run did not test it")
    if status not in ("killed", "survived", "timeout", "caught by type check", "no tests"):
        invalid(f"{name} has a status this script does not know: '{status}'")
    path = module_file(name)
    if generated(path):
        left_out["generated"].add(path)
        continue
    hit = excluded(path)
    if hit:
        left_out["approved"][hit[0]] = hit[1]
        continue
    planted.append((name, status))

def classify(name, status):
    if status == "no tests":
        return "not covered", "no tests"
    if status == "survived":
        return "equivalent", "survived"
    if status == "caught by type check":
        return "not-viable", "caught by type check" + (f" ({typecheck[name]})" if name in typecheck else "")
    if status == "killed":
        return "killed", "killed"
    again = recheck.get(name)
    if again is None:
        invalid(f"{name} timed out and has no recheck line")
    if again in NO_RESULT or again in ("not checked", "skipped", "no tests"):
        invalid(f"{name} timed out, and the recheck gave '{again}'")
    return {"killed": ("killed", "timeout, killed on the longer recheck"),
            "survived": ("equivalent", "timeout, survived the longer recheck"),
            "timeout": ("timeout", "timeout, timed out again on the longer recheck"),
            "caught by type check": ("not-viable", "timeout, caught by type check on recheck")}.get(again) or invalid(
            f"{name}: recheck status '{again}' not understood")

def match(name):
    fp = fingerprint(name)
    hits = [r for r in records if not r["used"] and r["fp"] == fp and function(r["name"]) == function(name)]
    same = [r for r in hits if r["name"] == name]
    pick = same[0] if same else (hits[0] if len(hits) == 1 else None)
    if pick:
        pick["used"] = True
    return pick, fp

killed, recorded, uncaught, renamed, wrong_kind, recorded_rows = 0, {k: 0 for k in KINDS}, [], [], [], []
for name, status in planted:
    kind, why = classify(name, status)
    if kind == "killed":
        killed += 1
        continue
    if kind == "not covered":
        uncaught.append((name, why, kind, None))
        continue
    rec, fp = match(name)
    if rec and rec["kind"] != kind:
        wrong_kind.append(f"record line {rec['n']} says {rec['kind']}, the mutant is {why}: {kind}")
        rec = None
    if rec:
        recorded[kind] += 1
        recorded_rows.append(f"{name} | {kind} | {rec['reason']}")
        if rec["name"] != name:
            renamed.append(f"record line {rec['n']}: {rec['name']} is now {name}")
        continue
    uncaught.append((name, why, kind, f"{name} | {kind} | {fp} | <the reason, after checking> | "
                                       f"<who> {datetime.date.today().isoformat()}"))

stale = [r for r in records if not r["used"] and in_scope(r["name"])]
test_support = []
for d, dirs, files in os.walk(os.path.join(root, "tests")):
    dirs[:] = sorted(x for x in dirs if not x.startswith(".") and x != "__pycache__")
    test_support += [os.path.relpath(os.path.join(d, f), root).replace(os.sep, "/") for f in sorted(files)
                     if f.endswith(".py") and not re.fullmatch(r"test_.*\.py|.*_test\.py|__init__\.py", f)]

total = len(planted)
caught = killed + sum(recorded.values())
print(f"Python mutation check (D048): {mode} run of commit {run['commit'][:12]} (source {run.get('source', '?')}), "
      f"mutmut {run['mutmut']}, {run.get('python', '?')}")
if mode == "scheduled":
    print(f"Report only: blocks nothing. {'Changed code since ' + run.get('changed_since', '') if scope is not None else 'Whole project'}; "
          f"{skipped} mutants outside it were not tested.")
print(f"Planted: {total}")
print(f"Killed by a test: {killed}")
print(f"Recorded: {sum(recorded.values())} (equivalent {recorded['equivalent']}, timeout {recorded['timeout']}, "
      f"not-viable {recorded['not-viable']})")
for row in recorded_rows:
    print(f"  {row}")
print(f"Not caught: {len(uncaught)}")
ACTION = {"not covered": "no test reaches it: write one, or list an approved exclusion",
          "equivalent": "write the test that kills it; record it as equivalent only if no input can tell it apart",
          "timeout": "check that the mutated code never finishes, then record it",
          "not-viable": "the type checker rejects it: check that, then record it"}
for name, why, kind, _ in uncaught:
    print(f"  {name}: {why}; {ACTION[kind]}")
for label, items in (("Generated code (left out)", sorted(left_out["generated"])),
                     ("Test support under tests/ (approved class, never mutated)", test_support),
                     ("Approved exclusions (left out)", [f"{k}: {v}" for k, v in sorted(left_out["approved"].items())]),
                     ("Approved lines not mutated", left_out["lines"])):
    print(f"{label}: {', '.join(items) if items else 'none'}")
for note in renamed:
    print(f"Renamed: {note}; update the record")
problems = wrong_kind + [f"record line {r['n']} matches no planted mutant ({r['name']}, fingerprint {r['fp']}): "
                         f"the code changed or the mutant is now killed; re-check it or remove it" for r in stale]
for p in problems:
    print(f"Stale record: {p}")
print(f"Result: {caught}/{total} caught (killed {killed} + recorded {sum(recorded.values())})")

if total == 0 and mode == "release":
    invalid("no mutant was planted outside generated code and approved exclusions")
if caught == total and not problems:
    verdict, code = "PASS", 0
elif caught * 10 > total * 9 and caught < total and not problems:
    verdict, code = "WAIVER-NEEDED", 3
    if mode == "release" and opts["--waiver"]:
        for l in read(opts["--waiver"], "waiver file").splitlines():
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if len(cells) != 6 or cells[0].lower() != "mutation" or cells[1].lower() != "python":
                continue
            run_ok = any(len(t) >= 7 and (run["commit"].startswith(t) or run.get("source", "-").startswith(t))
                         for t in re.findall(r"[0-9a-f]{7,40}", cells[2]))
            measured_ok = re.sub(r"\s", "", cells[3]) == f"{caught}/{total}"
            comments_ok = len(cells[4]) >= 10 and cells[4].lower() not in ("none", "n/a", "pending", "ok")
            try:
                date_ok = bool(datetime.date.fromisoformat(cells[5]))
            except ValueError:
                date_ok = False
            if run_ok and measured_ok and comments_ok and date_ok:
                verdict, code = f"PASS (waived by the product owner on {cells[5]})", 0
                break
            print(f"Waiver row not accepted (it must name this run's commit or source id, {caught}/{total}, "
                  f"the product owner's comments and a review date): {l.strip()}")
else:
    verdict, code = "FAIL", 1
    if problems:
        print("A stale or wrong record line fails the run whatever the counts; it cannot be waived.")
    elif mode == "scheduled":
        print("A scheduled run is never waived; fix it before the release run.")
    elif caught * 10 <= total * 9:
        print("90% or below: no waiver is possible" + (", so the waiver file was not read." if opts["--waiver"] else "."))
if code == 3 and mode == "release":
    print(f"More than 90%: the product owner may waive the remaining {total - caught} after reviewing them; "
          f"add the row | mutation | python | source {run.get('source', run['commit'][:12])} | {caught}/{total} | "
          f"<comments> | <YYYY-MM-DD> | (the source id stays the same when only the report changes)")
unrecorded = [u[3] for u in uncaught if u[3]]
if unrecorded:
    print("To record a mutant you have checked (only if no input can make it behave differently, or it never "
          "finishes, or the type checker rejects it), copy its line into the record and write the reason:")
    for u in unrecorded:
        print(f"  {u}")
print(f"Verdict: {verdict}")
if mode == "scheduled" and code != 2:
    code = 0
sys.exit(code)
PY
