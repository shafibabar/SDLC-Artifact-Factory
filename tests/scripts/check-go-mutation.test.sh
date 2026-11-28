#!/bin/bash
# Synthetic-input test for go-mutation-test's verdict script (decision D048):
# fake Gremlins output, recheck and run files; needs no Go and no Gremlins.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-mutation-test/scripts/check-go-mutation.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0
COMMIT=4f2a9c0e1b7d3a5c6e8f0a1b2c3d4e5f60718293
SOURCE=9d8c7b6a5f4e3d2c

# fixture <dir> <python that edits `mutants`, `recheck`, `run`, `files`, `record`, `extra`>
# Default: one file with 20 numbered lines, 20 KILLED mutants that compile.
fixture() {
  python3 -I - "$1" "$2" "$COMMIT" "$SOURCE" <<'PY'
import hashlib, json, os, sys
root, change, commit, source = sys.argv[1:5]
files = {"internal/fares/fares.go": "package fares\n" + "".join(f"var v{i} = {i} + 1\n" for i in range(2, 21)),
         "go.mod": "module example.com/tidewater\n\ngo 1.27\n"}
mutants = [("internal/fares/fares.go", i, 12, "ARITHMETIC_BASE", "KILLED") for i in range(2, 21)]
mutants.append(("internal/fares/fares.go", 2, 12, "INVERT_NEGATIVES", "KILLED"))
recheck = {}
run = {"commit": commit, "source": source, "mode": "full", "diff_ref": "", "gremlins": "v0.6.0",
       "go": "go1.27.4", "gremlins_exit": "0"}
record, extra, module = [], {}, "example.com/tidewater"
def fp(name, line):
    return hashlib.sha256(files[name].splitlines()[line - 1].strip().encode()).hexdigest()[:12]
def rec(name, line, col, mtype, kind, reason="no input reaches a value where the two differ", who="test-strategist 2026-11-28", fpline=None):
    record.append(f"{name}:{line}:{col} | {mtype} | {kind} | {fp(name, fpline or line)} | {reason} | {who}")
def status(i, s, mtype="ARITHMETIC_BASE"):
    for k, m in enumerate(mutants):
        if m[1] == i and m[3] == mtype:
            mutants[k] = m[:4] + (s,)
exec(change)
for name, text in files.items():
    os.makedirs(os.path.dirname(os.path.join(root, name)) or root, exist_ok=True)
    open(os.path.join(root, name), "w").write(text)
out = os.path.join(root, "mutation-out")
os.makedirs(out, exist_ok=True)
if run is not None:
    open(os.path.join(out, "run.txt"), "w").write("".join(f"{k}={v}\n" for k, v in run.items()))
by_file = {}
for name, line, col, mtype, st in mutants:
    by_file.setdefault(name, []).append({"type": mtype, "status": st, "line": line, "column": col})
report = {"go_module": module, "files": [{"file_name": k, "mutations": v} for k, v in by_file.items()]}
if extra.get("json") != "absent":
    open(os.path.join(out, "gremlins.json"), "w").write("" if extra.get("json") == "empty" else json.dumps(report))
lines = []
for name, line, col, mtype, st in mutants:
    if st in ("KILLED", "TIMED OUT") and (name, line, mtype) not in extra.get("drop_recheck", []):
        default = "compiles" if st == "KILLED" else "timed-out"
        lines.append(f"{name}:{line}:{col} {mtype} {st} -> {recheck.get((line, mtype), default)}")
open(os.path.join(out, "recheck.txt"), "w").write("".join(l + "\n" for l in lines))
open(os.path.join(root, "record.txt"), "w").write("".join(l + "\n" for l in record))
for name, text in extra.get("write", {}).items():
    open(os.path.join(root, name), "w").write(text)
PY
}

# case <name> <expected exit> <regex> <fixture change> [script arguments...]
case_() {
  local name="$1" want="$2" pattern="$3" change="$4"
  shift 4
  rm -rf "$TMP/m"
  mkdir -p "$TMP/m"
  fixture "$TMP/m" "$change"
  local out code
  out="$(/bin/bash "$SCRIPT" --mode release --commit "$COMMIT" --record "$TMP/m/record.txt" "$@" "$TMP/m" 2>&1)"
  code=$?
  if [ "$code" -eq "$want" ] && grep -E "$pattern" > /dev/null <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $code, want $want; pattern '$pattern')"
    printf '%s\n' "$out" | sed 's/^/    /' | head -14
    FAILURES=$((FAILURES + 1))
  fi
}

WAIVER='| Measure | Language | Run | Measured | Product owner comments | Reviewed on |\n|---|---|---|---|---|---|\n'

case_ "every mutant killed" 0 "Verdict: PASS$" "pass"
case_ "counts, not a tool score" 0 "^Result: 20/20 caught \(killed 20 \+ recorded 0\)" "pass"
case_ "one LIVED, unrecorded: 19/20 needs a waiver" 3 "Verdict: WAIVER-NEEDED" "status(5, 'LIVED')"
case_ "unrecorded LIVED gets a record line to fill" 3 "fares.go:5:12 \| ARITHMETIC_BASE \| equivalent \| [0-9a-f]{12} \| <the reason" "status(5, 'LIVED')"
case_ "equivalent mutant passes once recorded" 0 "Verdict: PASS$" \
  "status(5, 'LIVED'); rec('internal/fares/fares.go', 5, 12, 'ARITHMETIC_BASE', 'equivalent')"
case_ "two LIVED: 18/20 is 90%, no waiver" 1 "90% or below: no waiver is possible" "status(5, 'LIVED'); status(6, 'LIVED')"
case_ "90% with a waiver row still fails" 1 "Verdict: FAIL" \
  "status(5, 'LIVED'); status(6, 'LIVED'); extra['write'] = {'w.md': '$WAIVER| mutation | go | $SOURCE | 18/20 | Reviewed both survivors in detail | 2026-11-28 |\n'}" \
  --waiver "$TMP/m/w.md"
case_ "above 90% with a matching waiver row (source id)" 0 "Verdict: PASS \(waived by the product owner on 2026-11-28\)" \
  "status(5, 'LIVED'); extra['write'] = {'w.md': '$WAIVER| mutation | go | source $SOURCE | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/m/w.md"
case_ "waiver row naming the commit" 0 "waived by the product owner" \
  "status(5, 'LIVED'); extra['write'] = {'w.md': '$WAIVER| mutation | go | ${COMMIT:0:9} | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/m/w.md"
case_ "waiver row with other counts is refused" 3 "Waiver row not accepted" \
  "status(5, 'LIVED'); extra['write'] = {'w.md': '$WAIVER| mutation | go | $SOURCE | 18/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/m/w.md"
case_ "waiver row without comments is refused" 3 "Waiver row not accepted" \
  "status(5, 'LIVED'); extra['write'] = {'w.md': '$WAIVER| mutation | go | $SOURCE | 19/20 | ok | 2026-11-28 |\n'}" \
  --waiver "$TMP/m/w.md"
case_ "waiver row for another run is refused" 3 "Waiver row not accepted" \
  "status(5, 'LIVED'); extra['write'] = {'w.md': '$WAIVER| mutation | go | 0000000aaaa | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/m/w.md"
case_ "TIMED OUT counts only once recorded" 3 "TIMED OUT, timed out again on recheck; check that the mutated code never finishes" \
  "status(7, 'TIMED OUT')"
case_ "TIMED OUT recorded as timeout" 0 "Recorded: 1 \(equivalent 0, timeout 1, not-viable 0\)" \
  "status(7, 'TIMED OUT'); rec('internal/fares/fares.go', 7, 12, 'ARITHMETIC_BASE', 'timeout', 'i-- never reaches the bound; the loop never ends')"
case_ "TIMED OUT killed on recheck counts as killed" 0 "Killed by a test: 20" \
  "status(7, 'TIMED OUT'); recheck[(7, 'ARITHMETIC_BASE')] = 'killed'"
case_ "TIMED OUT that lived on recheck is a survivor" 3 "TIMED OUT, lived on recheck" \
  "status(7, 'TIMED OUT'); recheck[(7, 'ARITHMETIC_BASE')] = 'lived'"
case_ "KILLED that does not compile is not caught" 3 "KILLED, does not compile \(fares.go:8:9: invalid operation\); the compiler rejects it" \
  "recheck[(8, 'ARITHMETIC_BASE')] = 'rejected: fares.go:8:9: invalid operation'"
case_ "compile-rejected mutant recorded as not-viable" 0 "Verdict: PASS$" \
  "recheck[(8, 'ARITHMETIC_BASE')] = 'rejected: fares.go:8:9: invalid operation'; rec('internal/fares/fares.go', 8, 12, 'ARITHMETIC_BASE', 'not-viable', 'string minus string does not compile')"
case_ "NOT VIABLE needs a record" 3 "NOT VIABLE; the compiler rejects it" "status(9, 'NOT VIABLE')"
case_ "NOT COVERED is never recordable" 1 "Stale record: record line 1 matches no planted mutant" \
  "status(10, 'NOT COVERED'); rec('internal/fares/fares.go', 10, 12, 'ARITHMETIC_BASE', 'equivalent')"
case_ "NOT COVERED asks for a test of its own package" 3 "NOT COVERED; no test of its own package runs it" "status(10, 'NOT COVERED')"
case_ "record of the wrong kind" 1 "record line 1 says equivalent, the mutant is TIMED OUT, timed out again on recheck: timeout" \
  "status(7, 'TIMED OUT'); rec('internal/fares/fares.go', 7, 12, 'ARITHMETIC_BASE', 'equivalent')"
case_ "record whose code changed is stale" 1 "Stale record" \
  "status(5, 'LIVED'); rec('internal/fares/fares.go', 5, 12, 'ARITHMETIC_BASE', 'equivalent', fpline=6)"
case_ "record for a now-killed mutant is stale" 1 "the code changed or the mutant is now killed" \
  "rec('internal/fares/fares.go', 5, 12, 'ARITHMETIC_BASE', 'equivalent')"
case_ "record still matches when its line moved" 0 "Moved: record line 1: internal/fares/fares.go line 4 is now line 5" \
  "status(5, 'LIVED'); rec('internal/fares/fares.go', 5, 12, 'ARITHMETIC_BASE', 'equivalent'); record[0] = record[0].replace(':5:12', ':4:12')"
case_ "generated file left out by its marker" 0 "Generated code \(left out\): internal/fares/models.go" \
  "files['internal/fares/models.go'] = '// Code generated by sqlc. DO NOT EDIT.\n\npackage fares\nvar x = 1 + 2\n'; mutants.append(('internal/fares/models.go', 4, 11, 'ARITHMETIC_BASE', 'LIVED'))"
case_ "moq mock left out by name" 0 "Generated code \(left out\): internal/fares/port_moq.go" \
  "files['internal/fares/port_moq.go'] = 'package fares\nvar y = 1 + 2\n'; mutants.append(('internal/fares/port_moq.go', 2, 11, 'ARITHMETIC_BASE', 'NOT COVERED'))"
case_ "test support left out as a class" 0 "Test support under internal/test/ \(approved class, left out\): internal/test/fx/fx.go" \
  "files['internal/test/fx/fx.go'] = 'package fx\nvar y = 1 + 2\n'; mutants.append(('internal/test/fx/fx.go', 2, 11, 'ARITHMETIC_BASE', 'NOT COVERED'))"
case_ "approved exclusion left out and listed" 0 "Approved exclusions \(left out\): internal/legacy/: frozen importer, replaced next quarter" \
  "files['internal/legacy/imp.go'] = 'package legacy\nvar y = 1 + 2\n'; mutants.append(('internal/legacy/imp.go', 2, 11, 'ARITHMETIC_BASE', 'NOT COVERED')); extra['write'] = {'ex.txt': 'internal/legacy/ | approved 2026-11-20 | frozen importer, replaced next quarter\n'}" \
  --exclusions "$TMP/m/ex.txt"
case_ "pending exclusion is refused" 2 "INVALID: exclusion not approved" \
  "extra['write'] = {'ex.txt': 'internal/legacy/ | pending | frozen importer, replaced next quarter\n'}" \
  --exclusions "$TMP/m/ex.txt"
case_ "missing run.txt: the run did not finish" 2 "INVALID: run.txt \(the run did not finish\) is missing" "run = None"
case_ "missing report" 2 "INVALID: gremlins.json is missing" "extra['json'] = 'absent'"
case_ "empty report" 2 "INVALID: gremlins.json is empty" "extra['json'] = 'empty'"
case_ "report from another commit" 2 "INVALID: the run is of commit 111111111111" "run['commit'] = '1111111111111111111111111111111111111111'"
case_ "report for another module" 2 "INVALID: gremlins.json is for module example.com/other" "module = 'example.com/other'"
case_ "Gremlins exited with a threshold code" 2 "INVALID: Gremlins exited 10" "run['gremlins_exit'] = '10'"
case_ "a diff run cannot judge a release" 2 "INVALID: a release run covers the whole module" "run['mode'] = 'diff'; run['diff_ref'] = 'v1.4.0'"
case_ "SKIPPED in a release run" 2 "INVALID: SKIPPED mutants in a release run" "status(11, 'SKIPPED')"
case_ "dry run" 2 "INVALID: RUNNABLE mutants" "status(11, 'RUNNABLE')"
case_ "KILLED without a recheck line" 2 "has no recheck line" "extra['drop_recheck'] = [('internal/fares/fares.go', 12, 'ARITHMETIC_BASE')]"
case_ "record without a reason" 2 "gives no reason" \
  "status(5, 'LIVED'); rec('internal/fares/fares.go', 5, 12, 'ARITHMETIC_BASE', 'equivalent', '<the reason, after checking>')"
case_ "record without who and when" 2 "malformed" \
  "status(5, 'LIVED'); rec('internal/fares/fares.go', 5, 12, 'ARITHMETIC_BASE', 'equivalent', who='someone')"

# Scheduled mode: report only.
rm -rf "$TMP/m"; mkdir -p "$TMP/m"
fixture "$TMP/m" "run['mode'] = 'diff'; run['diff_ref'] = 'v1.4.0'; status(5, 'LIVED'); status(6, 'LIVED'); [status(i, 'SKIPPED') for i in range(7, 21)]"
out="$(/bin/bash "$SCRIPT" --mode scheduled --commit "$COMMIT" "$TMP/m" 2>&1)"; code=$?
if [ "$code" -eq 0 ] && grep -E "Report only: blocks nothing" > /dev/null <<<"$out" && grep -E "^Verdict: FAIL$" > /dev/null <<<"$out" \
   && grep -E "14 mutants outside it were not planted" > /dev/null <<<"$out"; then
  echo "PASS: scheduled run reports FAIL and exits 0"
else
  echo "FAIL: scheduled run (exit $code)"; printf '%s\n' "$out" | sed 's/^/    /' | head -8; FAILURES=$((FAILURES + 1))
fi
out="$(/bin/bash "$SCRIPT" --mode scheduled --commit 2222222 "$TMP/m" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: scheduled INVALID still exits 2"; else echo "FAIL: scheduled INVALID (exit $code)"; FAILURES=$((FAILURES + 1)); fi
out="$(/bin/bash "$SCRIPT" --mode nightly --commit "$COMMIT" "$TMP/m" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: usage"; else echo "FAIL: usage (exit $code)"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: check-go-mutation"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
