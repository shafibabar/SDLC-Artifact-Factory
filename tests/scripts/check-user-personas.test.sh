#!/bin/bash
# Tests skills/user-persona/scripts/check-user-personas.py — a skill-owned
# script exercised directly with a Markdown file (no model call).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

CHK="$REPO_ROOT/skills/user-persona/scripts/check-user-personas.py"
T="check-user-personas"

# 1. A clean standard set passes.
cat > "$SCRATCH_DIR/ok.md" <<'EOF'
---
name: user-personas
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-23
summary: Office manager is the primary of the reminder queue; the partner buys.
profile: standard
grounding: proto
evidence: none
review-by: 2027-01-15
---

## Persona: Priya, office manager

**Type:** Primary · **Interface:** reminder queue
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the ICP · no user research
**Status:** active

### Job
- **Job statement:** collect overdue payments without damaging the client relationship

### Validation questions
| Attribute | Ask | Wrong if |
|---|---|---|
| Habit | "What did you send last Friday?" | She used the bookkeeping tool's reminders |

## Persona: Martin, managing partner

**Type:** Customer
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the stakeholder map · no user research

### Validation questions
- "When did a client last complain about chasing?"

## Negative Persona: credit-control firms

**Type:** Negative
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the ICP · no user research
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/ok.md")"; rc=$?
[[ $rc -eq 0 && "$out" == *"0 error(s), 0 warning(s)"* ]] && _pass "$T: clean set passes" || _fail "$T: clean set passes" "rc=$rc $out"

# 2. The defects the skill names: Strategy phase, missing review-by, an
#    agent-applied RESEARCH label with no evidence, a bare PROTO, two
#    primaries on one interface, a non-type ("Buyer"), an age field, no
#    validation questions, and a job story outside lean.
cat > "$SCRATCH_DIR/bad.md" <<'EOF'
---
name: user-personas
version: 1.0.0
phase: strategy
owner: requirements-analyst
created: 2026-10-23
summary: Personas.
profile: standard
grounding: research
evidence: none
---

## Persona: Devi

**Type:** Primary · **Interface:** findings view
**Grounding:** RESEARCH — interview-grounded

## Persona: Maya

**Type:** Primary · **Interface:** Findings view
**Grounding:** PROTO — assumption-based
- **Age:** 42
- **Job stories:** When an audit window opens, I want a gap report, so I can brief the CISO.

## Persona: Carl

**Type:** Buyer
**Grounding:** PROTO — assumption-based · written by requirements-analyst (AI) from the map · no user research
EOF
out="$(python3 "$CHK" "$SCRATCH_DIR/bad.md")"; rc=$?
[[ $rc -eq 1 ]] && _pass "$T: defective set exits 1" || _fail "$T: defective set exits 1" "rc=$rc $out"
[[ "$out" == *"phase is 'strategy'"* ]] && _pass "$T: rejects phase strategy" || _fail "$T: rejects phase strategy" "$out"
[[ "$out" == *"missing 'review-by'"* ]] && _pass "$T: requires review-by" || _fail "$T: requires review-by" "$out"
[[ "$out" == *"'Persona: Devi': RESEARCH label with 'evidence: none'"* ]] \
  && _pass "$T: agent-applied RESEARCH" || _fail "$T: agent-applied RESEARCH" "$out"
[[ "$out" == *"'Persona: Maya': PROTO label lacks provenance (written by, from <inputs>, no user research)"* ]] \
  && _pass "$T: bare PROTO label" || _fail "$T: bare PROTO label" "$out"
[[ "$out" == *"'Persona: Maya': shares the Primary interface 'findings view'"* ]] \
  && _pass "$T: one primary per interface" || _fail "$T: one primary per interface" "$out"
[[ "$out" == *"'Persona: Carl': Type 'Buyer' is not one of"* ]] && _pass "$T: six types only" || _fail "$T: six types only" "$out"
[[ "$out" == *"decorative field 'Age'"* ]] && _pass "$T: bans age field" || _fail "$T: bans age field" "$out"
[[ "$out" == *"'Persona: Maya': PROTO persona has no validation questions"* ]] \
  && _pass "$T: PROTO needs validation questions" || _fail "$T: PROTO needs validation questions" "$out"
[[ "$out" == *"WARNING: persona 'Persona: Maya': holds a job story at the standard profile"* ]] \
  && _pass "$T: warns on job story outside lean" || _fail "$T: warns on job story outside lean" "$out"

# 3. At lean, a job story in the persona is expected (JTBD folded in).
sed -e 's/profile: standard/profile: lean/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/lean.md"
printf '%s\n' '- **Job stories:** When 10:30 arrives, I want the order complete, so I can send it.' >> "$SCRATCH_DIR/lean.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/lean.md")"; rc=$?
[[ $rc -eq 0 && "$out" != *"job story"* ]] && _pass "$T: lean keeps job stories" || _fail "$T: lean keeps job stories" "rc=$rc $out"

# 4. No primary at all, and unreadable input.
sed -e 's/\*\*Type:\*\* Primary · \*\*Interface:\*\* reminder queue/**Type:** Secondary/' "$SCRATCH_DIR/ok.md" > "$SCRATCH_DIR/noprimary.md"
out="$(python3 "$CHK" "$SCRATCH_DIR/noprimary.md")"; rc=$?
[[ $rc -eq 1 && "$out" == *"no Primary persona"* ]] && _pass "$T: requires a primary" || _fail "$T: requires a primary" "rc=$rc $out"
python3 "$CHK" "$SCRATCH_DIR/missing.md" >/dev/null 2>&1; r=$?
[[ $r -eq 2 ]] && _pass "$T: unreadable input exits 2" || _fail "$T: unreadable input exits 2" "rc=$r"

# 5. The skill's own worked examples pass.
for ex in "$REPO_ROOT"/skills/user-persona/examples/*.md; do
  python3 - "$ex" "$SCRATCH_DIR/ex.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read()
open(sys.argv[2], "w").write(re.search(r"```markdown\n(.*?)\n```\n", t, re.S).group(1))
PY
  out="$(python3 "$CHK" "$SCRATCH_DIR/ex.md")"; rc=$?
  [[ $rc -eq 0 ]] && _pass "$T: example $(basename "$ex") passes" || _fail "$T: example $(basename "$ex") passes" "$out"
done

smoke_test_summary
