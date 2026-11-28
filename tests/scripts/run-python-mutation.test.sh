#!/bin/bash
# Synthetic-input test for python-mutation-test's runner: a fake `mutmut` on the
# PATH stands in for mutmut 3.8.1 (its version line, `run` with name globs,
# `results --all true`, `show`, and the timeout recheck), so no mutmut is needed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-mutation-test/scripts/run-python-mutation.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0
mkdir -p "$TMP/bin"

# The fake reads fake-mutants.json (name -> status; "slow" times out unless
# timeout_multiplier >= 60 in the pyproject.toml of the folder it runs in, then
# it is killed; "endless" always times out) and logs every call to $FAKE_LOG.
cat > "$TMP/bin/mutmut" <<'PY'
#!/usr/bin/env python3
import fnmatch, json, os, re, sys
a = sys.argv[1:]
open(os.environ["FAKE_LOG"], "a").write(os.getcwd() + " :: " + " ".join(a) + "\n")
if a == ["--version"]:
    print("mutmut, version " + os.environ.get("FAKE_VERSION", "3.8.1")); sys.exit(0)
spec = json.load(open("fake-mutants.json"))
mult = float((re.search(r"(?m)^timeout_multiplier\s*=\s*([0-9.]+)", open("pyproject.toml").read()) or [0, "15"])[1])
state = os.path.join("mutants", "state.json")
if a[0] == "run":
    names = [x for x in a[1:] if "__mutmut_" in x]
    if int(os.environ.get("FAKE_RUN_EXIT", "0")):
        print("failed to collect stats. runner returned 2"); sys.exit(int(os.environ["FAKE_RUN_EXIT"]))
    old = json.load(open(state)) if os.path.exists(state) else {}
    if os.path.exists("mutants/stale-marker"):
        print("stale mutants/ was not deleted"); sys.exit(9)
    os.makedirs("mutants/src/pkg", exist_ok=True)
    picked = [n for n in spec if not names or any(fnmatch.fnmatchcase(n, g) for g in names)]
    if names and not picked:  # mutmut 3.8.1 has generated every mutant by then (observed)
        json.dump({n: "not checked" for n in spec}, open(state, "w"))
        print("AssertionError: Filtered for specific mutants, but nothing matches"); sys.exit(1)
    result = dict(old) or {n: "not checked" for n in spec}
    for n in picked:
        s = spec[n]
        result[n] = {"slow": "killed" if mult >= 60 else "timeout", "endless": "timeout"}.get(s, s)
    json.dump(result, open(state, "w"))
    errs = {n: "Incompatible return value type" for n, s in spec.items() if s == "caught by type check"}
    json.dump({"exit_code_by_key": {}, "type_check_error_by_key": errs}, open("mutants/src/pkg/m.py.meta", "w"))
    sys.exit(0)
if a[0] == "results":
    if a[1:] != ["--all", "true"]:
        print("Error: Option '--all' requires an argument."); sys.exit(2)
    for n, s in json.load(open(state)).items():
        print(f"    {n}: {s}")
    sys.exit(0)
if a[0] == "show":
    s = json.load(open(state))[a[1]]
    print(f"# {a[1]}: {s}\n--- src/pkg/m.py\n+++ src/pkg/m.py\n@@ -1,2 +1,2 @@\n def f(n):\n-    return n > 1\n+    return n >= 1 # {a[1][-2:]}")
    sys.exit(0)
sys.exit(3)
PY
chmod +x "$TMP/bin/mutmut"

# project <dir>: a committed git project with src/pkg/m.py, a class, and fake-mutants.json.
project() {
  rm -rf "$1"; mkdir -p "$1/src/pkg"
  ( cd "$1" && python3 -I - <<'PY'
import json
open("pyproject.toml", "w").write('[project]\nname = "pkg"\n\n[tool.mutmut]\ntimeout_multiplier = 15\nsource_paths = ["src/pkg"]\npytest_add_cli_args = ["--no-cov"]\n')
open("src/pkg/__init__.py", "w").write("")
open("src/pkg/m.py", "w").write("def f(n):\n    return n > 1\n\n\nclass Till:\n    def close(self, n):\n        return n * 2\n\n    def open(self):\n        return 0\n")
open(".gitignore", "w").write("mutants/\nmutation-out/\n")
spec = {"pkg.m.x_f__mutmut_1": "killed", "pkg.m.x_f__mutmut_2": "survived", "pkg.m.x_f__mutmut_3": "slow",
        "pkg.m.x_f__mutmut_4": "endless", "pkg.m.x_f__mutmut_5": "no tests", "pkg.m.x_f__mutmut_6": "caught by type check",
        "pkg.m.xǁTillǁclose__mutmut_1": "survived", "pkg.m.xǁTillǁopen__mutmut_1": "killed"}
json.dump(spec, open("fake-mutants.json", "w"), indent=1)
PY
    git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm init && git tag v1.0.0 )
}

check() {  # check <name> <condition-command...>
  local name="$1"; shift
  if "$@"; then echo "PASS: $name"; else echo "FAIL: $name"; FAILURES=$((FAILURES + 1)); fi
}
has() { grep -E "$2" "$1" > /dev/null 2>&1; }
hasnt() { ! grep -E "$2" "$1" > /dev/null 2>&1; }
run_it() {  # run_it <dir> [args...]; sets OUT and CODE
  local dir="$1"; shift
  OUT="$(cd "$dir" && PATH="$TMP/bin:$PATH" FAKE_LOG="$TMP/log" /bin/bash "$SCRIPT" "$@" . 2>&1)"; CODE=$?
}

P="$TMP/p"
project "$P"; : > "$TMP/log"
mkdir -p "$P/mutants"; touch "$P/mutants/stale-marker"
run_it "$P"
check "full run finishes (exit 0)" test "$CODE" -eq 0
check "stale mutants/ deleted before the run" test ! -f "$P/mutants/stale-marker"
check "run.txt written with commit, source id, mode, versions" has "$P/mutation-out/run.txt" "^source=[0-9a-f]{16}$"
check "run.txt mode full" has "$P/mutation-out/run.txt" "^mode=full$"
check "run.txt records mutmut 3.8.1" has "$P/mutation-out/run.txt" "^mutmut=3.8.1$"
check "results read with --all true" has "$TMP/log" ":: results --all true$"
check "results.txt lists every mutant" test "$(grep -c '__mutmut_' "$P/mutation-out/results.txt")" -eq 8
check "slow timeout killed on the longer recheck" has "$P/mutation-out/recheck.txt" "^pkg.m.x_f__mutmut_3 timeout -> killed$"
check "endless timeout timed out again" has "$P/mutation-out/recheck.txt" "^pkg.m.x_f__mutmut_4 timeout -> timeout$"
check "recheck ran in a copy, not the project" has "$TMP/log" "python-mutation-recheck-.* :: run pkg.m.x_f__mutmut_3 pkg.m.x_f__mutmut_4$"
check "the project's own timeout_multiplier untouched" has "$P/pyproject.toml" "^timeout_multiplier = 15$"
check "show.txt holds survivors, not killed ones" has "$P/mutation-out/show.txt" "^# pkg.m.x_f__mutmut_2: survived$"
check "show.txt skips a mutant killed on recheck" hasnt "$P/mutation-out/show.txt" "x_f__mutmut_3:"
check "show.txt holds the endless timeout" has "$P/mutation-out/show.txt" "^# pkg.m.x_f__mutmut_4: timeout$"
check "typecheck.txt carries the type checker's message" has "$P/mutation-out/typecheck.txt" "^pkg.m.x_f__mutmut_6: Incompatible return value type$"

# Changed-code run: one method changed since the tag.
( cd "$P" && python3 -I -c "
p = open('src/pkg/m.py').read(); open('src/pkg/m.py', 'w').write(p.replace('return n * 2', 'return n * 3'))" \
  && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm change )
: > "$TMP/log"
run_it "$P" --changed-since v1.0.0
check "changed run finishes" test "$CODE" -eq 0
check "scope.txt names the changed method only" has "$P/mutation-out/scope.txt" "^pkg.m.x$(printf '\307\201')Till$(printf '\307\201')close__mutmut_\*$"
check "scope.txt leaves unchanged functions out" hasnt "$P/mutation-out/scope.txt" "x_f__|open__"
check "mutmut run given the glob" has "$TMP/log" ":: run pkg.m.x.+Till.+close__mutmut_\*$"
check "run.txt mode changed, since the tag" has "$P/mutation-out/run.txt" "^changed_since=v1.0.0$"
check "unchanged functions are not checked" has "$P/mutation-out/results.txt" "x_f__mutmut_2: not checked"

# Nothing changed in any function.
( cd "$P" && git tag v1.1.0 && printf 'X = 1\n' >> src/pkg/m.py && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm const )
: > "$TMP/log"
run_it "$P" --changed-since v1.1.0
check "nothing changed: finished, empty scope" test "$CODE" -eq 0 -a ! -s "$P/mutation-out/scope.txt"
check "nothing changed: mutmut run not called" hasnt "$TMP/log" ":: run"

# A changed function with no mutant: mutmut refuses the filter; the runner reports an empty run.
( cd "$P" && printf '\n\ndef g():\n    return 1\n' >> src/pkg/m.py && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm g )
run_it "$P" --changed-since v1.1.0
check "filter matching nothing is not a failure" test "$CODE" -eq 0
check "filter matching nothing is reported" grep -E "No mutant in the changed functions" > /dev/null <<<"$OUT"

# A project below the repository root (several projects in one repository).
project "$TMP/mono/services/p"; rm -rf "$TMP/mono/services/p/.git"
( cd "$TMP/mono" && git init -q && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm mono && git tag v2.0.0 \
  && python3 -I -c "
p = open('services/p/src/pkg/m.py').read(); open('services/p/src/pkg/m.py', 'w').write(p.replace('return n > 1', 'return n > 2'))" \
  && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm change )
run_it "$TMP/mono/services/p" --changed-since v2.0.0
check "subfolder project: changed run finishes" test "$CODE" -eq 0
check "subfolder project: the changed function is in scope" has "$TMP/mono/services/p/mutation-out/scope.txt" "^pkg.m.x_f__mutmut_\*$"

# Refusals.
project "$P"; printf 'x\n' > "$P/untracked.txt"
run_it "$P"; check "dirty tree refused" test "$CODE" -eq 2 -a ! -f "$P/mutation-out/run.txt"
project "$P"
OUT="$(cd "$P" && PATH="$TMP/bin:$PATH" FAKE_LOG="$TMP/log" FAKE_VERSION=3.9.0 /bin/bash "$SCRIPT" . 2>&1)"; CODE=$?
check "another mutmut version refused" test "$CODE" -eq 2
check "the refusal names both versions" grep -E "mutmut is 3.9.0, pinned is 3.8.1" > /dev/null <<<"$OUT"
OUT="$(cd "$P" && PATH="$TMP/bin:$PATH" FAKE_LOG="$TMP/log" PYTEST_ADDOPTS=-x /bin/bash "$SCRIPT" . 2>&1)"; CODE=$?
check "PYTEST_ADDOPTS refused" test "$CODE" -eq 2
OUT="$(cd "$P" && PATH="$TMP/bin:$PATH" FAKE_LOG="$TMP/log" FAKE_RUN_EXIT=1 /bin/bash "$SCRIPT" . 2>&1)"; CODE=$?
check "mutmut run failing gives no result" test "$CODE" -eq 2 -a ! -f "$P/mutation-out/run.txt"
check "the failure says why" grep -E "mutmut run exited 1" > /dev/null <<<"$OUT"
run_it "$P" --mutmut-version latest; check "an inexact pin refused" test "$CODE" -eq 2
( cd "$P" && printf '[project]\nname = "pkg"\n' > pyproject.toml && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -qm nocfg )
run_it "$P"; check "no [tool.mutmut] refused" test "$CODE" -eq 2

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-python-mutation"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
