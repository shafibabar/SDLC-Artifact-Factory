#!/bin/bash
# Synthetic-input test for python-contract-test's own copy of the Pact impact
# report writer. It reads saved broker answers, so neither Docker nor a broker
# is needed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-contract-test/scripts/write-pact-impact-report.sh"
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

# Answers in the shape the `pact broker` command (Pact CLI 1.0.0) printed in
# the run for this skill: extra fields, a null verification result for a commit
# no run recorded, and plain text when the service is unknown.
mkdir -p "$TMP/cli"
cat > "$TMP/cli/plots.production.json" <<'JSON'
{"matrix":[{"consumer":{"name":"rentals","version":{"number":"c1","branch":"main","tags":[]}},"pact":{"createdAt":"2026-11-27T22:29:37+00:00"},"provider":{"name":"plots","version":{"number":"p2","branch":"main"}},"verificationResult":{"success":false,"verifiedAt":"2026-11-27T22:40:00+00:00"}}],"summary":{"deployable":false,"failed":1,"reason":"The verification for the pact between the version of rentals currently in production (c1) and version p2 of plots failed","success":0,"unknown":0}}
JSON
cat > "$TMP/cli/rentals.production.json" <<'JSON'
{"matrix":[{"consumer":{"name":"rentals","version":{"number":"c1"}},"pact":{},"provider":{"name":"plots","version":null},"verificationResult":null}],"summary":{"deployable":false,"failed":0,"reason":"No pacts or verifications have been published for version c9 of rentals","success":0,"unknown":1}}
JSON
printf '\xe2\x9d\x8c Pacticipant sheds not found\n' > "$TMP/cli/sheds.production.json"
check "CLI answer with a failed verification is BROKEN" 1 "^\| plots \| production \| BROKEN \| The verification for the pact" "${ARGS[@]}" --results "$TMP/cli"
check "CLI answer for a commit no run recorded is NOT VERIFIED" 1 "^\| rentals \| production \| NOT VERIFIED \| No pacts or verifications" "${ARGS[@]}" --results "$TMP/cli"
check "CLI text for an unknown service is NO RESULT" 1 "^\| sheds \| production \| NO RESULT " "${ARGS[@]}" --results "$TMP/cli"

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

# The program is language-neutral and shared with go-contract-test: each skill
# owns its copy, and the two must stay the same. Change both together.
if python3 -I - "$SCRIPT" "$REPO_ROOT/skills/go-contract-test/scripts/write-pact-impact-report.sh" <<'PY'
import sys
body = lambda path: open(path, encoding="utf-8").read().split("<<'PY'\n", 1)[1]
sys.exit(0 if body(sys.argv[1]) == body(sys.argv[2]) else 1)
PY
then echo "PASS: the program is identical to go-contract-test's copy"; else echo "FAIL: write-pact-impact-report.sh differs from go-contract-test's copy; change both together"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: python-contract-test write-pact-impact-report"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
