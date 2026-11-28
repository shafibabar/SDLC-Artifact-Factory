#!/bin/bash
# check-go-mutation.sh --mode release|scheduled --commit <sha>
#                      [--record <file>] [--exclusions <file>]... [--waiver <file>]
#                      [--out <dir>] [<module-dir>]
#
# The verdict on one mutation run, by decision D048 (never by Gremlins' own
# scores): every planted mutant is killed by a test, or recorded individually
# with the reason it cannot be. Reads, from <out> (default
# <module-dir>/mutation-out), what run-go-mutation.sh wrote: run.txt,
# gremlins.json and recheck.txt; reads the source files for the fingerprints.
#
# Each planted mutant is one of:
#   killed       KILLED that compiles; TIMED OUT whose recheck failed a test
#   recordable   LIVED (or TIMED OUT that lived on recheck): kill it with a test,
#                or record it as `equivalent` if no input can tell it apart;
#                TIMED OUT that timed out again: record as `timeout`;
#                NOT VIABLE, or KILLED/TIMED OUT that does not compile: record
#                as `not-viable`. A record counts only when it matches.
#   not covered  NOT COVERED: no test of its own package runs that line. Never
#                recordable: write the test, or list an approved exclusion.
# Left out and listed: files with the generated-code marker (or named _moq.go),
# test support under internal/test/, and approved --exclusions entries
#   <path or folder/> | approved YYYY-MM-DD | <reason>     (pending is refused).
# Record lines (--record), one per mutant:
#   <file>:<line>:<col> | <TYPE> | equivalent|timeout|not-viable | <fingerprint> | <reason> | <who> <YYYY-MM-DD>
# The fingerprint is printed by this script for every unrecorded mutant; a
# record still matches when its line moved, not when the line's code changed.
#
# Result = (killed + recorded) / planted, as counts. Verdicts:
#   PASS           every planted mutant killed or recorded           exit 0
#   WAIVER-NEEDED  more than 90% and under 100%, no matching waiver   exit 3
#                  (with a waiver row for this run and these counts:
#                  PASS, waived)                                      exit 0
#   FAIL           90% or below (no waiver possible), or a stale record exit 1
#   INVALID        missing, empty or unreadable output; another commit;
#                  Gremlins failed; a release run that was not full;
#                  a malformed record or exclusion                    exit 2
# Waiver rows are read from --waiver (a Markdown file holding the table
# | Measure | Language | Run | Measured | Product owner comments | Reviewed on |),
# row `mutation | go | <run> | <caught>/<planted> | ...`, where <run> names this
# run's commit or its source id (run.txt), at least 7 hex characters.
# --mode scheduled reports only: PASS, FAIL and WAIVER-NEEDED exit 0, INVALID 2,
# and no waiver is applied (a partial run is never waived).
set -uo pipefail
exec python3 -I - "$@" <<'PY'
import datetime, hashlib, json, os, re, sys

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
for key in ("commit", "mode", "gremlins", "gremlins_exit"):
    if key not in run:
        invalid(f"run.txt has no {key}")
if not run["commit"].startswith(opts["--commit"]) and not opts["--commit"].startswith(run["commit"]):
    invalid(f"the run is of commit {run['commit'][:12]}, not {opts['--commit'][:12]}")
if run["gremlins_exit"] != "0":
    invalid(f"Gremlins exited {run['gremlins_exit']}")
if mode == "release" and run["mode"] != "full":
    invalid("a release run covers the whole module; this run was --diff " + run.get("diff_ref", ""))

text = read(os.path.join(out, "gremlins.json"), "gremlins.json")
if not text.strip():
    invalid("gremlins.json is empty")
try:
    data = json.loads(text)
    planted_raw = [(f["file_name"], int(m["line"]), int(m["column"]), m["type"], m["status"])
                   for f in data["files"] for m in f["mutations"]]
except (ValueError, KeyError, TypeError) as exc:
    invalid(f"gremlins.json is not Gremlins' report: {exc}")
if not planted_raw:
    invalid("gremlins.json lists no mutant")
gomod = read(os.path.join(root, "go.mod"), "go.mod")
module = re.search(r"^module\s+\"?([^\s\"]+)", gomod, re.M)
if not module or data.get("go_module") != module.group(1):
    invalid(f"gremlins.json is for module {data.get('go_module')}, not {module.group(1) if module else '?'}")

recheck = {}
for l in read(os.path.join(out, "recheck.txt"), "recheck.txt").splitlines():
    m = re.fullmatch(r"(\S+):(\d+):(\d+) (\S+) (KILLED|TIMED OUT) -> (compiles|killed|lived|timed-out|rejected: .*)", l)
    if not m:
        invalid(f"recheck.txt line not understood: {l}")
    recheck[(m.group(1), int(m.group(2)), int(m.group(3)), m.group(4))] = m.group(6)

GENERATED = re.compile(r"^// Code generated .* DO NOT EDIT\.$")
sources = {}
def source(name):
    if name not in sources:
        try:
            sources[name] = open(os.path.join(root, name), encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            invalid(f"{name} is in the report but not in the module: check out the judged commit")
    return sources[name]

def generated(name):
    if name.endswith("_moq.go"):
        return True
    for line in source(name):
        if GENERATED.match(line):
            return True
        if line.startswith("package "):
            return False
    return False

def fingerprint(name, line):
    rows = source(name)
    text = rows[line - 1].strip() if 1 <= line <= len(rows) else ""
    return hashlib.sha256(text.encode()).hexdigest()[:12]

approved = []
for path in exclusion_files:
    for l in read(path, "exclusions file").splitlines():
        if not l.strip() or l.lstrip().startswith("#"):
            continue
        parts = [p.strip() for p in l.split("|")]
        ok = len(parts) == 3 and parts[0] and parts[2] and re.fullmatch(r"approved \d{4}-\d{2}-\d{2}", parts[1])
        if ok:
            try:
                datetime.date.fromisoformat(parts[1][9:])
            except ValueError:
                ok = False
        if not ok:
            invalid(f"exclusion not approved or malformed (<path> | approved YYYY-MM-DD | <reason>): {l}")
        approved.append((parts[0], parts[2]))

def excluded(name):
    for path, reason in approved:
        if name == path or (path.endswith("/") and name.startswith(path)):
            return path, reason
    return None

KINDS = ("equivalent", "timeout", "not-viable")
records = []
if opts["--record"]:
    for n, l in enumerate(read(opts["--record"], "record file").splitlines(), 1):
        if not l.strip() or l.lstrip().startswith("#"):
            continue
        p = [x.strip() for x in l.split("|")]
        m = re.fullmatch(r"(\S+):(\d+):(\d+)", p[0]) if len(p) == 6 else None
        who = re.fullmatch(r"(.+) (\d{4}-\d{2}-\d{2})", p[5]) if len(p) == 6 else None
        if not m or not who or p[2] not in KINDS or not re.fullmatch(r"[0-9a-f]{12}", p[3]):
            invalid(f"record line {n} malformed (<file>:<line>:<col> | <TYPE> | {'|'.join(KINDS)} | "
                    f"<fingerprint> | <reason> | <who> <YYYY-MM-DD>): {l}")
        if len(p[4]) < 10 or p[4].lower().startswith(("<", "todo", "tbd", "equivalent", "n/a", "none")):
            invalid(f"record line {n} gives no reason: {l}")
        records.append({"n": n, "file": m.group(1), "line": int(m.group(2)), "col": int(m.group(3)),
                        "type": p[1], "kind": p[2], "fp": p[3], "reason": p[4], "used": False})

left_out = {"generated": set(), "test support": set(), "approved": {}}
# Listed whether or not Gremlins planted anything in them (exclude-files may have
# kept them out): every report names the generated code and the test support.
for d, dirs, files in os.walk(root):
    dirs[:] = [x for x in dirs if not x.startswith(".") and x not in ("vendor", "testdata")
               and os.path.join(d, x) != out]
    for f in files:
        if f.endswith(".go") and not f.endswith("_test.go"):
            name = os.path.relpath(os.path.join(d, f), root).replace(os.sep, "/")
            if name.startswith("internal/test/"):
                left_out["test support"].add(name)
            elif generated(name):
                left_out["generated"].add(name)
planted, skipped = [], 0
for name, line, col, mtype, status in planted_raw:
    if status == "RUNNABLE":
        invalid("RUNNABLE mutants: this is a dry run, nothing was tested")
    if status == "SKIPPED":
        if mode == "release":
            invalid("SKIPPED mutants in a release run: it was not run over the whole module")
        skipped += 1
        continue
    if generated(name):
        left_out["generated"].add(name)
        continue
    if name.replace(os.sep, "/").startswith("internal/test/"):
        left_out["test support"].add(name)
        continue
    hit = excluded(name)
    if hit:
        left_out["approved"][hit[0]] = hit[1]
        continue
    planted.append((name, line, col, mtype, status))

def classify(name, line, col, mtype, status):
    if status == "NOT COVERED":
        return "not covered", "NOT COVERED"
    if status == "LIVED":
        return "equivalent", "LIVED"
    if status == "NOT VIABLE":
        return "not-viable", "NOT VIABLE"
    result = recheck.get((name, line, col, mtype))
    if result is None:
        invalid(f"{name}:{line}:{col} {mtype} ({status}) has no recheck line")
    if result.startswith("rejected"):
        return "not-viable", f"{status}, does not compile ({result[10:]})"
    if status == "KILLED":
        return "killed", "KILLED"
    return {"killed": ("killed", "TIMED OUT, killed on recheck"),
            "lived": ("equivalent", "TIMED OUT, lived on recheck"),
            "timed-out": ("timeout", "TIMED OUT, timed out again on recheck")}[result]

def match(name, line, col, mtype, kind):
    fp = fingerprint(name, line)
    hits = [r for r in records if not r["used"] and r["file"] == name and r["col"] == col
            and r["type"] == mtype and r["fp"] == fp]
    same = [r for r in hits if r["line"] == line]
    pick = same[0] if same else (hits[0] if len(hits) == 1 else None)
    if pick is None:
        return None, fp
    pick["used"] = True
    return pick, fp

killed, recorded, uncaught, moved, wrong_kind = 0, {k: 0 for k in KINDS}, [], [], []
recorded_rows = []
for name, line, col, mtype, status in sorted(planted):
    kind, why = classify(name, line, col, mtype, status)
    if kind == "killed":
        killed += 1
        continue
    if kind == "not covered":
        uncaught.append((name, line, col, mtype, why, None))
        continue
    rec, fp = match(name, line, col, mtype, kind)
    if rec and rec["kind"] != kind:
        wrong_kind.append(f"record line {rec['n']} says {rec['kind']}, the mutant is {why}: {kind}")
        rec = None
    if rec:
        recorded[kind] += 1
        recorded_rows.append(f"{name}:{line}:{col} | {mtype} | {kind} | {rec['reason']}")
        if rec["line"] != line:
            moved.append(f"record line {rec['n']}: {name} line {rec['line']} is now line {line}")
        continue
    uncaught.append((name, line, col, mtype, why, f"{name}:{line}:{col} | {mtype} | {kind} | {fp} | "
                     f"<the reason, after checking> | <who> {datetime.date.today().isoformat()}"))

skipped_keys = {(n, c, t) for n, l, c, t, s in planted_raw if s == "SKIPPED"}
stale = [r for r in records if not r["used"] and not (mode == "scheduled" and (r["file"], r["col"], r["type"]) in skipped_keys)]

total = len(planted)
caught = killed + sum(recorded.values())
print(f"Go mutation check (D048): {mode} run of commit {run['commit'][:12]} (source {run.get('source', '?')}), "
      f"Gremlins {run['gremlins']}, {run.get('go', '?')}")
if mode == "scheduled":
    print(f"Report only: blocks nothing. {'Changed code since ' + run.get('diff_ref', '') if run['mode'] == 'diff' else 'Whole module'}; "
          f"{skipped} mutants outside it were not planted.")
print(f"Planted: {total}")
print(f"Killed by a test: {killed}")
print(f"Recorded: {sum(recorded.values())} (equivalent {recorded['equivalent']}, timeout {recorded['timeout']}, "
      f"not-viable {recorded['not-viable']})")
for row in recorded_rows:
    print(f"  {row}")
print(f"Not caught: {len(uncaught)}")
ACTION = {"not covered": "no test of its own package runs it: write one, or list an approved exclusion",
          "equivalent": "write the test that kills it; record it as equivalent only if no input can tell it apart",
          "timeout": "check that the mutated code never finishes, then record it",
          "not-viable": "the compiler rejects it: check that, then record it"}
for name, line, col, mtype, why, line_text in uncaught:
    kind = "not covered" if line_text is None else line_text.split(" | ")[2]
    print(f"  {name}:{line}:{col} {mtype}: {why}; {ACTION[kind]}")
for label, items in (("Generated code (left out)", sorted(left_out["generated"])),
                     ("Test support under internal/test/ (approved class, left out)", sorted(left_out["test support"])),
                     ("Approved exclusions (left out)", [f"{k}: {v}" for k, v in sorted(left_out["approved"].items())])):
    print(f"{label}: {', '.join(items) if items else 'none'}")
for note in moved:
    print(f"Moved: {note}; update the record")
problems = wrong_kind + [f"record line {r['n']} matches no planted mutant ({r['file']}:{r['line']}:{r['col']} "
                         f"{r['type']}): the code changed or the mutant is now killed; re-check it or remove it"
                         for r in stale]
for p in problems:
    print(f"Stale record: {p}")
print(f"Result: {caught}/{total} caught (killed {killed} + recorded {sum(recorded.values())})")

if total == 0 and mode == "release":
    invalid("no mutant was planted outside generated code, test support and approved exclusions")
if caught == total and not problems:
    verdict, code = "PASS", 0
elif caught * 10 > total * 9 and caught < total and not problems:
    verdict, code = "WAIVER-NEEDED", 3
    if mode == "release" and opts["--waiver"]:
        for l in read(opts["--waiver"], "waiver file").splitlines():
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if len(cells) != 6 or cells[0].lower() != "mutation" or cells[1].lower() != "go":
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
            print(f"Waiver row not accepted (it must name this run's commit, {caught}/{total}, "
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
          f"add the row | mutation | go | source {run.get('source', run['commit'][:12])} | {caught}/{total} | "
          f"<comments> | <YYYY-MM-DD> | (the source id stays the same when only the report changes)")
unrecorded = [u[5] for u in uncaught if u[5]]
if unrecorded:
    print("To record a mutant you have checked (only if no input can make it behave differently, or it times out "
          "or does not compile), copy its line into the record and write the reason:")
    for u in unrecorded:
        print(f"  {u}")
print(f"Verdict: {verdict}")
if mode == "scheduled" and code != 2:
    code = 0
sys.exit(code)
PY
