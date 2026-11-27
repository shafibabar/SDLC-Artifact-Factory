#!/bin/bash
# Synthetic-input test for go-integration-test's validator. Needs neither Go nor Docker.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/go-integration-test/scripts/validate-go-integration-tests.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# check <label> <expected exit> <expected output pattern or -> <path...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$out"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$out"; FAILURES=$((FAILURES + 1))
  fi
}

# one <name> <rule> <level exit> <body line(s)>: a single offending file
one() {
  local name="$1" pattern="$2" want="$3" body="$4"
  mkdir -p "$TMP/$name"
  printf 'package x_test\n\n%s\n' "$body" > "$TMP/$name/a_integration_test.go"
  check "$name" "$want" "$pattern" "$TMP/$name"
}

check "no arguments is a usage error" 2 "usage"
check "missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty" && echo "package x" > "$TMP/empty/main.go"
check "nothing to check" 2 "nothing was checked" "$TMP/empty"

mkdir -p "$TMP/good"
cat > "$TMP/good/a_integration_test.go" <<'GO'
package x_test

// time.Sleep( and os.Getenv("DATABASE_URL") in a comment are not code.
func TestMain(m *testing.M) { os.Exit(run(m)) }

func TestStore(t *testing.T) {
	test.Integration(t)
	log.Print("do not time.Sleep( here")
	testdb.Scoped(t, pool, id, `DELETE FROM jobs WHERE id = $1`)
	if _, err := pool.Exec(ctx, `ALTER TABLE outbox ADD CONSTRAINT c CHECK (false)`); err != nil {
		t.Fatalf("add: %v", err)
	}
}
GO
check "clean file passes" 0 "1 file\(s\), 1 of them .*: 0 FAIL, 0 WARN" "$TMP/good"

one sleep "FAIL SLEEP" 1 'func helper() { time.Sleep(time.Second) }'
one dburl "FAIL DBURL" 1 'var dsn = os.Getenv("DATABASE_URL")'
one testdburl "FAIL DBURL" 1 'var dsn, ok = os.LookupEnv("TEST_DATABASE_URL")'
one mockdb "FAIL FAKEDB" 1 'import "github.com/pashagolub/pgxmock/v4"'
one sqlite "FAIL FAKEDB" 1 'import _ "modernc.org/sqlite"'
one truncate "FAIL RESET" 1 'const q = `TRUNCATE jobs CASCADE`'
one wipe "FAIL RESET" 1 'const q = "DELETE FROM jobs"'
one latest "FAIL IMAGE" 1 'const image = "postgres:latest"'
one untagged "FAIL IMAGE" 1 'func f() { postgres.Run(ctx, "postgres") }'
one dockerskip "FAIL DOCKERSKIP" 1 'func f(t *testing.T) { testcontainers.SkipIfProviderIsNotHealthy(t) }'
one ignored "FAIL CLEANERR" 1 'func f() {
	_, _ = pool.Exec(ctx, "DELETE FROM jobs WHERE id = $1", id)
}'
one shortexit "FAIL SHORTEXIT" 1 'func TestMain(m *testing.M) {
	if testing.Short() {
		os.Exit(0)
	}
	os.Exit(m.Run())
}'
one buildtag "FAIL BUILDTAG" 1 '//go:build integration'
one fixedport "WARN FIXEDPORT" 0 'const dsn = "postgres://u:p@localhost:5432/app"'
one noskip "WARN NOSKIP .*TestStore" 0 'func TestStore(t *testing.T) {
	t.Parallel()
}'

mkdir -p "$TMP/mod/internal/test"
echo 'package test
func wait() { time.Sleep(time.Second) }' > "$TMP/mod/internal/test/await.go"
check "harness files are checked" 1 "FAIL SLEEP .*await.go:2" "$TMP/mod"
mkdir -p "$TMP/unit"
echo 'package x_test
func TestAdd(t *testing.T) {}' > "$TMP/unit/add_test.go"
check "unit tests only: count of integration files is shown" 0 "0 of them" "$TMP/unit"

# The shipped examples must satisfy the validator (Go blocks extracted from Markdown).
python3 -I - "$REPO_ROOT/skills/go-integration-test" "$TMP/shipped" <<'PY'
import os, re, sys
skill, out = sys.argv[1:]
count = 0
for folder in ("templates", "examples"):
    for name in sorted(os.listdir(os.path.join(skill, folder))):
        text = open(os.path.join(skill, folder, name), encoding="utf-8").read()
        for path, body in re.findall(r"^#{2,4} `([\w./-]+\.go)`\n\n```go\n(.*?)^```", text, re.M | re.S):
            target = os.path.join(out, name[:-3], path)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w", encoding="utf-8").write(body)
            count += 1
print(count)
PY
check "shipped templates and examples are clean" 0 ": 0 FAIL, 0 WARN" "$TMP/shipped"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-go-integration-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
