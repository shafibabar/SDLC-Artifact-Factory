#!/bin/bash
# Synthetic-input test for python-mutation-test's verdict script (decision D048):
# fake mutmut output, recheck and run files; needs no mutmut.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-mutation-test/scripts/check-python-mutation.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0
COMMIT=4f2a9c0e1b7d3a5c6e8f0a1b2c3d4e5f60718293
SOURCE=9d8c7b6a5f4e3d2c

# fixture <dir> <python that edits `results`, `recheck`, `run`, `files`, `record`, `exclusions`, `extra`, `cfg`>
# Default: one module with 20 killed mutants in function `fee`.
fixture() {
  python3 -I - "$1" "$2" "$COMMIT" "$SOURCE" <<'PY'
import hashlib, os, sys
root, change, commit, source = sys.argv[1:5]
M = "orchard.domain.fees"
files = {"src/orchard/__init__.py": "", "src/orchard/domain/__init__.py": "",
         "src/orchard/domain/fees.py": "def fee(n: int) -> int:\n    return n * 2\n",
         "tests/__init__.py": "", "tests/fakes.py": "class FakeTills:\n    pass\n",
         "tests/conftest.py": "import pytest\n", "tests/unit/test_fees.py": "def test_fee() -> None:\n    pass\n"}
results = {f"{M}.x_fee__mutmut_{i}": "killed" for i in range(1, 21)}
recheck, typecheck = {}, {}
run = {"commit": commit, "source": source, "mode": "full", "changed_since": "", "mutmut": "3.8.1",
       "python": "Python 3.14.4", "mutmut_exit": "0", "recheck_multiplier": "60"}
cfg = '[tool.mutmut]\nsource_paths = ["src/orchard"]\npytest_add_cli_args = ["--no-cov"]\n'
record, exclusions, extra, scope = [], [], {}, None
def diff(name, variant=""):
    n = name.rsplit("_", 1)[1]
    return (f"--- src/orchard/domain/fees.py\n+++ src/orchard/domain/fees.py\n@@ -1,2 +1,2 @@\n"
            f" def fee(n: int) -> int:\n-    return n * 2\n+    return n * {n}{variant}\n")
def fp(name, variant=""):
    body = "\n".join(l for l in diff(name, variant).splitlines() if not l.startswith("@@"))
    return hashlib.sha256(body.encode()).hexdigest()[:12]
def name(i, fn="x_fee", module=M):
    return f"{module}.{fn}__mutmut_{i}"
def rec(i, kind, reason="no input reaches a value where the two differ", who="test-strategist 2026-11-28", as_name=None, variant=""):
    record.append(f"{as_name or name(i)} | {kind} | {fp(name(i), variant)} | {reason} | {who}")
exec(change)
for path, text in files.items():
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)
open(os.path.join(root, "pyproject.toml"), "w").write(cfg)
out = os.path.join(root, "mutation-out")
os.makedirs(out, exist_ok=True)
if run is not None:
    open(os.path.join(out, "run.txt"), "w").write("".join(f"{k}={v}\n" for k, v in run.items()))
if extra.get("results") != "absent":
    open(os.path.join(out, "results.txt"), "w").write("".join(f"{k}: {v}\n" for k, v in results.items()))
open(os.path.join(out, "recheck.txt"), "w").write("".join(f"{k} timeout -> {v}\n" for k, v in recheck.items()))
shows = "".join(f"# {k}: {v}\n" + diff(k, extra.get("variant", {}).get(k, "")) for k, v in results.items() if v != "killed")
open(os.path.join(out, "show.txt"), "w").write(shows)
open(os.path.join(out, "typecheck.txt"), "w").write("".join(f"{k}: {v}\n" for k, v in typecheck.items()))
if scope is not None:
    open(os.path.join(out, "scope.txt"), "w").write("".join(g + "\n" for g in scope))
open(os.path.join(root, "record.txt"), "w").write("".join(l + "\n" for l in record))
open(os.path.join(root, "ex.txt"), "w").write("".join(l + "\n" for l in exclusions))
for path, text in extra.get("write", {}).items():
    open(os.path.join(root, path), "w").write(text)
PY
}

# case_ <name> <expected exit> <regex> <fixture change> [script arguments...]
case_() {
  local name="$1" want="$2" pattern="$3" change="$4"
  shift 4
  rm -rf "$TMP/p"
  mkdir -p "$TMP/p"
  fixture "$TMP/p" "$change"
  local out code
  out="$(/bin/bash "$SCRIPT" --mode release --commit "$COMMIT" --record "$TMP/p/record.txt" --exclusions "$TMP/p/ex.txt" "$@" "$TMP/p" 2>&1)"
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
case_ "one survived, unrecorded: 19/20 needs a waiver" 3 "Verdict: WAIVER-NEEDED" "results[name(5)] = 'survived'"
case_ "unrecorded survivor gets a record line to fill" 3 "x_fee__mutmut_5 \| equivalent \| [0-9a-f]{12} \| <the reason" "results[name(5)] = 'survived'"
case_ "equivalent mutant passes once recorded" 0 "Verdict: PASS$" "results[name(5)] = 'survived'; rec(5, 'equivalent')"
case_ "two survived: 18/20 is 90%, no waiver" 1 "90% or below: no waiver is possible" \
  "results[name(5)] = 'survived'; results[name(6)] = 'survived'"
case_ "90% with a waiver row still fails" 1 "Verdict: FAIL" \
  "results[name(5)] = 'survived'; results[name(6)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | python | $SOURCE | 18/20 | Reviewed both survivors in detail | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "above 90% with a matching waiver row (source id)" 0 "Verdict: PASS \(waived by the product owner on 2026-11-28\)" \
  "results[name(5)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | python | source $SOURCE | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "waiver row naming the commit" 0 "waived by the product owner" \
  "results[name(5)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | python | ${COMMIT:0:9} | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "waiver row for another language is ignored" 3 "Verdict: WAIVER-NEEDED" \
  "results[name(5)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | go | $SOURCE | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "waiver row with other counts is refused" 3 "Waiver row not accepted" \
  "results[name(5)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | python | $SOURCE | 18/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "waiver row without comments is refused" 3 "Waiver row not accepted" \
  "results[name(5)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | python | $SOURCE | 19/20 | ok | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "waiver row for another run is refused" 3 "Waiver row not accepted" \
  "results[name(5)] = 'survived'; extra['write'] = {'w.md': '$WAIVER| mutation | python | 0000000aaaa | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "timeout counts only once recorded" 3 "timeout, timed out again on the longer recheck; check that the mutated code never finishes" \
  "results[name(7)] = 'timeout'; recheck[name(7)] = 'timeout'"
case_ "timeout recorded as timeout" 0 "Recorded: 1 \(equivalent 0, timeout 1, not-viable 0\)" \
  "results[name(7)] = 'timeout'; recheck[name(7)] = 'timeout'; rec(7, 'timeout', 'the loop variable only grows; the loop never ends')"
case_ "timeout killed on the longer recheck counts as killed" 0 "Killed by a test: 20" \
  "results[name(7)] = 'timeout'; recheck[name(7)] = 'killed'"
case_ "timeout that survived the recheck is a survivor" 3 "timeout, survived the longer recheck" \
  "results[name(7)] = 'timeout'; recheck[name(7)] = 'survived'"
case_ "timeout without a recheck line" 2 "timed out and has no recheck line" "results[name(7)] = 'timeout'"
case_ "caught by type check needs a record" 3 "caught by type check \(Incompatible return value type\); the type checker rejects it" \
  "results[name(8)] = 'caught by type check'; typecheck[name(8)] = 'Incompatible return value type'"
case_ "caught by type check recorded as not-viable" 0 "Verdict: PASS$" \
  "results[name(8)] = 'caught by type check'; rec(8, 'not-viable', 'returns a float where an int is declared')"
case_ "no tests is never recordable" 1 "Stale record: record line 1 matches no planted mutant" \
  "results[name(10)] = 'no tests'; rec(10, 'equivalent')"
case_ "no tests asks for a test" 3 "no tests; no test reaches it: write one" "results[name(10)] = 'no tests'"
case_ "record of the wrong kind" 1 "record line 1 says equivalent, the mutant is timeout, timed out again on the longer recheck: timeout" \
  "results[name(7)] = 'timeout'; recheck[name(7)] = 'timeout'; rec(7, 'equivalent')"
case_ "record whose diff changed is stale" 1 "Stale record" \
  "results[name(5)] = 'survived'; rec(5, 'equivalent', variant=' + 0')"
case_ "record for a now-killed mutant is stale" 1 "the code changed or the mutant is now killed" "rec(5, 'equivalent')"
case_ "a stale line cannot be waived" 1 "cannot be waived" \
  "results[name(5)] = 'survived'; rec(6, 'equivalent'); extra['write'] = {'w.md': '$WAIVER| mutation | python | $SOURCE | 19/20 | Reviewed: boundary on a dead path | 2026-11-28 |\n'}" \
  --waiver "$TMP/p/w.md"
case_ "record still matches when the mutant was renumbered" 0 "Renamed: record line 1: orchard.domain.fees.x_fee__mutmut_4 is now orchard.domain.fees.x_fee__mutmut_5" \
  "results[name(5)] = 'survived'; rec(5, 'equivalent', as_name=name(4))"
case_ "method names with the class separator" 0 "Verdict: PASS$" \
  "n = name(1, fn='xǁTillǁclose'); results[n] = 'survived'; record.append(n + ' | equivalent | ' + fp(n) + ' | rounding to the same pence either way | test-strategist 2026-11-28')"
case_ "generated file left out by its marker" 0 "Generated code \(left out\): src/orchard/adapters/client.py" \
  "files['src/orchard/adapters/__init__.py'] = ''; files['src/orchard/adapters/client.py'] = '# Code generated by openapi-python-client. DO NOT EDIT.\ndef f():\n    return 1\n'; results[name(1, 'x_f', 'orchard.adapters.client')] = 'no tests'"
case_ "test support listed" 0 "Test support under tests/ \(approved class, never mutated\): tests/conftest.py, tests/fakes.py" "pass"
case_ "approved exclusion left out and listed" 0 "Approved exclusions \(left out\): src/orchard/legacy/: frozen importer, replaced next quarter" \
  "files['src/orchard/legacy/__init__.py'] = ''; files['src/orchard/legacy/imp.py'] = 'def g():\n    return 2\n'; results[name(1, 'x_g', 'orchard.legacy.imp')] = 'no tests'; exclusions.append('src/orchard/legacy/ | folder | approved 2026-11-20 | frozen importer, replaced next quarter')"
case_ "do_not_mutate without approval is refused" 2 "src/orchard/legacy/imp.py is matched by do_not_mutate, with no approved exclusion" \
  "files['src/orchard/legacy/__init__.py'] = ''; files['src/orchard/legacy/imp.py'] = 'def g():\n    return 2\n'; cfg += 'do_not_mutate = [\"src/orchard/legacy/*\"]\n'"
case_ "do_not_mutate with approval passes" 0 "Approved exclusions \(left out\): src/orchard/legacy/imp.py" \
  "files['src/orchard/legacy/__init__.py'] = ''; files['src/orchard/legacy/imp.py'] = 'def g():\n    return 2\n'; cfg += 'do_not_mutate = [\"src/orchard/legacy/*\"]\n'; exclusions.append('src/orchard/legacy/imp.py | file | approved 2026-11-20 | frozen importer, replaced next quarter')"
case_ "code outside source_paths is refused" 2 "src/extra/x.py is outside source_paths" \
  "files['src/extra/x.py'] = 'def h():\n    return 3\n'"
case_ "only_mutate leaving a file out is refused" 2 "src/orchard/rates.py is not matched by only_mutate" \
  "files['src/orchard/rates.py'] = 'def r():\n    return 4\n'; cfg += 'only_mutate = [\"src/orchard/domain/*\"]\n'"
case_ "a pragma without approval is refused" 2 "src/orchard/domain/fees.py:2 is not mutated .* to propose one: src/orchard/domain/fees.py \| lines [0-9a-f]{12} \| pending" \
  "files['src/orchard/domain/fees.py'] = 'def fee(n: int) -> int:\n    return n * 2  # pragma: no mutate\n'"
case_ "an approved pragma line is listed" 0 "Approved lines not mutated: src/orchard/domain/fees.py:2" \
  "import hashlib; files['src/orchard/domain/fees.py'] = 'def fee(n: int) -> int:\n    return n * 2  # pragma: no mutate\n'; exclusions.append('src/orchard/domain/fees.py | lines ' + hashlib.sha256('return n * 2  # pragma: no mutate'.encode()).hexdigest()[:12] + ' | approved 2026-11-20 | doubling kept for the old till export')"
case_ "do_not_mutate_patterns needs approval" 2 "is not mutated \(pragma or do_not_mutate_patterns\)" \
  "cfg += 'do_not_mutate_patterns = [\"n \\\\\\\\* 2\"]\n'"
case_ "mutate_only_covered_lines is refused" 2 "mutate_only_covered_lines = true" "cfg += 'mutate_only_covered_lines = true\n'"
case_ "pending exclusion is refused" 2 "INVALID: exclusion not approved" \
  "exclusions.append('src/orchard/legacy/ | folder | pending | frozen importer, replaced next quarter')"
case_ "missing run.txt: the run did not finish" 2 "INVALID: run.txt \(the run did not finish\) is missing" "run = None"
case_ "missing results" 2 "INVALID: results.txt is missing" "extra['results'] = 'absent'"
case_ "empty results" 2 "INVALID: results.txt lists no mutant" "results.clear()"
case_ "results from another commit" 2 "INVALID: the run is of commit 111111111111" "run['commit'] = '1111111111111111111111111111111111111111'"
case_ "mutmut run failed" 2 "INVALID: mutmut run exited 1" "run['mutmut_exit'] = '1'"
case_ "a changed-code run cannot judge a release" 2 "INVALID: a release run covers the whole project" \
  "run['mode'] = 'changed'; run['changed_since'] = 'v1.4.0'; scope = [M + '.x_fee__mutmut_*']"
case_ "not checked in a release run" 2 "is 'not checked': the run did not test it" "results[name(11)] = 'not checked'"
case_ "skipped in a release run" 2 "is 'skipped': the run did not test it" "results[name(11)] = 'skipped'"
case_ "suspicious gives no result" 2 "is 'suspicious': fix the cause and run again; it can never be recorded" "results[name(11)] = 'suspicious'"
case_ "segfault gives no result" 2 "is 'segfault'" "results[name(11)] = 'segfault'"
case_ "interrupted gives no result" 2 "is 'check was interrupted by user'" "results[name(11)] = 'check was interrupted by user'"
case_ "an unknown status gives no result" 2 "a status this script does not know" "results[name(11)] = 'mystery'"
case_ "record without a reason" 2 "gives no reason" "results[name(5)] = 'survived'; rec(5, 'equivalent', '<the reason, after checking>')"
case_ "record without who and when" 2 "malformed" "results[name(5)] = 'survived'; rec(5, 'equivalent', who='someone')"
case_ "deprecated string keys" 2 "paths_to_mutate or tests_dir given as a string" "cfg += 'tests_dir = \"tests/unit/\"\n'"

# Scheduled mode: report only, changed functions only.
rm -rf "$TMP/p"; mkdir -p "$TMP/p"
fixture "$TMP/p" "run['mode'] = 'changed'; run['changed_since'] = 'v1.4.0'; scope = [M + '.x_fee__mutmut_*']; results.update({name(i, 'x_tax'): 'not checked' for i in range(1, 15)}); results[name(5)] = 'survived'; results[name(6)] = 'survived'; rec(2, 'equivalent', as_name=name(2, 'x_tax'))"
out="$(/bin/bash "$SCRIPT" --mode scheduled --commit "$COMMIT" --record "$TMP/p/record.txt" "$TMP/p" 2>&1)"; code=$?
if [ "$code" -eq 0 ] && grep -E "Report only: blocks nothing" > /dev/null <<<"$out" && grep -E "^Verdict: FAIL$" > /dev/null <<<"$out" \
   && grep -E "14 mutants outside it were not tested" > /dev/null <<<"$out" && ! grep -E "Stale record" > /dev/null <<<"$out"; then
  echo "PASS: scheduled run reports FAIL, exits 0, and judges no record outside its scope"
else
  echo "FAIL: scheduled run (exit $code)"; printf '%s\n' "$out" | sed 's/^/    /' | head -10; FAILURES=$((FAILURES + 1))
fi
rm -rf "$TMP/p"; mkdir -p "$TMP/p"
fixture "$TMP/p" "run['mode'] = 'changed'; scope = [M + '.x_fee__mutmut_*']; results[name(3)] = 'not checked'"
out="$(/bin/bash "$SCRIPT" --mode scheduled --commit "$COMMIT" "$TMP/p" 2>&1)"; code=$?
if [ "$code" -eq 2 ] && grep -E "not checked" > /dev/null <<<"$out"; then echo "PASS: not checked inside the scope is INVALID"; else echo "FAIL: not checked in scope (exit $code)"; FAILURES=$((FAILURES + 1)); fi
rm -rf "$TMP/p"; mkdir -p "$TMP/p"
fixture "$TMP/p" "run['mode'] = 'changed'; scope = []; results = {k: 'not checked' for k in results}"
out="$(/bin/bash "$SCRIPT" --mode scheduled --commit "$COMMIT" "$TMP/p" 2>&1)"; code=$?
if [ "$code" -eq 0 ] && grep -E "^Planted: 0$" > /dev/null <<<"$out"; then echo "PASS: nothing changed is reported, not failed"; else echo "FAIL: empty scope (exit $code)"; printf '%s\n' "$out" | head -5; FAILURES=$((FAILURES + 1)); fi
out="$(/bin/bash "$SCRIPT" --mode scheduled --commit 2222222 "$TMP/p" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: scheduled INVALID still exits 2"; else echo "FAIL: scheduled INVALID (exit $code)"; FAILURES=$((FAILURES + 1)); fi
out="$(/bin/bash "$SCRIPT" --mode nightly --commit "$COMMIT" "$TMP/p" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: usage"; else echo "FAIL: usage (exit $code)"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: check-python-mutation"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
