#!/bin/bash
# Synthetic-input test for go-mutation-test's runner: a fake `gremlins` writes a
# prepared report and a fake `go` answers the version, compile and test calls, so
# no Go toolchain or Gremlins is needed. Git is real.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-mutation-test/scripts/run-go-mutation.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0
mkdir -p "$TMP/bin"

# Fake gremlins: records its arguments and some environment, writes $FAKE_REPORT
# to the --output path unless FAKE_NO_REPORT is set, and exits $FAKE_EXIT.
cat > "$TMP/bin/gremlins" <<'SH'
#!/bin/bash
printf '%s\n' "$@" > "$FAKE_LOG.args"
printf 'GOFLAGS=%s\nGIT_CONFIG_COUNT=%s\nGIT_CONFIG_KEY_0=%s\nGIT_CONFIG_VALUE_0=%s\n' \
  "${GOFLAGS:-}" "${GIT_CONFIG_COUNT:-}" "${GIT_CONFIG_KEY_0:-}" "${GIT_CONFIG_VALUE_0:-}" > "$FAKE_LOG.env"
out=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--output" ]; then out="$2"; shift; fi
  shift
done
echo "Killed: 3, Lived: 0, Not covered: 0"
if [ -z "${FAKE_NO_REPORT:-}" ] && [ -n "$out" ]; then cp "$FAKE_REPORT" "$out"; fi
exit "${FAKE_EXIT:-0}"
SH
# Fake go: `version -m` reports $FAKE_VERSION; `env GOVERSION`; `test -c` fails
# when the package holds a string minus a string; `test` (run) loops for ever on
# `i--`, fails on `<=` and passes otherwise.
cat > "$TMP/bin/go" <<'SH'
#!/bin/bash
case "$1" in
  version) printf '%s: go1.27.4\n\tpath\tgithub.com/go-gremlins/gremlins/cmd/gremlins\n\tmod\tgithub.com/go-gremlins/gremlins\t%s\th1:x=\n' "$3" "$FAKE_VERSION"; exit 0 ;;
  env) echo go1.27.4; exit 0 ;;
esac
for pkg; do :; done
if [ "$2" = "-c" ]; then
  if grep -E '"[a-z]+" - "' "$pkg"/*.go > /dev/null; then echo "${pkg#./}/fares.go:9:9: invalid operation: operator - not defined"; exit 1; fi
  exit 0
fi
if grep -E 'i--' "$pkg"/*.go > /dev/null; then sleep 30; fi
if grep -E '<=' "$pkg"/*.go > /dev/null; then echo "--- FAIL"; exit 1; fi
exit 0
SH
chmod +x "$TMP/bin/gremlins" "$TMP/bin/go"

# A committed module. Line 5: count < n (BOUNDARY gives <=, killed on recheck);
# line 6: i++ (INCREMENT_DECREMENT gives i--, endless); line 9: "a" + "b".
new_repo() {
  rm -rf "$TMP/r"
  mkdir -p "$TMP/r/internal/fares" "$TMP/r/artifacts"
  printf 'module example.com/saltmarsh\n\ngo 1.27\n' > "$TMP/r/go.mod"
  printf 'unleash:\n  threshold:\n    efficacy: 0\n' > "$TMP/r/.gremlins.yaml"
  printf 'mutation-out/\n' > "$TMP/r/.gitignore"
  printf 'package fares\n\nfunc Count(n int) int {\n\tc := 0\n\tfor count := 0; count < n; count++ {\n\t\tfor i := 0; i < 1; i++ {\n\t\t\tc += 1\n\t\t}\n\t}\n\treturn c\n}\n\nfunc Label() string { return "a" + "b" }\n' > "$TMP/r/internal/fares/fares.go"
  printf 'report\n' > "$TMP/r/artifacts/report.md"
  git -C "$TMP/r" init -q -b main
  git -C "$TMP/r" add -A
  git -C "$TMP/r" -c user.name=t -c user.email=t@example.invalid commit -qm one
}
REPORT="$TMP/report.json"
cat > "$REPORT" <<'JSON'
{"go_module":"example.com/saltmarsh","files":[{"file_name":"internal/fares/fares.go","mutations":[
{"type":"CONDITIONALS_BOUNDARY","status":"TIMED OUT","line":5,"column":24},
{"type":"INCREMENT_DECREMENT","status":"TIMED OUT","line":6,"column":23},
{"type":"ARITHMETIC_BASE","status":"KILLED","line":13,"column":34},
{"type":"CONDITIONALS_NEGATION","status":"KILLED","line":5,"column":24},
{"type":"REMOVE_SELF_ASSIGNMENTS","status":"LIVED","line":7,"column":6}]}]}
JSON

# run_case <name> <expected exit> <regex> [env assignments and runner arguments...]
run_case() {
  local name="$1" want="$2" pattern="$3"
  shift 3
  local out code
  out="$(cd "$TMP" && env PATH="$TMP/bin:/usr/bin:/bin" FAKE_LOG="$TMP/log" FAKE_REPORT="$REPORT" FAKE_VERSION=v0.6.0 "$@" 2>&1)"
  code=$?
  if [ "$code" -eq "$want" ] && grep -E -e "$pattern" > /dev/null <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $code, want $want; pattern '$pattern')"
    printf '%s\n' "$out" | sed 's/^/    /' | head -12
    FAILURES=$((FAILURES + 1))
  fi
}
check_file() {
  local name="$1" file="$2" pattern="$3"
  if [ -f "$file" ] && grep -E -e "$pattern" "$file" > /dev/null; then echo "PASS: $name"; else
    echo "FAIL: $name ($file lacks '$pattern')"; [ -f "$file" ] && sed 's/^/    /' "$file" | head -8; FAILURES=$((FAILURES + 1)); fi
}

new_repo
run_case "a full run finishes" 0 "Run finished for [0-9a-f]{12} \(whole module\); recheck: 1 compiles, 1 killed, 1 rejected, 1 timed-out" \
  /bin/bash "$SCRIPT" --recheck-timeout 2 "$TMP/r"
check_file "KILLED that compiles" "$TMP/r/mutation-out/recheck.txt" "^internal/fares/fares.go:5:24 CONDITIONALS_NEGATION KILLED -> compiles$"
check_file "TIMED OUT killed on recheck" "$TMP/r/mutation-out/recheck.txt" "^internal/fares/fares.go:5:24 CONDITIONALS_BOUNDARY TIMED OUT -> killed$"
check_file "TIMED OUT that never ends" "$TMP/r/mutation-out/recheck.txt" "^internal/fares/fares.go:6:23 INCREMENT_DECREMENT TIMED OUT -> timed-out$"
if grep REMOVE_SELF_ASSIGNMENTS "$TMP/r/mutation-out/recheck.txt" > /dev/null; then echo "FAIL: a LIVED mutant was rechecked"; FAILURES=$((FAILURES + 1)); else echo "PASS: LIVED is not rechecked"; fi
check_file "run.txt names the commit" "$TMP/r/mutation-out/run.txt" "^commit=$(git -C "$TMP/r" rev-parse HEAD)$"
check_file "run.txt: full mode, pinned version, exit 0" "$TMP/r/mutation-out/run.txt" "^gremlins=v0.6.0$"
check_file "run.txt: a source id" "$TMP/r/mutation-out/run.txt" "^source=[0-9a-f]{16}$"
check_file "Gremlins gets the committed config" "$TMP/log.args" "^$TMP/r/.gremlins.yaml$"
check_file "no path argument (whole module)" "$TMP/log.args" "^--output$"
if grep -E "^\./|^internal" "$TMP/log.args" > /dev/null; then echo "FAIL: a path argument was passed"; FAILURES=$((FAILURES + 1)); else echo "PASS: no package path given to Gremlins"; fi
check_file "an uncached coverage run" "$TMP/log.env" "^GOFLAGS=.*-count=1$"
if cmp -s "$TMP/r/internal/fares/fares.go" <(git -C "$TMP/r" show HEAD:internal/fares/fares.go); then echo "PASS: the module is left unchanged"; else echo "FAIL: the module was changed"; FAILURES=$((FAILURES + 1)); fi

# A compile-rejected KILLED mutant (string + string becomes string - string).
cat > "$REPORT" <<'JSON'
{"go_module":"example.com/saltmarsh","files":[{"file_name":"internal/fares/fares.go","mutations":[
{"type":"ARITHMETIC_BASE","status":"KILLED","line":13,"column":34}]}]}
JSON
run_case "a KILLED mutant that does not compile" 0 "recheck: 1 rejected" /bin/bash "$SCRIPT" "$TMP/r"
check_file "the compiler's message is kept" "$TMP/r/mutation-out/recheck.txt" "ARITHMETIC_BASE KILLED -> rejected: internal/fares/fares.go:9:9: invalid operation"

source_one="$(grep '^source=' "$TMP/r/mutation-out/run.txt")"
printf 'waiver row added\n' >> "$TMP/r/artifacts/report.md"
git -C "$TMP/r" -c user.name=t -c user.email=t@example.invalid commit -qam "report only"
run_case "a report-only commit" 0 "Run finished" /bin/bash "$SCRIPT" "$TMP/r"
check_file "keeps the source id" "$TMP/r/mutation-out/run.txt" "^$source_one$"

run_case "a report that does not match the source" 2 "no ARITHMETIC_BASE operator at that position" \
  /bin/bash -c "sed 's/\"column\":34/\"column\":20/' '$REPORT' > '$TMP/bad.json' && FAKE_REPORT='$TMP/bad.json' /bin/bash '$SCRIPT' '$TMP/r'"
run_case "uncommitted change" 2 "uncommitted or untracked changes" \
  /bin/bash -c "printf '// x\n' >> '$TMP/r/internal/fares/fares.go' && /bin/bash '$SCRIPT' '$TMP/r'; s=\$?; git -C '$TMP/r' checkout -q -- .; exit \$s"
run_case "untracked Go file" 2 "uncommitted or untracked changes" \
  /bin/bash -c "printf 'package fares\n' > '$TMP/r/internal/fares/new.go' && /bin/bash '$SCRIPT' '$TMP/r'; s=\$?; rm -f '$TMP/r/internal/fares/new.go'; exit \$s"
run_case "another Gremlins version" 2 "Gremlins is v0.5.1, pinned is v0.6.0" FAKE_VERSION=v0.5.1 /bin/bash "$SCRIPT" "$TMP/r"
run_case "a range instead of a version" 2 "must be an exact version" /bin/bash "$SCRIPT" --gremlins-version latest "$TMP/r"
run_case "GREMLINS_ variables override the file" 2 "GREMLINS_\* environment variables override .gremlins.yaml: unset GREMLINS_UNLEASH_DIFF" \
  GREMLINS_UNLEASH_DIFF=main /bin/bash "$SCRIPT" "$TMP/r"
run_case "a threshold set (exit 10)" 2 "Gremlins exited 10 \(10 or 11 means a threshold is set" FAKE_EXIT=10 /bin/bash "$SCRIPT" "$TMP/r"
if [ -f "$TMP/r/mutation-out/run.txt" ]; then echo "FAIL: run.txt written for a failed run"; FAILURES=$((FAILURES + 1)); else echo "PASS: no run.txt for a failed run"; fi
run_case "interrupted run: exit 0 and no report" 2 "Gremlins wrote no report" FAKE_NO_REPORT=1 /bin/bash "$SCRIPT" "$TMP/r"
run_case "no .gremlins.yaml" 2 "no .gremlins.yaml" \
  /bin/bash -c "git -C '$TMP/r' rm -q .gremlins.yaml && git -C '$TMP/r' -c user.name=t -c user.email=t@example.invalid commit -qm rm && /bin/bash '$SCRIPT' '$TMP/r'"
new_repo
run_case "a diff run" 0 "diff against v1.0.0" /bin/bash -c "git -C '$TMP/r' tag v1.0.0 && /bin/bash '$SCRIPT' --diff v1.0.0 '$TMP/r'"
check_file "passes --diff" "$TMP/log.args" "^--diff$"
check_file "diffs without context lines" "$TMP/log.env" "^GIT_CONFIG_KEY_0=diff.context$"
check_file "run.txt: diff mode" "$TMP/r/mutation-out/run.txt" "^mode=diff$"
mkdir -p "$TMP/mono"
mv "$TMP/r" "$TMP/mono/svc"
rm -rf "$TMP/mono/svc/.git"
git -C "$TMP/mono" init -q -b main && git -C "$TMP/mono" add -A && git -C "$TMP/mono" -c user.name=t -c user.email=t@example.invalid commit -qm one
run_case "a diff run on a module below the repository root" 2 "--diff needs the module at the repository root" \
  /bin/bash "$SCRIPT" --diff main "$TMP/mono/svc"
run_case "a full run on a module below the root" 0 "whole module" /bin/bash "$SCRIPT" "$TMP/mono/svc"
run_case "usage" 2 "unknown argument" /bin/bash "$SCRIPT" --workers 4 "$TMP/mono/svc"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-go-mutation"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
