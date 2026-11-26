#!/bin/bash
# Synthetic-input test for go-unit-test's check-go-branch-coverage.sh.
# Needs no Go toolchain: `go` and `gobco` are stubs.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$SCRIPT_DIR/../../skills/go-unit-test/scripts/check-go-branch-coverage.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

expect() {
  local name="$1" code="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$S" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$code" ] && grep -qE -- "$pattern" <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $rc, want $code /$pattern/)"; echo "$out"; FAILED=1
  fi
}

M="$(cd "$TMP" && pwd -P)/mod"; mkdir -p "$M/a" "$TMP/bin"
printf 'module example.test/m\n\ngo 1.27\n' > "$M/go.mod"
printf 'package a\n\nfunc F(n int) int {\n\tif n > 0 {\n\t\treturn 1\n\t}\n\treturn 0\n}\n' > "$M/a/a.go"
printf 'package a\n' > "$M/a/x_moq.go"
cat > "$TMP/bin/go" <<'STUB'
#!/bin/bash
printf '%s\n' "$STUB_LIST"
STUB
cat > "$TMP/bin/gobco" <<'STUB'
#!/bin/bash
if [ "$1" = -version ]; then echo "${STUB_VERSION:-1.3.4}"; exit 0; fi
echo "$*" >> "$STUB_LOG"
if [ -n "${STUB_OUT:-}" ]; then echo "$STUB_OUT"; exit "${STUB_EXIT:-0}"; fi
while [ $# -gt 0 ]; do [ "$1" = -stats ] && printf '%s' "$STUB_STATS" > "$2"; shift; done
echo "Branch coverage: x/y"
exit "${STUB_EXIT:-0}"
STUB
chmod +x "$TMP/bin/go" "$TMP/bin/gobco"
export STUB_LOG="$TMP/log" PATH="$TMP/bin:$PATH"
export STUB_LIST="$M/a|a.go,x_moq.go,"
row() { printf '{"Start":"a/%s:4:5","Code":"n > 0","TrueCount":%s,"FalseCount":%s}' "$1" "$2" "$3"; }

export STUB_STATS="[$(row a.go 1 1),$(row x_moq.go 0 1)]"
expect "full coverage passes; moq conditions left out" 0 "2/2 outcomes" "$M"
expect "unmeasured cases stated" 0 "Not measured: select; range loops" "$M"
if grep -q -- "-branch -stats .* ./a" "$TMP/log" && ! grep -q -- "-race" "$TMP/log"; then
  echo "PASS: branch mode, one package, no race"; else echo "FAIL: gobco args"; cat "$TMP/log"; FAILED=1; fi
STUB_STATS="[$(row a.go 1 0)]" expect "never false fails" 1 "'n > 0' never false" "$M"
STUB_STATS="[$(row a.go 1 0)]" expect "50 percent has no waiver" 1 "no waiver" "$M"
STUB_STATS="[$(row a.go 0 0)]" expect "never evaluated" 1 "never evaluated" "$M"
many="$(for _ in $(seq 10); do row a.go 1 1; echo -n ,; done)"
STUB_STATS="[$many$(row a.go 1 0)]" expect "above 90 is waivable after review" 1 "may waive" "$M"
STUB_EXIT=1 expect "gobco failure is no result" 2 "NO RESULT ./a" "$M"
STUB_OUT="nothing to instrument" expect "nothing to instrument is no result" 2 "NO RESULT ./a" "$M"
STUB_STATS="not json" expect "bad statistics are no result" 2 "unreadable" "$M"
STUB_STATS="[]" expect "0/0 with a condition in source is no result" 2 "measured none" "$M"
STUB_VERSION=1.0.0 expect "wrong version refused" 2 "pinned version" "$M"
GOBCO=no-such-binary expect "missing gobco is no result" 2 "not installed" "$M"
printf 'package a\n' > "$M/a/b_windows.go"
expect "constrained-out file is no result and blocks" 2 "left out of this build" "$M"
mkdir -p "$M/only"; printf '//go:build extra\n\npackage only\n' > "$M/only/b.go"
expect "folder invisible to go list is no result" 2 "only/b.go: left out" "$M"
rm -r "$M/only"
printf 'a/b_windows.go | approved 2026-01-02 | other platform\n' > "$TMP/excl"
expect "approved exclusion applies and is named as not measured" 0 "NOT measured, by approved exception: a/b_windows.go" --exclusions "$TMP/excl" "$M"
printf 'a/a.go | approved 2026-01-02 | gobco panics\n' >> "$TMP/excl"
STUB_EXIT=2 expect "package with every file excepted is not run" 0 "NOT measured, by approved exception: a/a.go" --exclusions "$TMP/excl" "$M"
printf 'package a\n' > "$M/a/c.go"
STUB_LIST="$M/a|a.go,c.go," STUB_EXIT=2 expect "one unexcepted file keeps the package blocked" 2 "NO RESULT ./a" --exclusions "$TMP/excl" "$M"
rm "$M/a/c.go"
printf 'a/b_windows.go | pending | other platform\n' > "$TMP/pending"
expect "pending exclusion refused" 2 "not approved" --exclusions "$TMP/pending" "$M"
mkdir -p "$M/plain"
printf 'package plain\n\n// if in a comment\nvar s = "switch case if"\n\nfunc G(x []int) {\n\tfor range x {\n\t}\n\tfor _, v := range x {\n\t\t_ = v\n\t}\n\tfor {\n\t}\n}\n' > "$M/plain/p.go"
rm "$M/a/b_windows.go"; mv "$M/a/a.go" "$TMP/a.go.keep"
STUB_LIST="$M/plain|p.go," STUB_STATS="[]" expect "package truly without conditions passes" 0 "no measured package holds a condition" "$M"
printf 'package plain\n\nfunc H(n int) {\n\tfor i := 0; i < n; i++ {\n\t}\n}\n' > "$M/plain/p.go"
STUB_LIST="$M/plain|p.go," STUB_STATS="[]" expect "for condition must be measured" 2 "measured none" "$M"
rm -r "$M/plain"; mv "$TMP/a.go.keep" "$M/a/a.go"
STUB_LIST="$M/a|a.go,"
expect "tags reach go test" 0 "PASS" --tags extra "$M"
if grep -q -- "-test=-tags=extra" "$TMP/log"; then echo "PASS: tags passed"; else echo "FAIL: tags"; FAILED=1; fi
expect "unknown argument" 2 "unknown argument" -race "$M"
# go-makefile's cover recipe: either gate's non-zero exit stops make.
Q="$SCRIPT_DIR/../../skills/go-makefile/references/quality-gate-targets.md"
if command -v make >/dev/null 2>&1; then
  mkdir -p "$TMP/mk/scripts"
  { sed -n '/^COVER_EXCEPTIONS/p' "$Q"; sed -n '/^\.PHONY: cover$/,/^$/p' "$Q"; sed -n '/^\.PHONY: ci$/,/^ci:/p' "$Q"
    printf 'tidy generate vet lint arch vuln:\n\t@true\n'; } > "$TMP/mk/Makefile"
  gate() { printf '#!/bin/bash\necho "ran %s $*"\nexit %s\n' "$1" "$2" > "$TMP/mk/scripts/check-go-$1-coverage.sh"; chmod +x "$TMP/mk/scripts/check-go-$1-coverage.sh"; }
  mk() { # name want-zero|nonzero pattern
    local out rc; out="$(make -C "$TMP/mk" ci 2>&1)"; rc=$?
    local got=nonzero; [ $rc -eq 0 ] && got=zero
    if [ "$got" = "$2" ] && grep -qE -- "$3" <<<"$out"; then echo "PASS: $1"
    else echo "FAIL: $1 (exit $rc)"; echo "$out"; FAILED=1; fi; }
  gate line 0; gate branch 0; mk "make ci passes when both gates pass" zero "ran branch"
  gate branch 2; mk "make ci blocks on a branch no-result" nonzero "ran branch"
  gate branch 1; mk "make ci blocks on a branch gap" nonzero "ran branch"
  gate line 2; gate branch 0; mk "make ci blocks on a line no-result" nonzero "ran line"
  touch "$TMP/mk/coverage-exceptions.txt"; gate line 0
  mk "make ci passes the exception file to both gates" zero "ran branch --exclusions coverage-exceptions.txt"
else
  echo "SKIP: make is not installed; Makefile checks not run"
fi
exit $FAILED
