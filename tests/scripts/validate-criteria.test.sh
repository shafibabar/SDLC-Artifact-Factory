#!/bin/bash
# Tests skills/acceptance-criteria/scripts/validate-criteria.sh with synthetic
# criteria files and example maps in the real artifacts/<product>/ideate layout.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

SKILL="$REPO_ROOT/skills/acceptance-criteria"
VALIDATE="$SKILL/scripts/validate-criteria.sh"
IDEATE="$SCRATCH_DIR/artifacts/acme/ideate"
mkdir -p "$IDEATE/acceptance-criteria" "$IDEATE/example-maps"
MAP="$IDEATE/example-maps/US-7.md"
GOOD="$IDEATE/acceptance-criteria/US-7.md"
cd "$SCRATCH_DIR"

write_map() {
cat > "$MAP" <<'M'
---
name: example-map
story-id: US-7
readiness: ready
---

# Example Map: US-7 Collect a parcel

## Rules and Examples

### R1: A parcel can be collected for 72 hours
- Source: ideate/requirements.md (BR-4)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | Ana collects on Wednesday | The locker opens | backlog |
| R1.E2 | Negative | Ana collects after 73 hours | Refused | backlog |
| R1.E3 | Edge | Ana collects at 72 hours | The locker opens | backlog |

### R2: One reminder is sent
- Source: product owner (Q-1)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R2.E1 | Happy | Still there after 48 hours | One reminder | product owner |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | Reminder? | R2 | surprise | yes | answered | yes — product owner, 2026-11-25 |
M
}

write_good() {
cat > "$GOOD" <<'C'
---
name: acceptance-criteria
product: acme
story-id: US-7
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Four criteria for collecting a held parcel, drawn from its ready example map.
profile: lean
run: agent-run
traces_to: ideate/user-stories.md (US-7); ideate/example-maps/US-7.md
---

# Acceptance Criteria: US-7 Collect a parcel

## Story Reference

As a resident, I want my parcel held, so that I can collect it when I get home.

## Derived From

- Example map: ideate/example-maps/US-7.md (Ready, 0 open questions)
- Quality targets cited, not restated: NFR-PERF-02

## How These Were Made

Agent-run: one agent (requirements-analyst) drafted these from the map; no workshop was held.

## Happy Path

### AC-US-7.1: Collect inside the hold
- From: R1 (R1.E1)

```gherkin
Given a parcel for Ana was dropped on Monday at 18:00,
When Ana enters her code on Wednesday at 20:00,
Then the locker opens
And Ana sees the parcel marked "Collected" as well
```

### AC-US-7.2: One reminder
- From: R2 (R2.E1)

**Rule:** A resident gets one reminder 24 hours before expiry.
**Verify:** Count the reminders Ana receives for one held parcel.
**Example:** Ana's parcel expires Thursday 18:00; she gets one reminder on Wednesday 18:00.

## Error / Negative Scenarios

### AC-US-7.3: Expired code
- From: R1 (R1.E2)

```gherkin
Given Ana's parcel expired on Thursday at 18:00,
When Ana enters her code on Thursday at 19:00,
Then the locker stays shut
But Ana is not charged
```

## Boundary / Edge Cases

### AC-US-7.4: Exactly on the limit
- From: R1 (R1.E3)

```gherkin
Given Ana's parcel expires on Thursday at 18:00,
When Ana enters her code on Thursday at 18:00,
Then the locker opens
```

## Explicitly Out of Scope

- Extending the hold: US-19.
C
}

write_map; write_good

ok() { # label
  OUT="$("$VALIDATE" "$GOOD" 2>&1)"; RC=$?
  if [ "$RC" -eq 0 ]; then _pass "validate-criteria: $1"; else _fail "validate-criteria: $1" "exit $RC: $(echo "$OUT" | grep FAIL | head -5)"; fi
}
bad() { # label, expected FAIL substring, python expression editing text t
  write_map; write_good
  python3 - "$GOOD" "$3" <<'P'
import re, sys
p = sys.argv[1]; t = open(p).read(); n = eval(sys.argv[2]); assert n != t, "edit did nothing"
open(p, "w").write(n)
P
  OUT="$("$VALIDATE" "$GOOD" 2>&1)"; RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep '^FAIL' | grep -qF -- "$2"; then _pass "validate-criteria: $1"
  else _fail "validate-criteria: $1" "exit $RC; wanted FAIL containing '$2'; got: $(echo "$OUT" | grep FAIL | head -5)"; fi
}
badmap() { # label, expected, python expression editing the map
  write_map; write_good
  python3 - "$MAP" "$3" <<'P'
import re, sys
p = sys.argv[1]; t = open(p).read(); n = eval(sys.argv[2]); assert n != t, "edit did nothing"
open(p, "w").write(n)
P
  OUT="$("$VALIDATE" "$GOOD" 2>&1)"; RC=$?
  if [ "$RC" -eq 1 ] && echo "$OUT" | grep '^FAIL' | grep -qF -- "$2"; then _pass "validate-criteria: $1"
  else _fail "validate-criteria: $1" "exit $RC; wanted FAIL containing '$2'; got: $(echo "$OUT" | grep FAIL | head -5)"; fi
}

ok "a complete file with a real map path (no EM- ID) passes, 'as well' included"

# Path forms
write_good; sed -i 's#Example map: ideate/#Example map: artifacts/acme/ideate/#' "$GOOD"; ok "a map path starting artifacts/<product>/ is accepted"

# A rules-only story passes
write_good
python3 - "$GOOD" <<'P'
import re, sys
p = sys.argv[1]; t = open(p).read()
i = iter(["R1.E1", "R2.E1", "R1.E2", "R1.E3"])
t = re.sub(r"```gherkin.*?```", lambda m: "**Rule:** A parcel is held 72 hours.\n**Verify:** Try the code.\n**Example:** Ana, Wednesday 20:00.", t, flags=re.S)
open(p, "w").write(t)
P
ok "a story written only in the rule format passes"

# Templates must fail (L6)
OUT="$("$VALIDATE" "$SKILL/templates/acceptance-criteria.md" 2>&1)"; RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "FAIL: no unfilled"; then _pass "validate-criteria: the unfilled template fails"; else _fail "validate-criteria: the unfilled template fails" "exit $RC"; fi
cp "$SKILL/templates/acceptance-criteria.md" "$GOOD"
if ! "$VALIDATE" "$GOOD" >/dev/null 2>&1; then _pass "validate-criteria: the template copied to a story path fails"; else _fail "validate-criteria: the template copied to a story path fails" "passed"; fi
: > "$GOOD"
"$VALIDATE" "$GOOD" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 1 ]; then _pass "validate-criteria: an empty file fails"; else _fail "validate-criteria: an empty file fails" "exit $RC"; fi

bad "empty happy section" "'## Happy Path' holds at least one criterion" 're.sub(r"(## Happy Path\n).*?(?=## Error)", r"\1\n", t, flags=re.S)'
bad "empty negative section" "'## Error / Negative Scenarios' holds" 're.sub(r"(## Error / Negative Scenarios\n).*?(?=## Boundary)", r"\1\n", t, flags=re.S)'
bad "missing edge section" "'## Boundary / Edge Cases' holds" 're.sub(r"## Boundary / Edge Cases\n.*?(?=## Explicitly)", "", t, flags=re.S)'
bad "empty gherkin block" "AC-US-7.4: has Given, When and Then" 're.sub(r"Given Ana.s parcel expires.*?opens\n", "", t, flags=re.S)'
bad "heading with no body" "AC-US-7.4: is written as Gherkin or as Rule" 're.sub(r"```gherkin\nGiven Ana.s parcel expires.*?```\n", "", t, flags=re.S)'
bad "rule with empty Verify" "AC-US-7.2: Rule, Verify and Example are filled" 't.replace("**Verify:** Count the reminders Ana receives for one held parcel.", "**Verify:**")'
bad "two When steps" "AC-US-7.1: exactly one When" 't.replace("Then the locker opens\nAnd Ana", "And Ana opens the app,\nThen the locker opens\nAnd Ana", 1)'
bad "angle placeholder" "no unfilled" 't.replace("Then the locker stays shut", "Then <observable outcome>")'
bad "bracket placeholder" "no unfilled" 't.replace("Then the locker stays shut", "Then [error outcome],")'
bad "empty out of scope" "out of scope names at least one" 't.replace("- Extending the hold: US-19.\n", "")'
bad "old ID scheme" "AC-US-n.m" 't.replace("### AC-US-7.1:", "### AC-001:")'
bad "ID of another story" "AC-US-7.m" 't.replace("### AC-US-7.1:", "### AC-US-8.1:")'
bad "duplicate ID" "unique" 't.replace("### AC-US-7.4:", "### AC-US-7.1:")'
bad "stray old-scheme reference" "no other criterion ID scheme" 't.replace("- Extending the hold: US-19.", "- Extending the hold: see AC-002.")'
bad "criterion without From" "AC-US-7.4: From line" 't.replace("- From: R1 (R1.E3)\n", "")'
bad "From cites a missing example" "exist in the map" 't.replace("(R1.E3)", "(R1.E9)")'
bad "map rule with no criterion" "every map rule has a criterion" 't.replace("- From: R2 (R2.E1)", "- From: R1 (R1.E1)")'
bad "red-flag word" "ambiguous word" 't.replace("Then the locker stays shut", "Then the error should be handled properly")'
bad "vague 'works well'" "ambiguous word" 't.replace("Then the locker stays shut", "Then the locker works well")'
bad "HTTP in a criterion" "technical" 't.replace("Then the locker stays shut", "Then GET /parcels returns nothing")'
bad "response time as a criterion" "quality target" 't.replace("Then the locker stays shut", "Then the p95 latency is under 200 ms")'
bad "criterion outside the three angles" "sits under Happy, Negative or Edge" 't.replace("## Explicitly Out of Scope", "## Other\n\n### AC-US-7.9: Extra\n- From: R1 (R1.E1)\n\n## Explicitly Out of Scope")'
write_map; write_good; sed -i 's/Then the locker stays shut/Then the database shows nothing/' "$GOOD"
OUT="$("$VALIDATE" "$GOOD" 2>&1)"; RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^WARN: AC-US-7.3 says 'database'"; then _pass "validate-criteria: a technical word warns without failing"; else _fail "validate-criteria: a technical word warns without failing" "exit $RC"; fi
bad "assumption left in" "no assumption or unknown" 't.replace("Then the locker stays shut", "Then the outcome is unknown (Q-2)")'
bad "old EM- reference" "names the story" 're.sub(r"- Example map: .*", "- Example map: EM-017", t)'
bad "map of another story" "names the story" 't.replace("- Example map: ideate/example-maps/US-7.md", "- Example map: ideate/example-maps/US-8.md")'
bad "no summary" "frontmatter has 'summary'" 're.sub(r"summary: .*\n", "", t)'
bad "claims a session" "one agent" 't.replace("one agent (requirements-analyst) drafted these from the map; no workshop was held.", "the three amigos agreed these.")'
badmap "map not ready" "map is ready" 't.replace("readiness: ready", "readiness: not-ready")'
badmap "map with an open question" "no open question" 't.replace("| answered | yes — product owner, 2026-11-25 |", "| open | — |")'

write_map; write_good; rm "$MAP"
OUT="$("$VALIDATE" "$GOOD" 2>&1)"; RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q "FAIL: the example map file exists"; then _pass "validate-criteria: a missing map file fails"; else _fail "validate-criteria: a missing map file fails" "exit $RC"; fi

write_map; write_good; cp "$GOOD" "$IDEATE/acceptance-criteria/US-7-slug.md"
OUT="$("$VALIDATE" "$IDEATE/acceptance-criteria/US-7-slug.md" 2>&1)"
if echo "$OUT" | grep -q "FAIL: file name is <story-id>.md"; then _pass "validate-criteria: a slugged file name fails"; else _fail "validate-criteria: a slugged file name fails" "no FAIL line"; fi

# Every worked example in the skill passes against its own input map
for ex in "$SKILL"/examples/*.md; do
  OUT="$(python3 - "$ex" "$SCRATCH_DIR/ex/$(basename "$ex" .md)" <<'P'
import os, re, sys
t = open(sys.argv[1]).read(); root = sys.argv[2]
blocks = re.findall(r"^````markdown\n(.*?)^````$", t, re.M | re.S)
out = []
for b in blocks:
    name = re.search(r"^name: (\S+)", b, re.M).group(1)
    sid = re.search(r"^story-id: (\S+)", b, re.M).group(1)
    d = os.path.join(root, "ideate", {"example-map": "example-maps", "acceptance-criteria": "acceptance-criteria"}[name])
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, sid + ".md"); open(p, "w").write(b)
    if name == "acceptance-criteria": out.append(p)
print("\n".join(out))
P
)"
  RC=1; DETAIL="no criteria block"
  for f in $OUT; do DETAIL="$("$VALIDATE" "$f" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] || break; done
  if [ "$RC" -eq 0 ]; then _pass "validate-criteria: $(basename "$ex") output passes"; else _fail "validate-criteria: $(basename "$ex") output passes" "$(echo "$DETAIL" | grep -E 'FAIL|block' | head -5)"; fi
done

"$VALIDATE" /no/such/file.md >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then _pass "validate-criteria: a nonexistent file exits 2"; else _fail "validate-criteria: a nonexistent file exits 2" "got $RC"; fi
"$VALIDATE" >/dev/null 2>&1; RC=$?
if [ "$RC" -eq 2 ]; then _pass "validate-criteria: no argument exits 2"; else _fail "validate-criteria: no argument exits 2" "got $RC"; fi

smoke_test_summary
