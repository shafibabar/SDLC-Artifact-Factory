#!/bin/bash
# Synthetic-input test for go-contract-test's Pact impact report writer. It
# reads saved broker answers, so neither Go, Docker nor a broker is needed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-contract-test/scripts/write-pact-impact-report.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# answer <dir> <file> <deployable: true|false|null> <failed count> <consumer version> <provider version or -> <result: true|false|null>
answer() {
  mkdir -p "$TMP/$1"
  python3 -I - "$TMP/$1/$2" "$3" "$4" "$5" "$6" "$7" <<'PY'
import json, sys
path, deployable, failed, consumer, provider, result = sys.argv[1:]
flag = {"true": True, "false": False, "null": None}
json.dump({
    "summary": {"deployable": flag[deployable], "reason": "broker says | so", "failed": int(failed)},
    "matrix": [{
        "consumer": {"name": "signup", "version": {"number": consumer}},
        "provider": {"name": "classes", "version": None if provider == "-" else {"number": provider}},
        "verificationResult": None if result == "null" else {"success": flag[result]},
    }],
}, open(path, "w"))
PY
}

# check <label> <expected exit> <output pattern or -> <script arguments...>
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

answer green signup.production.json true 0 c4 p9 true
answer green classes.production.json true 0 c4 p9 true
answer broken classes.production.json false 1 c1 p2 false
answer unverified signup.production.json null 0 c2 - null
answer mixed signup.production.json true 0 c4 p9 true
mkdir -p "$TMP/mixed" "$TMP/none"
echo "Error retrieving matrix. Pacticipant classes not found" > "$TMP/mixed/classes.production.json"
echo '[1, 2]' > "$TMP/mixed/billing.test.json"

ARGS=(--product step-studio --date 2026-11-28)
check "no arguments is a usage error" 2 "usage"
check "bad date is a usage error" 2 "usage" --product p --date tomorrow --results "$TMP/green"
check "missing results folder" 2 "cannot read" "${ARGS[@]}" --results "$TMP/absent"
check "empty results folder" 2 "nothing to report" "${ARGS[@]}" --results "$TMP/none"

check "all verified exits 0" 0 "\*\*Every check is verified\.\*\*" "${ARGS[@]}" --results "$TMP/green"
check "frontmatter name" 0 "^name: pact-impact-2026-11-28$" "${ARGS[@]}" --results "$TMP/green"
check "frontmatter summary counts" 0 "^summary: Daily Pact run for step-studio on 2026-11-28: 2 of 2 .* verified, 0 needing attention\.$" "${ARGS[@]}" --results "$TMP/green"
check "frontmatter owner can be set" 0 "^owner: backend-engineer$" "${ARGS[@]}" --results "$TMP/green" --owner backend-engineer
check "flow row names both versions" 0 "^\| production \| signup c4 \| classes p9 \| passed \|$" "${ARGS[@]}" --results "$TMP/green"
check "approval line is present" 0 "^Product owner: " "${ARGS[@]}" --results "$TMP/green"

check "failed verification is BROKEN and exits 1" 1 "^\| classes \| production \| BROKEN \| broker says / so \|$" "${ARGS[@]}" --results "$TMP/broken"
check "failed flow row" 1 "\| signup c1 \| classes p2 \| FAILED \|" "${ARGS[@]}" --results "$TMP/broken"
check "no verification is NOT VERIFIED and exits 1" 1 "^\| signup \| production \| NOT VERIFIED " "${ARGS[@]}" --results "$TMP/unverified"
check "missing provider version is shown" 1 "classes \(no verified version\) \| not verified" "${ARGS[@]}" --results "$TMP/unverified"
check "a broker error is NO RESULT, never a pass" 1 "^\| classes \| production \| NO RESULT " "${ARGS[@]}" --results "$TMP/mixed"
check "JSON of another shape is NO RESULT" 1 "^\| billing \| test \| NO RESULT " "${ARGS[@]}" --results "$TMP/mixed"
check "items needing attention are listed for action" 1 "^- classes in production \(NO RESULT\): " "${ARGS[@]}" --results "$TMP/mixed"
check "summary counts the attention items" 1 "1 of 3 .* verified, 2 needing attention" "${ARGS[@]}" --results "$TMP/mixed"

# The report must satisfy the artifact frontmatter check the plugin applies on write.
bash "$SCRIPT" "${ARGS[@]}" --results "$TMP/green" > "$TMP/report.md"
if python3 -I - "$TMP/report.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
block = re.match(r"---\n(.*?)\n---\n", text, re.S)
keys = re.findall(r"(?m)^([a-z-]+):", block.group(1)) if block else []
sys.exit(0 if all(k in keys for k in ("name", "version", "phase", "owner", "created", "summary")) else 1)
PY
then echo "PASS: report carries the six artifact frontmatter fields"; else echo "FAIL: frontmatter fields"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: write-pact-impact-report"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
