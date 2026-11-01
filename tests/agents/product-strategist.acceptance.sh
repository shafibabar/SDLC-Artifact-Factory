#!/bin/bash
# Proves product-strategist can actually produce real strategy artifacts — a vision
# statement and a strategy kernel — and applies the kernel's shape from the
# strategy-kernel skill (diagnosis, guiding policy, coherent actions; D045 retired the
# mission statement), not just answer a question about it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

STRATEGY_DIR_REL="artifacts/acme-estate/strategy"
VISION="$SCRATCH_DIR/$STRATEGY_DIR_REL/vision-statement.md"

validate_vision_and_kernel() {
  local scratch="$1"
  local dir="$scratch/$STRATEGY_DIR_REL"
  local kernel="$dir/strategy-kernel.md"

  [[ -f "$dir/vision-statement.md" ]] || { echo "missing $STRATEGY_DIR_REL/vision-statement.md"; return 1; }
  [[ -f "$kernel" ]] || { echo "missing $STRATEGY_DIR_REL/strategy-kernel.md"; return 1; }
  [[ ! -f "$dir/mission-statement.md" ]] || { echo "a mission-statement.md was written; D045 retired it"; return 1; }

  # Artifact standard: every produced artifact carries name: and summary: frontmatter.
  local f
  for f in "$dir/vision-statement.md" "$kernel"; do
    grep -q '^name:' "$f" || { echo "$(basename "$f") has no name: frontmatter (artifact standard)"; return 1; }
    grep -q '^summary:' "$f" || { echo "$(basename "$f") has no summary: frontmatter (artifact standard)"; return 1; }
  done

  # The kernel has all three of Rumelt's parts — a goals-only "strategy" fails here.
  grep -qi 'diagnosis' "$kernel" || { echo "strategy-kernel.md has no Diagnosis"; return 1; }
  grep -qi 'guiding policy' "$kernel" || { echo "strategy-kernel.md has no Guiding Policy"; return 1; }
  grep -qi 'coherent actions' "$kernel" || { echo "strategy-kernel.md has no Coherent Actions"; return 1; }
  # ...and the guiding policy rules something out.
  grep -qiE 'rules? out' "$kernel" || { echo "strategy-kernel.md's guiding policy rules nothing out"; return 1; }

  return 0
}

smoke_test_acceptance \
  "agents/product-strategist (acceptance)" \
  "Use the Agent tool to dispatch the 'product-strategist' subagent with exactly this task: for a product called 'Acme Estate' — a data-estate and compliance platform for SMBs (50–500 employees) that maps where sensitive and PII data lives across Google Drive and S3 — produce TWO strategy artifacts using the vision-statement and strategy-kernel skills from this plugin: (1) $STRATEGY_DIR_REL/vision-statement.md and (2) $STRATEGY_DIR_REL/strategy-kernel.md, both under $SCRATCH_DIR. Treat any competitive analysis or stakeholder map as unavailable and state your assumptions in the kernel. Each file must follow its skill's artifact template, including frontmatter. Do not produce any other artifacts, do not ask for approval, just write the two files and stop." \
  "$VISION" \
  validate_vision_and_kernel

smoke_test_summary
