#!/bin/bash
# Synthetic-input test for go-contract-test's API breaking-change gate. A fake
# oasdiff stands in for the real tool, so neither Go nor Docker is needed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-contract-test/scripts/check-openapi-breaking.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# The fake prints its version, logs the arguments of every call, exits with
# FAKE_BREAKING_EXIT for "breaking" and prints FAKE_DIFF for "diff".
mkdir -p "$TMP/bin"
cat > "$TMP/bin/oasdiff" <<'FAKE'
#!/bin/bash
echo "$*" >> "$FAKE_LOG"
case "$1" in
  --version) echo "oasdiff version ${FAKE_VERSION:-1.39.0}" ;;
  breaking) echo "fake breaking output"; exit "${FAKE_BREAKING_EXIT:-0}" ;;
  diff) if [ -n "${FAKE_DIFF:-}" ]; then printf '%s\n' "$FAKE_DIFF"; else echo '{}'; fi ;;
esac
FAKE
chmod +x "$TMP/bin/oasdiff"
export FAKE_LOG="$TMP/calls.log"

cat > "$TMP/spec.yaml" <<'SPEC'
openapi: 3.1.0
info: { title: t, version: 1.0.0 }
paths:
  /v1/classes/{id}:
    get:
      responses:
        "200": { description: ok }
SPEC
printf '{"openapi":"3.1.0","info":{"title":"t","version":"1"},"paths":{"/v1/x":{"get":{"responses":{"200":{"description":"ok"}}}}}}' > "$TMP/spec.json"
: > "$TMP/empty.yaml"
printf 'openapi: 3.1.0\npaths: {}\n' > "$TMP/nopaths.yaml"
printf 'hello: 1\n' > "$TMP/other.yaml"

# check <label> <expected exit> <output pattern or -> [VAR=value ...] -- <script arguments...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  local out rc
  : > "$FAKE_LOG"
  out="$(env PATH="$TMP/bin:$PATH" ${envs[@]+"${envs[@]}"} bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$out"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$out"; FAILURES=$((FAILURES + 1))
  fi
}
# logged <label> <pattern>: the last run called oasdiff with arguments matching the pattern
logged() {
  if grep -qE -- "$2" "$FAKE_LOG"; then echo "PASS: $1"; else echo "FAIL: $1"; cat "$FAKE_LOG"; FAILURES=$((FAILURES + 1)); fi
}

check "no arguments is a usage error" 2 "usage" --
check "base and first-release together" 2 "exactly one" -- --base "$TMP/spec.yaml" --first-release --revision "$TMP/spec.yaml"
check "neither base nor first-release" 2 "exactly one" -- --revision "$TMP/spec.yaml"

check "no change passes" 0 "RESULT: PASS" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml"
logged "oasdiff is asked to fail on warnings" "^breaking --fail-on WARN "
logged "an empty config file is passed" "--config [^ ]*empty\.yaml"
logged "the shipped severity file is passed" "--severity-levels [^ ]*resources/oasdiff-severity\.txt"
check "a JSON description is accepted" 0 "RESULT: PASS" -- --base "$TMP/spec.json" --revision "$TMP/spec.yaml"

check "breaking change fails" 1 "FAIL: breaking change" FAKE_BREAKING_EXIT=1 -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml"
check "oasdiff error is not a pass" 2 "oasdiff exited 102" FAKE_BREAKING_EXIT=102 -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml"
check "wrong oasdiff version" 2 "oasdiff 1.39.0 is required" FAKE_VERSION=1.20.0 -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml"
check "another pinned version can be named" 0 "RESULT: PASS" FAKE_VERSION=1.41.0 -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --oasdiff-version 1.41.0
out="$(env PATH="/usr/bin:/bin" bash "$SCRIPT" --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" 2>&1)"; rc=$?
if [[ $rc -eq 2 ]] && grep -q "cannot run oasdiff" <<<"$out"; then echo "PASS: oasdiff missing is not a pass"; else echo "FAIL: oasdiff missing (exit $rc)"; echo "$out"; FAILURES=$((FAILURES + 1)); fi

check "empty baseline refused" 2 "empty, has no paths or is not an OpenAPI" -- --base "$TMP/empty.yaml" --revision "$TMP/spec.yaml"
check "baseline without paths refused" 2 "has no paths" -- --base "$TMP/nopaths.yaml" --revision "$TMP/spec.yaml"
check "baseline that is not OpenAPI refused" 2 "not an OpenAPI" -- --base "$TMP/other.yaml" --revision "$TMP/spec.yaml"
check "missing baseline is a failure" 2 "cannot read base spec" -- --base "$TMP/none.yaml" --revision "$TMP/spec.yaml"
check "empty revision refused" 2 "not an OpenAPI" -- --base "$TMP/spec.yaml" --revision "$TMP/empty.yaml"
check "first release is stated" 0 "first release: no deployed description" -- --first-release --revision "$TMP/spec.yaml"

cat > "$TMP/exceptions.txt" <<'TXT'
# approved additions
GET /v1/classes/{id} added the new `waitlist` enum value to the `status` response property for the response status `200` | approved-by: A. Owner | approved-on: 2026-11-28
TXT
check "approved exception is printed and passed on" 0 "EXCEPTION line 2: GET /v1/classes" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --exceptions "$TMP/exceptions.txt"
logged "the exceptions file reaches oasdiff" "--err-ignore [^ ]*exceptions\.txt --warn-ignore [^ ]*exceptions\.txt"
echo 'GET /v1/classes/{id} removed the optional property `note` from the response with the `200` status' > "$TMP/unapproved.txt"
check "unapproved exception fails" 1 "FAIL line 1: no 'approved-by:'" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --exceptions "$TMP/unapproved.txt"
echo 'GET /v1/x something | approved-by: A. Owner | approved-on: soon' > "$TMP/nodate.txt"
check "exception without a date fails" 1 "FAIL line 1" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --exceptions "$TMP/nodate.txt"
check "missing exceptions file is a failure" 2 "cannot read exceptions file" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --exceptions "$TMP/none.txt"

GONE='{"paths":{"deleted":["/v1/old"],"modified":{"/v1/classes/{id}":{"operations":{"deleted":["GET"]}}}}}'
check "removed endpoint without a record fails" 1 "/v1/old was removed and has no retirement record" "FAKE_DIFF=$GONE" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml"
cat > "$TMP/retired.txt" <<'TXT'
# method path | sunset | evidence | approval
* /v1/old | sunset: 2026-09-30 | no-caller-evidence: gateway logs for October show no call | approved-by: A. Owner | approved-on: 2026-11-20
GET /v1/classes/{id} | sunset: 2026-10-31 | no-caller-evidence: consumer registry is empty | approved-by: A. Owner | approved-on: 2026-11-20
TXT
check "removed endpoints with records pass" 0 "removed endpoints: 2" "FAKE_DIFF=$GONE" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --retirements "$TMP/retired.txt" --today 2026-11-28
check "sunset not yet reached fails" 1 "sunset date missing or not yet passed" "FAKE_DIFF=$GONE" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --retirements "$TMP/retired.txt" --today 2026-10-01
sed 's/ | approved-by: A. Owner | approved-on: 2026-11-20//' "$TMP/retired.txt" > "$TMP/unsigned.txt"
check "record without sign-off fails" 1 "approved-by or approved-on missing" "FAKE_DIFF=$GONE" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --retirements "$TMP/unsigned.txt" --today 2026-11-28
sed 's/no-caller-evidence: [^|]*|/no-caller-evidence: |/' "$TMP/retired.txt" > "$TMP/noevidence.txt"
check "record without evidence fails" 1 "no-caller-evidence missing" "FAKE_DIFF=$GONE" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --retirements "$TMP/noevidence.txt" --today 2026-11-28
echo 'POST /v1/classes/{id} | sunset: 2026-10-31 | no-caller-evidence: x | approved-by: A | approved-on: 2026-11-20' > "$TMP/wrongmethod.txt"
check "record for another method does not count" 1 "GET /v1/classes/\{id\} was removed and has no retirement record" 'FAKE_DIFF={"paths":{"modified":{"/v1/classes/{id}":{"operations":{"deleted":["GET"]}}}}}' -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml" --retirements "$TMP/wrongmethod.txt" --today 2026-11-28
check "unreadable diff output is not a pass" 2 "did not print JSON" "FAKE_DIFF=not json" -- --base "$TMP/spec.yaml" --revision "$TMP/spec.yaml"

SEVERITY="$REPO_ROOT/skills/go-contract-test/resources/oasdiff-severity.txt"
if grep -qx "response-optional-property-removed err" "$SEVERITY" && grep -qx "response-non-success-status-removed err" "$SEVERITY"; then
  echo "PASS: severity file raises both changes to errors"
else
  echo "FAIL: severity file content"; FAILURES=$((FAILURES + 1))
fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: check-openapi-breaking"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
