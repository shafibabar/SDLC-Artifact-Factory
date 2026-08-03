#!/bin/bash
# Proves data-architect can actually invoke data-retention-policy and produce a
# real, conforming retention & disposal policy -- not just answer a question
# about the skill's content (that's the .contract.sh tier).
#
# The three facts probed are ones a model working from generic data-governance
# and "GDPR common sense" gets WRONG, and are exactly what the skill exists to
# pin down:
#
#   1. Precedence. The skill states one absolute ordering:
#        legal hold  >  retention window  >  erasure request
#      Generic reasoning ranks a data-subject erasure request (Art. 17, "the
#      right to be forgotten") at the top -- it feels supreme. It is not: a
#      legal hold suspends deletion even against an erasure request, and
#      deleting held data during litigation is an incident with no undo. The
#      prompt asks for the ranking and dictates only its FORMAT, never its
#      order, so a pass is evidence the order came from the skill.
#   2. Immutable backups are erased by DESTROYING THE ENCRYPTION KEY
#      (crypto-shredding), not by a row-level delete. An immutable snapshot
#      cannot be edited row-by-row; a policy that says "delete the row from
#      backups" is describing something the storage layer cannot do.
#   3. Erasure FOLLOWS FORWARD LINEAGE to every derived artifact. The generic
#      answer deletes the primary record and relies on FK cascades; the skill
#      names that "erasure theatre" -- derived entities, graph vertices,
#      projections, and reports survive a cascade that never reached them.
#
# The prompt supplies the scenario (stores, data classes) as facts and asks for
# what the skill's standard requires; it never names crypto-shredding, lineage,
# or the precedence order.
#
# Live `claude` CLI dispatch -- slow. Run with SMOKE_TEST_TIMEOUT=300.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

DESIGN_DIR_REL="artifacts/acme-estate/design"
POLICY="$SCRATCH_DIR/$DESIGN_DIR_REL/data-retention-policy.md"

validate_retention_policy() {
  local scratch="$1"
  local file="$scratch/$DESIGN_DIR_REL/data-retention-policy.md"

  [[ -f "$file" ]] || { echo "missing $DESIGN_DIR_REL/data-retention-policy.md"; return 1; }

  # Artifact standard: every produced artifact carries a name: frontmatter field.
  grep -q '^name:' "$file" || { echo "data-retention-policy.md has no name: frontmatter (artifact standard)"; return 1; }

  python3 - "$file" <<'PY'
import re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
flat = re.sub(r"\s+", " ", text)
low = flat.lower()
errors = []

# --- 1. Precedence chain: legal hold > retention window > erasure request ---
chain = None
for m in re.finditer(r"([^>|\n]{1,80})>([^>|\n]{1,80})>([^>|\n]{1,80})", flat):
    parts = [p.strip().strip("*`_").lower() for p in m.groups()]
    if any("hold" in p for p in parts) and any("erasure" in p or "erase" in p for p in parts):
        chain = parts
        break

if chain is None:
    errors.append("no 'A > B > C' precedence chain naming a legal hold and an erasure request was found")
else:
    if "hold" not in chain[0]:
        errors.append("precedence chain does not rank the legal hold first: %r" % (chain,))
    if "retention window" not in chain[1] and "retention" not in chain[1]:
        errors.append("precedence chain does not rank the retention window second: %r" % (chain,))
    if "erasure" not in chain[2] and "erase" not in chain[2]:
        errors.append("precedence chain does not rank the erasure request last: %r" % (chain,))

# --- 2. Immutable backups disposed of by destroying the encryption key ---
crypto = re.search(
    r"crypto[- ]?shred"
    r"|key[- ]destruction"
    r"|destroy\w*\s+(?:the\s+)?(?:per-\w+\s+)?(?:encryption\s+|tenant\s+|subject\s+)*key"
    r"|(?:encryption\s+)?key\s+(?:is\s+)?destr",
    low,
)
if not crypto:
    errors.append("backup disposal does not use key destruction / crypto-shredding")

# A row-level delete claimed against immutable snapshots is the failure mode.
if re.search(r"(delete|purge|remove)\s+(the\s+)?rows?\s+from\s+(the\s+)?backup", low):
    errors.append("policy claims row-level deletion from immutable backup snapshots")

# --- 3. Erasure scoped by forward lineage, not just the primary record ---
if "lineage" not in low:
    errors.append("erasure procedure never mentions lineage as the way derived data is located")
elif not re.search(
    r"lineage[^.]{0,160}?(derived|downstream|forward|everywhere|every (copy|store|artifact))"
    r"|(forward|derived|downstream)[^.]{0,160}?lineage",
    low,
):
    errors.append("lineage is mentioned but not used to locate derived/downstream data for erasure")

# --- Sanity: it is a real document, not a stub ---
body = [l for l in text.splitlines() if l.strip() and not l.strip().startswith("---")]
if len(body) < 15:
    errors.append("document has no substantive body (%d non-blank lines)" % len(body))

if errors:
    for e in errors:
        print("  - " + e)
    sys.exit(1)
sys.exit(0)
PY
}

smoke_test_acceptance \
  "agents/data-architect (acceptance)" \
  "Use the Agent tool to dispatch the 'data-architect' subagent with exactly this task: for a product called 'Acme Estate' — a data-estate and compliance platform that maps where sensitive and PII data lives across a customer's Google Drive and S3 — produce ONE design artifact at $SCRATCH_DIR/$DESIGN_DIR_REL/data-retention-policy.md using the data-retention-policy skill from this plugin. The design already fixed these facts, use them as given: the data classes held are audit log, compliance report, data-asset record, extracted entity metadata, personal data (PII), and operational telemetry; the stores are PostgreSQL, an Apache AGE graph projection, an Elasticsearch index, Redpanda topics, and a nightly immutable encrypted backup snapshot; extracted entities and compliance findings are derived from the source data assets by the pipeline. The artifact must contain: (a) a frontmatter block with at least a name: field; (b) a retention schedule table giving each data class a window, a basis, and a disposition; (c) a section headed '## Precedence' that states, as a single ordered chain in the exact form 'A > B > C' with the highest-precedence item first, how the skill's standard ranks these three against one another — a legal hold, the retention window, and a data-subject erasure request — followed by one sentence of justification; (d) an erasure procedure describing how the design locates everything that must be erased when a data subject exercises the right to erasure; and (e) a cross-store disposal table naming the disposal mechanism for every store listed above. Do not produce any other artifacts, do not ask for approval, just write that one file and stop." \
  "$POLICY" \
  validate_retention_policy

smoke_test_summary
