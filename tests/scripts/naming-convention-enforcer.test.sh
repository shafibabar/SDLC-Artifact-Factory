#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

# Valid flat skill path -> allow
smoke_test_script "naming-convention-enforcer" \
  '{"tool_input":{"file_path":"/x/skills/valid-name/SKILL.md"}}' "allow"

# Invalid skill name -> deny
smoke_test_script "naming-convention-enforcer" \
  '{"tool_input":{"file_path":"/x/skills/BadName/SKILL.md"}}' "deny" "does not match"

# Old 2-level domain-nested path -> allow (not in scope; that structure no longer exists)
smoke_test_script "naming-convention-enforcer" \
  '{"tool_input":{"file_path":"/x/skills/domain/name/SKILL.md"}}' "allow"

# Valid/invalid across the other 3 component types
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/agents/valid-name.md"}}' "allow"
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/agents/BadName.md"}}' "deny"
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/commands/valid-name.md"}}' "allow"
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/commands/bad_name.md"}}' "deny"
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/scripts/valid-name.sh"}}' "allow"
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/scripts/Bad-Name.sh"}}' "deny"

# Unrelated path -> allow (not in scope)
smoke_test_script "naming-convention-enforcer" '{"tool_input":{"file_path":"/x/README.md"}}' "allow"

# Malformed JSON -> fail open
output="$(echo 'not json' | "$REPO_ROOT/scripts/naming-convention-enforcer.sh" 2>&1)"
if [[ "$output" == *'"continue": true'* ]]; then
  echo "PASS: scripts/naming-convention-enforcer (case: malformed-input-fails-open)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "FAIL: scripts/naming-convention-enforcer: malformed input did not fail open"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

smoke_test_summary
