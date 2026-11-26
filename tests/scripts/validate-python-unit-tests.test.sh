#!/bin/bash
# Synthetic-input test for python-unit-test's validate-python-unit-tests.sh.
# Needs only python3.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$SCRIPT_DIR/../../skills/python-unit-test/scripts/validate-python-unit-tests.sh"
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
# one <name> <exit> <regex> <file content>
one() {
  mkdir -p "$TMP/$1"
  printf '%s\n' "$4" > "$TMP/$1/test_x.py"
  expect "$1" "$2" "$3" "$TMP/$1"
}
body() { printf 'async def test_x(repo, m):\n    %s\n    assert 1\n' "$1"; }

one sleep 1 "FAIL SLEEP " "$(body 'await asyncio.sleep(1)')"
one time-sleep 1 "FAIL SLEEP " "$(body 'time.sleep(0.1)')"
one yield-only 0 "0 FAIL" "$(body 'await asyncio.sleep(0)')"
one clock 0 "WARN CLOCK " "$(body 'datetime.now()')"
one rand 0 "WARN RAND " "$(body 'random.randint(1, 2)')"
one seeded 0 "0 FAIL, 0 WARN" "$(body 'random.Random(1).randint(1, 2)')"
one realio-import 1 "FAIL REALIO " "$(printf 'import testcontainers.postgres\n')"
one realio-connect 1 "FAIL REALIO " "$(body 'await asyncpg.connect(url)')"
one broad 1 "FAIL BROAD " "$(printf 'def test_x():\n    with pytest.raises(Exception):\n        f()\n')"
one dead-assert 1 "FAIL DEADASSERT " "$(printf 'def test_x():\n    with pytest.raises(ValueError):\n        f()\n        assert x\n')"
one unittest 1 "FAIL UNITTEST " "$(printf 'class TestX(unittest.TestCase):\n    pass\n')"
one noid 0 "WARN NOID " "$(printf '@pytest.mark.parametrize("v", [1, 2])\ndef test_x(v):\n    assert v\n')"
one ids 0 "0 FAIL, 0 WARN" "$(printf '@pytest.mark.parametrize("v", [pytest.param(1, id="one")])\ndef test_x(v):\n    assert v\n')"
one repo-call 1 "FAIL OWNEDCALL " "$(body 'repo.save.assert_awaited_once()')"
one uow-count 1 "FAIL OWNEDCALL " "$(body 'assert fake_uow.commit.call_count == 1')"
one port-awaited 0 "0 FAIL, 0 WARN" "$(body 'm.send.assert_awaited_once_with(1)')"
one port-called 0 "WARN CALLED " "$(body 'm.send.assert_called_once_with(1)')"
one tuple 1 "FAIL TUPLE " "$(printf 'def test_x():\n    assert (x == 1, "m")\n')"
one private 1 "FAIL PRIVATE " "$(printf 'def test_x():\n    assert asset._state == 1\n')"
one dunder 0 "0 FAIL" "$(printf 'def test_x():\n    assert asset.__class__ is A\n')"
one no-assert 1 "FAIL NOASSERT " "$(printf 'def test_x():\n    f()\n')"
one raises-only 0 "0 FAIL" "$(printf 'def test_x():\n    with pytest.raises(ValueError):\n        f()\n')"
one shadowed 1 "FAIL SHADOWED " "$(printf 'def test_x():\n    assert 1\ndef test_x():\n    assert 1\n')"
one two-classes 0 "0 FAIL" "$(printf 'class TestA:\n    def test_x(self):\n        assert 1\nclass TestB:\n    def test_x(self):\n        assert 1\n')"
one syntax 2 "cannot parse" 'def test_x(:'
mkdir -p "$TMP/empty"
expect "nothing to check" 2 "nothing was checked" "$TMP/empty"
expect "missing path" 2 "no such path" "$TMP/nope"
expect "no arguments" 2 "usage:"
exit "$FAILED"
