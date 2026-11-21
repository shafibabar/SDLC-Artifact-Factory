#!/bin/bash
# Proves domain-modeler can produce a real Event Storming Big Picture in agent-run
# mode (D047-8) from named artifacts, using event-storming-facilitation's template,
# and that the result passes the skill's own validator — the end of the skill's
# validate → fix → re-validate loop. The validator checks the structural items:
# a source on every card, boundary candidates with evidence at lean, hotspots kept
# open as questions for the product owner, and no aggregates in a Big Picture.
# Live `claude` CLI dispatch -- slow. Run with SMOKE_TEST_TIMEOUT=300.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

PRODUCT_REL="artifacts/kettlewise"
BIG_PICTURE="$SCRATCH_DIR/$PRODUCT_REL/design/event-storming/big-picture.md"
VALIDATE="$REPO_ROOT/skills/event-storming-facilitation/scripts/validate-event-storming.sh"

# Fixture inputs: a small lean product, written here so the test pins no skill prose.
mkdir -p "$SCRATCH_DIR/$PRODUCT_REL/strategy" "$SCRATCH_DIR/$PRODUCT_REL/ideate"
cat > "$SCRATCH_DIR/$PRODUCT_REL/strategy/vision.md" <<'EOF'
---
name: vision-statement
version: 1.0.0
phase: strategy
owner: product-strategist
created: 2026-01-02
summary: Kettlewise sends one independent tea shop's loose-leaf subscribers a monthly box they can skip or swap before it is packed.
---
# Vision: Kettlewise
For the regular customers of Fennick's Teas, a single shop with about 300 subscribers, Kettlewise is a monthly loose-leaf box they can tailor before it ships. Subscribers choose teas until the shop packs the boxes on the 20th; boxes are posted on the 22nd; payment is taken when the box is packed.
EOF
cat > "$SCRATCH_DIR/$PRODUCT_REL/ideate/job-stories.md" <<'EOF'
---
name: job-stories
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-01-03
summary: Five job stories for Kettlewise subscribers and the shop owner.
---
# Job Stories
- J1: When I sign up, I want to pick a plan (3 or 5 teas) so that I pay for what I drink.
- J2: When the new month's teas are announced, I want to swap teas in my box so that I avoid ones I dislike.
- J3: When I'm away, I want to skip a month so that I'm not charged.
- J4 (shop owner): When the 20th arrives, I want a packing list of every box so that I pack them in one afternoon.
- J5 (shop owner): When a tea runs out after people chose it, I want to offer a substitute so that boxes still go out on time.
EOF

validate_big_picture() {
  local scratch="$1"
  local f="$scratch/$PRODUCT_REL/design/event-storming/big-picture.md"
  [[ -f "$f" ]] || { echo "missing $PRODUCT_REL/design/event-storming/big-picture.md"; return 1; }
  local out
  if ! out="$("$VALIDATE" "$f" 2>&1)"; then
    echo "the Big Picture fails the skill's validator: $(echo "$out" | grep FAIL | head -5 | tr '\n' ' ')"
    return 1
  fi
  # Agent-run honesty: with no session held, the wall must be marked agent-run.
  grep -qE '^mode: *agent-run' "$f" || { echo "frontmatter mode is not agent-run"; return 1; }
  return 0
}

smoke_test_acceptance \
  "agents/domain-modeler (acceptance)" \
  "Use the Agent tool to dispatch the 'domain-modeler' subagent with exactly this task: for the product 'kettlewise' at the lean profile, whose artifacts are under $SCRATCH_DIR/$PRODUCT_REL (strategy/vision.md and ideate/job-stories.md), run an Event Storming Big Picture in agent-run mode using this plugin's event-storming-facilitation skill. No domain experts are available. Write the transcript to $BIG_PICTURE using the skill's Big Picture template, and follow the skill's procedure through its validation step (run its validator, fix every failure, re-run until clean). Do not run any later Design step, do not classify subdomains, do not ask for approval: write the one file and stop." \
  "$BIG_PICTURE" \
  validate_big_picture

smoke_test_summary
