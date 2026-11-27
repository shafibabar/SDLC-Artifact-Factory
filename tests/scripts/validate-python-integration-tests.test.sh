#!/bin/bash
# Synthetic-input test for python-integration-test's validator. Needs python3 only:
# no packages and no Docker. Skips clearly when python3 is missing.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/python-integration-test/scripts/validate-python-integration-tests.sh"
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not installed; validate-python-integration-tests.sh not tested"
  exit 0
fi
TMP="$(mktemp -d)" || exit 1
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

# one <label> <file name> <expected exit> <pattern>  (file body on stdin)
one() {
  local dir; dir="$(mktemp -d "$TMP/c.XXXXXX")"
  mkdir -p "$dir/tests/integration"
  printf 'import pytest\n\n@pytest.hookimpl(tryfirst=True)\ndef pytest_collection_modifyitems(items):\n    for i in items:\n        i.add_marker(pytest.mark.integration)\n' > "$dir/tests/integration/conftest.py"
  cat > "$dir/tests/integration/$2"
  check "$1" "$3" "$4" "$dir"
}

check "no arguments is a usage error" 2 "usage"
check "missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty/tests/unit"; echo "x = 1" > "$TMP/empty/tests/unit/test_a.py"
check "nothing to check is not a pass" 2 "nothing was checked" "$TMP/empty"
one "unparseable file" test_bad.py 2 "cannot read or parse" <<'EOF'
def broken(:
EOF

one "clean test passes" test_ok.py 0 "0 FAIL, 0 WARN" <<'EOF'
"""Docstring mentioning TRUNCATE jobs and DATABASE_URL is not a finding."""
import asyncio

async def test_ok(db, monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "x")
    await db.execute("DELETE FROM jobs WHERE id = $1", 1)
    await asyncio.sleep(0)
    while not await db.fetchval("SELECT 1"):
        await asyncio.sleep(0.02)
EOF
for read in 'os.environ["DATABASE_URL"]' 'os.environ.get("DATABASE_URL")' 'os.getenv("KAFKA_BOOTSTRAP_SERVERS")'; do
  one "address from the environment: $read" test_a.py 1 "FAIL DBURL" <<<"import os
URL = $read"
done
one "sleeping outside a poll" test_a.py 1 "FAIL SLEEP" <<'EOF'
import asyncio
async def test_a():
    await asyncio.sleep(1)
EOF
one "imported sleep" test_a.py 1 "FAIL SLEEP" <<'EOF'
from time import sleep
def test_a():
    sleep(2)
EOF
one "truncate" test_a.py 1 "FAIL RESET" <<'EOF'
async def test_a(db):
    await db.execute("TRUNCATE TABLE jobs")
EOF
one "unfiltered delete in an f-string" test_a.py 1 "FAIL RESET" <<'EOF'
async def test_a(db, table="jobs"):
    await db.execute(f"DELETE FROM {table}")
EOF
one "latest image" harness.py 1 "FAIL IMAGE" <<'EOF'
IMAGE = "postgres:latest"
EOF
one "container with the default image" harness.py 1 "FAIL IMAGE" <<'EOF'
c = PostgresContainer()
EOF
one "untagged image" harness.py 1 "FAIL IMAGE" <<'EOF'
c = RedpandaContainer("redpandadata/redpanda")
EOF
one "substitute engine" test_a.py 1 "FAIL FAKEDB" <<'EOF'
import mongomock
EOF
one "harness skips without Docker" conftest.py 1 "FAIL DOCKERSKIP" <<'EOF'
import pytest
def server():
    pytest.skip("no docker")
EOF
one "retry marker" test_a.py 1 "FAIL RETRY" <<'EOF'
import pytest
@pytest.mark.flaky(reruns=3)
def test_a(): pass
EOF
one "swallowed cleanup error" test_a.py 1 "FAIL SWALLOW" <<'EOF'
async def test_a(db):
    try:
        await db.close()
    except Exception:
        pass
EOF
one "suppressed errors" test_a.py 1 "FAIL SWALLOW" <<'EOF'
import contextlib
async def test_a(db):
    with contextlib.suppress(Exception):
        await db.close()
EOF
one "doubles warn only" test_a.py 0 "WARN DOUBLE" <<'EOF'
from unittest.mock import AsyncMock
from tests.fakes import FakeUnitOfWork
repo = AsyncMock()
EOF
one "test client warns" test_a.py 0 "WARN TESTCLIENT" <<'EOF'
from fastapi.testclient import TestClient
EOF
one "old import path warns" test_a.py 0 "WARN OLDAPI" <<'EOF'
from testcontainers.postgres import PostgresContainer
EOF
one "fixed port warns" test_a.py 0 "WARN FIXEDPORT" <<'EOF'
URL = "postgresql://test@localhost:5432/app"
EOF
one "skip in a test warns" test_a.py 0 "WARN SKIP" <<'EOF'
import pytest
def test_a():
    pytest.skip("later")
EOF
one "sqlite warns" test_a.py 0 "WARN SQLITE" <<'EOF'
import sqlite3
EOF

mkdir -p "$TMP/m/tests/integration"; echo "def test_a(): pass" > "$TMP/m/tests/integration/test_a.py"
check "no marker anywhere warns" 0 "WARN NOMARK" "$TMP/m"
printf 'import pytest\npytestmark = pytest.mark.integration\ndef test_a(): pass\n' > "$TMP/m/tests/integration/test_a.py"
check "module marker is enough" 0 "0 FAIL, 0 WARN" "$TMP/m"

mkdir -p "$TMP/s/tests/integration" "$TMP/s/src/app"; cp "$TMP/m/tests/integration/test_a.py" "$TMP/s/tests/integration/"
echo "from tests.integration.harness import PostgresServer" > "$TMP/s/src/app/wiring.py"
check "shipped code importing tests fails" 1 "FAIL SHIPPED .*wiring.py:1" "$TMP/s"
rm "$TMP/s/src/app/wiring.py"
printf '[tool.pytest.ini_options]\naddopts = "-q -m \x27not integration\x27"\n' > "$TMP/s/pyproject.toml"
check "deselecting in addopts fails" 1 "FAIL DESELECT" "$TMP/s"
printf '[tool.pytest.ini_options]\naddopts = [\n  "--reruns", "2",\n]\n' > "$TMP/s/pyproject.toml"
check "reruns in addopts fails" 1 "FAIL RETRY" "$TMP/s"
printf '[tool.pytest.ini_options]\naddopts = "-q"\nmarkers = ["integration: not integration with -m"]\n' > "$TMP/s/pyproject.toml"
check "ordinary settings pass" 0 "0 FAIL" "$TMP/s"
mkdir -p "$TMP/o/tests/infrastructure"; printf 'import time\ndef test_a():\n    time.sleep(1)\n' > "$TMP/o/tests/infrastructure/test_repo.py"
check "a named file below tests is checked" 1 "FAIL SLEEP" "$TMP/o/tests/infrastructure/test_repo.py"

if [[ $FAILURES -eq 0 ]]; then echo "All validate-python-integration-tests checks passed"; else echo "$FAILURES check(s) failed"; exit 1; fi
