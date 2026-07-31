#!/bin/bash
# Proves product-strategist can actually produce real strategy artifacts — a vision
# statement and a mission statement — and applies the mission-vs-vision distinction
# from the refactored mission-statement/vision-statement skills (not just answer a
# question about them; that's the .contract.sh tier).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

STRATEGY_DIR_REL="artifacts/acme-estate/strategy"
VISION="$SCRATCH_DIR/$STRATEGY_DIR_REL/vision-statement.md"
MISSION="$SCRATCH_DIR/$STRATEGY_DIR_REL/mission-statement.md"

validate_vision_and_mission() {
  local scratch="$1"
  local dir="$scratch/$STRATEGY_DIR_REL"

  [[ -f "$dir/vision-statement.md" ]] || { echo "missing $STRATEGY_DIR_REL/vision-statement.md"; return 1; }
  [[ -f "$dir/mission-statement.md" ]] || { echo "missing $STRATEGY_DIR_REL/mission-statement.md"; return 1; }

  # Artifact standard: every produced artifact carries a name: frontmatter field.
  grep -q '^name:' "$dir/vision-statement.md" || { echo "vision-statement.md has no name: frontmatter (artifact standard)"; return 1; }
  grep -q '^name:' "$dir/mission-statement.md" || { echo "mission-statement.md has no name: frontmatter (artifact standard)"; return 1; }

  # The mission-vs-vision distinction was applied: the two artifacts are not the same text.
  # A copy-pasted mission==vision means the refactored distinction was not honoured.
  if diff -q <(grep -vE '^(name|version|phase|owner|created):' "$dir/vision-statement.md") \
             <(grep -vE '^(name|version|phase|owner|created):' "$dir/mission-statement.md") >/dev/null; then
    echo "vision and mission body content is identical — the mission-vs-vision distinction was not applied"
    return 1
  fi

  # Each artifact has a real body beyond frontmatter (not an empty stub).
  local vbody mbody
  vbody=$(grep -vcE '^(---|name:|version:|phase:|owner:|created:|tags:|\s*)$' "$dir/vision-statement.md")
  mbody=$(grep -vcE '^(---|name:|version:|phase:|owner:|created:|tags:|\s*)$' "$dir/mission-statement.md")
  [[ "$vbody" -ge 2 ]] || { echo "vision-statement.md has no substantive body"; return 1; }
  [[ "$mbody" -ge 2 ]] || { echo "mission-statement.md has no substantive body"; return 1; }

  return 0
}

smoke_test_acceptance \
  "agents/product-strategist (acceptance)" \
  "Use the Agent tool to dispatch the 'product-strategist' subagent with exactly this task: for a product called 'Acme Estate' — a data-estate and compliance platform for SMBs (50–500 employees) that maps where sensitive and PII data lives across Google Drive and S3 — produce TWO strategy artifacts using the vision-statement and mission-statement skills from this plugin: (1) $STRATEGY_DIR_REL/vision-statement.md and (2) $STRATEGY_DIR_REL/mission-statement.md, both under $SCRATCH_DIR. Apply the mission-vs-vision distinction: the vision is the future world-state the product is working toward; the mission is the enduring present-day purpose that pursues it — they must be distinct, not the same text. Each file must have a frontmatter block with at least a name: field and then a substantive body. Do not produce any other artifacts, do not ask for approval, just write the two files and stop." \
  "$VISION" \
  validate_vision_and_mission

smoke_test_summary
