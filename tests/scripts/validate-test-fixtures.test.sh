#!/bin/bash
# Synthetic-input test for test-fixture-design's validate-test-fixtures.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$SCRIPT_DIR/../../skills/test-fixture-design/scripts/validate-test-fixtures.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

# expect <name> <exit-code> <output-regex> <args...>
expect() {
  local name="$1" code="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$V" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$code" ] && grep -qE "$pattern" <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $rc, want $code /$pattern/)"; echo "$out"; FAILED=1
  fi
}
# bad <name> <file> <rule> <line of code>
bad() {
  mkdir -p "$TMP/bad/$1"
  printf '%s\n' "$4" > "$TMP/bad/$1/$2"
  expect "$1" 1 "FAIL $3 " "$TMP/bad/$1"
}

bad go-truncate a_test.go F5 '	pool.Exec(ctx, "TRUNCATE bookings CASCADE")'
bad py-drop conftest.py F5 '    conn.execute("DROP SCHEMA public CASCADE")'
bad delete-all conftest.py F5 '    conn.execute("DELETE FROM bookings")'
bad go-discard a_test.go F4 '	_, _ = pool.Exec(ctx, "DELETE FROM b WHERE id=$1", id)'
bad go-rollback a_test.go F4 '	t.Cleanup(func() {
		_ = tx.Rollback(ctx)
	})'
bad go-oneline a_test.go F4 '	t.Cleanup(func() { _ = tx.Rollback(ctx) })'
bad py-swallow conftest.py F4 'try:
    cleanup()
except Exception:
    pass'
bad go-clock a_test.go F6 '	b := NewBooking(time.Now())'
bad py-clock test_a.py F6 'now = datetime.now(timezone.utc)'
bad go-rand a_test.go F6 '	n := rand.IntN(10)'
bad py-rand test_a.py F6 'n = random.randint(1, 9)'
bad bulk-update test_a.py F8 'CMD = "go test ./... -update"'

mkdir -p "$TMP/good/tests" "$TMP/good/internal/test/db"
cat > "$TMP/good/tests/test_ok.py" <<'PY'
# datetime.now() in a comment is ignored
rng = random.Random(42)
n = rng.randint(1, 9)
deadline = time.time() + 5  # polling timeout
conn.execute("DELETE FROM bookings WHERE id = ?", (key,))
PY
cat > "$TMP/good/internal/test/db/tx.go" <<'GO'
package db

func WithTx(t *testing.T) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	rng := rand.New(rand.NewPCG(1, 2))
	_ = rng.IntN(3)
	t.Cleanup(func() {
		if err := tx.Rollback(ctx); err != nil {
			t.Errorf("rollback: %v", err)
		}
	})
}
GO
expect clean-code 0 "checked 2 file\(s\): 0 FAIL, 0 WARN" "$TMP/good"

printf 'package x\n\nfunc setup(t *testing.T) {\n\tt.Helper()\n\tdefer pool.Close()\n}\n' > "$TMP/defer_test.go"
expect defer-warns 0 "WARN F4" "$TMP/defer_test.go"
printf 'url = os.environ["DATABASE_URL"]\n' > "$TMP/conftest.py"
expect env-url-warns 0 "WARN F7" "$TMP/conftest.py"

mkdir -p "$TMP/prod/app"
printf 'now = datetime.now()\n' > "$TMP/prod/app/service.py"
expect non-test-files-only 2 "nothing was checked" "$TMP/prod"
expect missing-path 2 "no such path" "$TMP/nope"
expect no-args 2 "usage"

exit "$FAILED"
