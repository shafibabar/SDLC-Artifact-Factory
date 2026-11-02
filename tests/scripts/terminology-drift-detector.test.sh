#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# Non-artifact path -> allow (not in scope), silent
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"/x/CLAUDE.md","content":"outbox pattern"}}' "allow"

# Drifted terms under artifacts/, mixed case -> warn, never blocks
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"/x/artifacts/p/s/v.md","content":"We use the outbox pattern and circuit breaker everywhere. Also OUTBOX PATTERN."}}' \
  "warn" "Transactional Outbox"

# Clean canonical terms -> allow
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"/x/artifacts/p/s/v.md","content":"We use the Transactional Outbox and Circuit Breaker."}}' \
  "allow"

# --- Edit (#1288): the hook runs after the edit and checks the whole file on disk
T="$SCRATCH_DIR/artifacts/p/s/t.md"; mkdir -p "$(dirname "$T")"
printf 'Intro.\n\nWe retry with a circuit breaker.\n' > "$T"
smoke_test_script "terminology-drift-detector" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'","old_string":"Intro.","new_string":"Introduction."}}' \
  "warn" "Circuit Breaker"
printf 'We retry with a Circuit Breaker.\n' > "$T"
smoke_test_script "terminology-drift-detector" \
  '{"tool_name":"Edit","tool_input":{"file_path":"'"$T"'","old_string":"retry","new_string":"retry"}}' \
  "allow"

# --- The product's own banned synonyms (D047-9) ---
# Billing bans "appointment" (its word is Encounter); Scheduling's canonical term
# is Appointment, so the word is a homonym: flagged only inside design/billing/.
P="$SCRATCH_DIR/artifacts/bookwell"
mkdir -p "$P/design/billing" "$P/design/scheduling"
cat > "$P/design/billing/ubiquitous-language.md" <<'MD'
## Terms

| Term | Type | Meaning in this context | Rules | Behaviour | Source |
|---|---|---|---|---|---|
| Encounter | Aggregate Root | A treatment that happened | Immutable | `EncounterRecorded` | po |

## Banned Synonyms

| Banned | Use instead | Renamed in |
|---|---|---|
| appointment, visit | Encounter | nothing built yet |
MD
cat > "$P/design/scheduling/ubiquitous-language.md" <<'MD'
## Terms

| Term | Type | Meaning in this context | Rules | Behaviour | Source |
|---|---|---|---|---|---|
| Appointment | Aggregate Root | A held slot | Can move before it starts | `AppointmentBooked` | wall |
MD

# Inside the banning context: a banned word (and its plural) warns, naming the context
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$P"'/design/billing/invoicing-rules.md","content":"Each visit is invoiced. Appointments are charged."}}' \
  "warn" "banned in the billing Ubiquitous Language"

# Outside any context: "visit" is canonical nowhere -> warns
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$P"'/quality/test-plan.md","content":"Check every visit."}}' \
  "warn" "use 'Encounter'"

# Outside any context: "Appointment" is canonical in Scheduling (a homonym) -> allowed
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$P"'/quality/test-plan.md","content":"Book an Appointment, then record the Encounter."}}' \
  "allow"

# Inside Scheduling, Billing's bans don't apply
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$P"'/design/scheduling/notes.md","content":"An Appointment can move."}}' \
  "allow"

# The language documents themselves list banned words on purpose -> allowed
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$P"'/design/billing/ubiquitous-language.md","content":"| appointment, visit | Encounter |"}}' \
  "allow"

# Whole words only: "revisit" is not "visit"
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$P"'/design/billing/notes.md","content":"We will revisit pricing."}}' \
  "allow"

# A product with no language documents behaves as before
smoke_test_script "terminology-drift-detector" \
  '{"tool_input":{"file_path":"'"$SCRATCH_DIR"'/artifacts/other/design/x/notes.md","content":"Each visit counts."}}' \
  "allow"

smoke_test_summary
