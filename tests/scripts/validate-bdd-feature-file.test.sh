#!/bin/bash
# Tests skills/bdd-feature-file/scripts/validate-bdd-feature-file.sh with
# synthetic files. The three shipped examples are the known-good inputs.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SKILL="$REPO_ROOT/skills/bdd-feature-file"
VALIDATE="$SKILL/scripts/validate-bdd-feature-file.sh"
cd "$SCRATCH_DIR"

# Unpack each example's criteria and feature file into artifacts/<product>/.
python3 - "$SKILL/examples" <<'PY'
import glob, os, re, sys
for f in sorted(glob.glob(sys.argv[1] + "/*.md")):
    blocks = re.findall(r"^````(\w+)\n(.*?)^````", open(f).read(), re.M | re.S)
    crit = next(b for l, b in blocks if l == "markdown")
    feat = next(b for l, b in blocks if l == "gherkin")
    story = re.search(r"# story-id: (\S+)", feat).group(1)
    product = re.search(r"# product: (\S+)", feat).group(1)
    for d, name, body in (("ideate/acceptance-criteria", story + ".md", crit),
                          ("implement/features", story + ".feature", feat)):
        os.makedirs("artifacts/%s/%s" % (product, d), exist_ok=True)
        open("artifacts/%s/%s/%s" % (product, d, name), "w").write(body)
PY

for pair in kerbside:US-4 shelfmark:US-12 paygate:US-31; do
  p="${pair%:*}"; s="${pair#*:}"
  OUTPUT="$("$VALIDATE" "artifacts/$p/implement/features/$s.feature" 2>&1)"; RC=$?
  if [ "$RC" -eq 0 ] && ! echo "$OUTPUT" | grep "^WARN" >/dev/null; then
    _pass "validate-bdd-feature-file: shipped example $p passes cleanly"
  else
    _fail "validate-bdd-feature-file: shipped example $p passes cleanly" "exit $RC: $(echo "$OUTPUT" | grep -E '^(FAIL|WARN)' | head -3)"
  fi
done

BASE=artifacts/kerbside/implement/features/US-4.feature
cp "$BASE" good.feature

# case <name> <expected exit> <grep pattern that must appear> <python edit of t>
case_() {
  local name="$1" want="$2" pattern="$3" edit="$4" out rc
  cp good.feature "$BASE"
  python3 -c "import re,sys; p=sys.argv[1]; t=open(p).read(); $edit; open(p,'w').write(t)" "$BASE"
  out="$("$VALIDATE" "$BASE" 2>&1)"; rc=$?
  if [ "$rc" -eq "$want" ] && echo "$out" | grep -E "$pattern" >/dev/null; then
    _pass "validate-bdd-feature-file: $name"
  else
    _fail "validate-bdd-feature-file: $name" "exit $rc (wanted $want); $(echo "$out" | grep -E '^(FAIL|WARN)' | head -3)"
  fi
}
OK="0 check\(s\) failed"

# L8: the blank template must fail.
cp "$SKILL/templates/feature-file.feature" "$BASE"
OUTPUT="$("$VALIDATE" "$BASE" 2>&1)"; RC=$?
if [ "$RC" -eq 1 ] && echo "$OUTPUT" | grep "FAIL: no unfilled placeholder" >/dev/null; then
  _pass "validate-bdd-feature-file: the blank template fails (L8)"
else
  _fail "validate-bdd-feature-file: the blank template fails (L8)" "exit $RC"
fi
case_ "one leftover placeholder fails" 1 "unfilled placeholder" "t=t.replace('Priya\'s order 17 is being cooked','<precondition>')"
case_ "a bracket placeholder fails" 1 "unfilled placeholder" "t=t.replace('she cancels order 17','[the single action under test]',1)"

# L8: plain business wording must pass.
case_ "'get a refund', 'delete', 'post', 'put' and 'click-and-collect' pass" 0 "$OK" \
  "t=t.replace('But no second refund is made','But no second refund is made\n      And she can still get a refund, delete the post, put it on hold and post a click-and-collect order\n      And she can select a seat from the map and choose the account type')"
case_ "an on-screen message in quotes is not read as technical" 0 "$OK" "t=t.replace('\"Already cooking\"','\"Click here: GET /help\"')"

# L8: tags, including inherited and extra ones, pass.
case_ "tagged files with extra tags on Feature and Rule pass (L8)" 0 "$OK" "t=t.replace('Feature:','@orders\nFeature:').replace('  Rule:','  @cooking\n  Rule:').replace('@happy','@happy @smoke')"
case_ "trailing '# happy' comment fails" 1 "no trailing comment" "t=t.replace('Scenario: An order not yet cooking is cancelled','Scenario: An order not yet cooking is cancelled # happy')"

# Technical wording.
for pair in "an HTTP request|she sends a DELETE request" "an HTTP verb and path|she calls DELETE /orders/17" \
            "a screen click|she clicks Cancel" "a query|she runs SELECT name FROM orders" "a status code|she is answered with HTTP 403"; do
  case_ "${pair%%|*} in a step fails" 1 "no technical wording" "t=t.replace('When she cancels order 17','When ${pair#*|}',1)"
done
case_ "a speed target in a step fails" 1 "speed or availability" "t=t.replace('But no second refund is made','And the answer arrives within 300 ms')"

# Traceability.
case_ "a scenario without a criterion tag fails" 1 "tagged with the criterion" "t=t.replace('@AC-US-4.2 @negative','@negative')"
case_ "an uncovered criterion is named" 1 "has a scenario that runs \(missing: AC-US-4.2\)" "t=t.replace('@AC-US-4.2','@AC-US-4.1')"
case_ "a tag naming no criterion fails" 1 "unknown: AC-US-4.9" "t=t.replace('@AC-US-4.3 @edge','@AC-US-4.3 @AC-US-4.9 @edge')"
case_ "another ID scheme fails" 1 "only the form" "t=t.replace('@AC-US-4.3 @edge','@AC-US-4.3 @AC-001 @edge')"
case_ "a criterion tag on the Rule fails" 1 "no criterion tag on Feature or Rule" "t=t.replace('  Rule:','  @AC-US-4.1\n  Rule:')"
for tag in quarantine wip skip; do
  case_ "a @$tag scenario covers nothing" 1 "missing: AC-US-4.2" "t=t.replace('@AC-US-4.2 @negative','@AC-US-4.2 @negative @$tag')"
done
case_ "a missing angle tag fails" 1 "exactly one of @happy" "t=t.replace('@AC-US-4.3 @edge','@AC-US-4.3')"
case_ "a file with no edge scenario fails" 1 "at least one @edge" "t=t.replace('@AC-US-4.3 @edge','@AC-US-4.3 @negative')"
case_ "a changed value is warned" 0 "WARN: AC-US-4.1 states 17" "t=t.replace('17','18')"

# Structure.
case_ "two When steps fail" 1 "exactly one When" "t=t.replace('When she cancels order 17\n','When she cancels order 17\n      When she signs out\n',1)"
case_ "And after When counts as a second When" 1 "found 2" "t=t.replace('When she cancels order 17\n','When she cancels order 17\n      And she signs out\n',1)"
case_ "a scenario with no Then fails" 1 "has a Then" "t=t.replace('Then she is told \"Already cooking\"\n      But order 17 stays on the cooking list','')"
case_ "a misspelt keyword fails" 1 "not a Gherkin line" "t=t.replace('Then she is told','Thn she is told')"
case_ "a duplicate scenario name fails" 1 "name is unique" "t=t.replace('Scenario: A second cancel changes nothing','Scenario: Cancelling is refused once cooking has started')"
case_ "a When in the Background fails" 1 "Background holds only Given" "t=t.replace('  Rule:','  Background:\n    When she signs in\n\n  Rule:')"
case_ "YAML frontmatter fails" 1 "no YAML frontmatter" "t='---\nname: x\n---\n'+t"
case_ "a missing header field fails" 1 "header has '# summary:'" "t=re.sub(r'# summary:.*\n','',t)"
case_ "a false session claim fails" 1 "no workshop was held" "t=re.sub(r'# Agent-run:.*\n','',t)"

# Outlines.
OUTLINE=artifacts/shelfmark/implement/features/US-12.feature
BASE="$OUTLINE"; cp "$BASE" good.feature
case_ "a repeated Examples row fails" 1 "no repeated Examples row" "t=t.replace('| 2        | refused |','| 2        | refused |\n        | 2        | refused |')"
case_ "a placeholder with no column fails" 1 "has an Examples column" "t=t.replace('renewed <renewals>','renewed <count>')"
case_ "an outline with no rows fails" 1 "header and a row" "t=t.replace('        | 1        | allowed |\n        | 2        | refused |\n','')"
case_ "tags on separate Examples blocks count" 0 "$OK" "t=t.replace('    @AC-US-12.3 @edge\n    Scenario Outline','    Scenario Outline').replace('      Examples:','      @AC-US-12.3 @edge\n      Examples:')"
cp good.feature "$BASE"

# Missing criteria file fails traceability rather than passing silently.
mkdir -p lone && cp good.feature lone/US-12.feature
OUTPUT="$("$VALIDATE" lone/US-12.feature 2>&1)"
if echo "$OUTPUT" | grep "FAIL: the criteria file exists" >/dev/null \
   && "$VALIDATE" lone/US-12.feature artifacts/shelfmark/ideate/acceptance-criteria/US-12.md >/dev/null 2>&1; then
  _pass "validate-bdd-feature-file: no criteria file fails; an explicit criteria path is used"
else
  _fail "validate-bdd-feature-file: no criteria file fails; an explicit criteria path is used" "unexpected result"
fi

# Product mode: every criteria file and every Must Have story needs a feature file.
OUTPUT="$("$VALIDATE" --product artifacts/shelfmark --must US-12 2>&1)"; RC1=$?
cp artifacts/shelfmark/ideate/acceptance-criteria/US-12.md artifacts/shelfmark/ideate/acceptance-criteria/US-13.md
OUTPUT2="$("$VALIDATE" --product artifacts/shelfmark --must US-12,US-14 2>&1)"; RC2=$?
if [ "$RC1" -eq 0 ] && [ "$RC2" -eq 1 ] && echo "$OUTPUT2" | grep "US-13 has criteria, so it needs" >/dev/null \
   && echo "$OUTPUT2" | grep "Must Have US-14 has a criteria file" >/dev/null; then
  _pass "validate-bdd-feature-file: --product finds stories with no feature file or no criteria"
else
  _fail "validate-bdd-feature-file: --product finds stories with no feature file or no criteria" "exits $RC1/$RC2"
fi

"$VALIDATE" /no/such/file.feature >/dev/null 2>&1; A=$?
"$VALIDATE" >/dev/null 2>&1; B=$?
printf '# language: fr\n' > fr.feature; "$VALIDATE" fr.feature >/dev/null 2>&1; C=$?
if [ "$A$B$C" = "222" ]; then
  _pass "validate-bdd-feature-file: usage, missing file and non-English keywords exit 2"
else
  _fail "validate-bdd-feature-file: usage, missing file and non-English keywords exit 2" "got $A $B $C"
fi

smoke_test_summary
