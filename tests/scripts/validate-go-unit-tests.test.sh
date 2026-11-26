#!/bin/bash
# Synthetic-input test for go-unit-test's validate-go-unit-tests.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$SCRIPT_DIR/../../skills/go-unit-test/scripts/validate-go-unit-tests.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

expect() {
  local name="$1" code="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$V" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$code" ] && grep -qE -- "$pattern" <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $rc, want $code /$pattern/)"; echo "$out"; FAILED=1
  fi
}
# one <name> <exit> <regex> <test-function body>
one() {
  mkdir -p "$TMP/$1"
  printf 'package p\n\nfunc TestX(t *testing.T) {\n%s\n}\n' "$4" > "$TMP/$1/x_test.go"
  expect "$1" "$2" "$3" "$TMP/$1"
}
one sleep 1 "FAIL SLEEP " '	time.Sleep(time.Second)'
one bool-assert 1 "FAIL BOOL " '	assert.True(t, got == want)'
one bool-require 1 "FAIL BOOL " '	require.False(t, got != want, "m")'
one bare 1 "FAIL BARE " '	t.Fail()'
one err-equal 1 "FAIL ERRTEXT " '	if err.Error() == "x" {
	}'
one err-contains 1 "FAIL ERRTEXT " '	if !strings.Contains(err.Error(), "x") {
	}'
one err-helper 1 "FAIL ERRTEXT " '	require.EqualError(t, err, "x")'
one loopcopy 0 "WARN LOOPCOPY " '	tt := tt'
one global-rand 0 "WARN RAND " '	_ = rand.IntN(3)'
one clock 0 "WARN CLOCK " '	_ = time.Now()'
one setenv 0 "WARN SETENV " '	t.Parallel()
	t.Setenv("A", "b")'
one defer-parallel 0 "WARN DEFER " '	defer db.Close()
	t.Run("a", func(t *testing.T) { t.Parallel() })'
one clean 0 "0 FAIL, 0 WARN" '	// time.Sleep(1) and t.Fail() in a comment
	s := "time.Sleep(1)"
	assert.True(t, err != nil)
	assert.True(t, ok)
	r := rand.New(rand.NewPCG(1, 2))
	_ = r.IntN(3)
	if !errors.Is(err, ErrX) {
		t.Errorf("got %v, want %v", err, ErrX)
	}'
one bubble 0 "0 FAIL, 0 WARN" '	synctest.Test(t, func(t *testing.T) {
		start := time.Now()
		time.Sleep(time.Second)
		_ = time.Since(start)
	})'
mkdir -p "$TMP/skip/vendor"
printf 'package p\n' > "$TMP/skip/a_test.go"
printf 'func TestV(t *testing.T) { t.Fail() }\n' > "$TMP/skip/vendor/v_test.go"
printf 'func F() { time.Sleep(1) }\n' > "$TMP/skip/prod.go"
expect "vendor and non-test files skipped" 0 "checked 1 test file" "$TMP/skip"
mkdir -p "$TMP/none"
expect "nothing to check" 2 "nothing was checked" "$TMP/none"
expect "missing path" 2 "no such path" "$TMP/nope"
expect "usage" 2 "usage"
exit $FAILED
