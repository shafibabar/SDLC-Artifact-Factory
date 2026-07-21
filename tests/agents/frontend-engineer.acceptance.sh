#!/bin/bash
# Proves frontend-engineer can actually invoke react-component-design and
# produce a real, compiling React+TypeScript component — not just answer a
# question about the skill's content (that's the .contract.sh tier).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

COMPONENT_REL="src/shared/ui/SensitivityBadge.tsx"
TEST_REL="src/shared/ui/SensitivityBadge.test.tsx"
COMPONENT="$SCRATCH_DIR/$COMPONENT_REL"

validate_react_component() {
  local scratch="$1"
  local component="$scratch/$COMPONENT_REL"
  local test_file="$scratch/$TEST_REL"

  [[ -f "$component" ]] || { echo "missing $COMPONENT_REL"; return 1; }
  [[ -f "$test_file" ]] || { echo "missing $TEST_REL (TDD is non-negotiable per this repo's rules)"; return 1; }

  assert_not_contains "$component" ": any" || return 1
  assert_not_contains "$component" "<any>" || return 1
  assert_contains "$component" "interface" || assert_contains "$component" "type " || return 1

  assert_ts_valid "$component" "$scratch" || return 1
  return 0
}

smoke_test_acceptance \
  "agents/frontend-engineer (acceptance)" \
  "Use the Agent tool to dispatch the 'frontend-engineer' subagent with exactly this task: using the react-component-design skill from this plugin, implement a small presentational atom component 'SensitivityBadge' with this prop contract: a single required prop 'level' typed as the union 'Public' | 'Internal' | 'Confidential' | 'Restricted', rendering a small badge with that label and level-appropriate styling. No data fetching, no network calls — this is a pure presentational atom per the skill's Presentational vs Container section. Follow the skill's own Output Format and Atomic Design conventions exactly, writing these two files under $SCRATCH_DIR/src/shared/ui/: SensitivityBadge.tsx and SensitivityBadge.test.tsx (React Testing Library, written first per TDD). Type the props with an explicit interface — no 'any'. This is a standalone scratch project; do not run npm install, tsc, or any tests yourself after writing the files — validation happens separately. Do not produce anything else, do not ask for approval, just write the two files and stop." \
  "$COMPONENT" \
  validate_react_component

smoke_test_summary
