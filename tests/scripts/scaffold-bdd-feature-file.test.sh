#!/bin/bash
# Tests skills/bdd-feature-file/scripts/scaffold-bdd-feature-file.sh with
# synthetic criteria and map files.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SCAFFOLD="$REPO_ROOT/skills/bdd-feature-file/scripts/scaffold-bdd-feature-file.sh"
VALIDATE="$REPO_ROOT/skills/bdd-feature-file/scripts/validate-bdd-feature-file.sh"
cd "$SCRATCH_DIR"

check_() { if eval "$2"; then _pass "scaffold-bdd-feature-file: $1"; else _fail "scaffold-bdd-feature-file: $1" "condition failed"; fi; }

check_ "refuses a story with no criteria file" '! "$SCAFFOLD" acme US-9 "Hold a parcel" >/dev/null 2>&1 && [ ! -e artifacts/acme/implement ]'

mkdir -p artifacts/acme/ideate/acceptance-criteria artifacts/acme/ideate/example-maps
cat > artifacts/acme/ideate/example-maps/US-9.md <<'MD'
### R1: A parcel is held for 3 days
MD
cat > artifacts/acme/ideate/acceptance-criteria/US-9.md <<'MD'
## Story Reference

As a recipient, I want to have my parcel held, so that I can collect it later.

## Happy Path

### AC-US-9.1: Collected in time
- From: R1 (R1.E1)

```gherkin
Given a parcel arrived on Monday,
When Ana collects it on Tuesday,
Then she receives the parcel.
```

## Error / Negative Scenarios

### AC-US-9.2: Too late
- From: R1 (R1.E2)

**Rule:** A parcel is held for 3 days.
**Verify:** Collect on day 4.
**Example:** Ana arrives on day 4 and is told it was returned.

## Boundary / Edge Cases

### AC-US-9.3: Last day
- From: R2 (R2.E1)

```gherkin
Given it is the third day,
When Ana collects the parcel,
Then she receives the parcel.
```
MD

OUT="$("$SCAFFOLD" acme 9 'Hold a parcel / locker & "safe"')"
check_ "writes implement/features/US-n.feature" '[ "$OUT" = "artifacts/acme/implement/features/US-9.feature" ] && [ -f "$OUT" ]'
check_ "keeps a title with special characters" 'grep -qxF "Feature: Hold a parcel / locker & \"safe\"" "$OUT"'
check_ "fills the story framing" 'grep -qx "  As a recipient" "$OUT" && grep -qx "  So that I can collect it later" "$OUT"'
check_ "one tagged scenario per criterion with its angle" 'grep -q "@AC-US-9.1 @happy" "$OUT" && grep -q "@AC-US-9.2 @negative" "$OUT" && grep -q "@AC-US-9.3 @edge" "$OUT" && [ "$(grep -c "^    Scenario:" "$OUT")" = 3 ]'
check_ "copies Gherkin steps without trailing punctuation" 'grep -qx "      When Ana collects it on Tuesday" "$OUT"'
check_ "groups by map rule, using the map title" 'grep -qx "  Rule: A parcel is held for 3 days" "$OUT" && grep -qx "  Rule: <R2 in business words>" "$OUT"'
check_ "leaves placeholders for a rule-format criterion" 'grep -q "Given <state from the criterion" "$OUT"'
check_ "does not claim a run mode, and fails validation until finished" 'grep -qx "# run: <agent-run or workshop>" "$OUT" && ! "$VALIDATE" "$OUT" >/dev/null 2>&1'
check_ "refuses to overwrite" '! "$SCAFFOLD" acme US-9 "Hold a parcel" >/dev/null 2>&1'

printf '## Happy Path\n' > artifacts/acme/ideate/acceptance-criteria/US-10.md
check_ "refuses a criteria file with no criterion" '! "$SCAFFOLD" acme US-10 "Empty" >/dev/null 2>&1 && [ ! -e artifacts/acme/implement/features/US-10.feature ]'

"$SCAFFOLD" acme US-9 >/dev/null 2>&1; A=$?
"$SCAFFOLD" acme "Hold a parcel" "x" >/dev/null 2>&1; B=$?
check_ "bad arguments exit 2" '[ "$A$B" = 22 ]'

smoke_test_summary
