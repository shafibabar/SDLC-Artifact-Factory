#!/bin/bash
# Proves the product-strategist agent can actually invoke the vision-statement
# skill and produce the real artifact it exists to produce — not just answer
# a question about the skill's content (that's the .contract.sh tier).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

TARGET="$SCRATCH_DIR/artifacts/testproduct/strategy/vision-statement.md"

validate_vision_statement() {
  local scratch="$1"
  local file="$scratch/artifacts/testproduct/strategy/vision-statement.md"

  assert_frontmatter_field "$file" "name" || return 1
  assert_frontmatter_field "$file" "product" || return 1
  assert_frontmatter_field "$file" "version" || return 1
  assert_frontmatter_field "$file" "phase" || return 1
  assert_frontmatter_field "$file" "created" || return 1
  assert_frontmatter_field "$file" "owner" || return 1

  assert_contains "$file" "# Vision Statement" || return 1
  assert_contains "$file" "## Rationale" || return 1
  assert_contains "$file" "## North Star Implication" || return 1
  assert_contains "$file" "Target user" || return 1
  assert_contains "$file" "Unmet need" || return 1
  assert_contains "$file" "Product category" || return 1
  assert_contains "$file" "Key benefit" || return 1
  assert_contains "$file" "Differentiation" || return 1

  local vision_text
  vision_text="$(awk '/^# Vision Statement/{f=1; next} /^## Rationale/{f=0} f' "$file")"
  if [[ -z "$(tr -d '[:space:]' <<<"$vision_text")" ]]; then
    echo "vision statement body is empty between '# Vision Statement' and '## Rationale'"
    return 1
  fi
  assert_word_count_at_most "$vision_text" 60 || return 1

  return 0
}

smoke_test_acceptance \
  "skills/vision-statement (acceptance)" \
  "Use the Agent tool to dispatch the 'product-strategist' subagent with exactly this task: using ONLY the vision-statement skill from this plugin, produce a vision statement for this project's first product. Read the problem statement from sdlc-context.json's first_product section (name: Data Estate Mapping and Compliance Intelligence). Follow the skill's own Output Format template exactly: frontmatter with name/product/version/phase/created/owner, then a '# Vision Statement' heading with the vision itself (at or under 60 words, per the skill's own Length quality criterion), then a '## Rationale' heading with Target user / Unmet need / Product category / Key benefit / Differentiation, then a '## North Star Implication' heading. Write the result to exactly this path using the Write tool: $TARGET — Do not produce any other strategy artifact, do not ask for approval or confirmation, just write this one file and then stop." \
  "$TARGET" \
  validate_vision_statement

smoke_test_summary
