#!/bin/bash
# Proves each agent actually receives the standard tool set at runtime (#1254).
# Claude Code's agent `tools:` field is an ALLOW-list: before this fix
# backend-engineer (`tools: [Bash]`) got Bash alone, product-strategist
# (`[Read, Write]`) got no Bash for memory-recall, and ux-architect (`[]`) got
# no tools at all. The agent schema enforces the declaration; this test proves
# the platform honours it. One agent per old failure shape keeps it cheap.
# Glob and Grep are declared too, but some Claude Code builds have no separate
# Glob/Grep tools (search runs through Bash), so only these four are required.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

NAME="agent-tools"
STANDARD=(Read Write Edit Bash)

mkdir -p "$SCRATCH_DIR/.sdlc-memory"
touch "$SCRATCH_DIR/.sdlc-memory/.skip-install"
git -C "$SCRATCH_DIR" init -q

for agent in backend-engineer product-strategist ux-architect; do
  reply=$(cd "$SCRATCH_DIR" && timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" \
    --permission-mode acceptEdits -p \
    "Use the Agent tool exactly once with subagent_type 'sdlc-artifact-factory:$agent' and this prompt: 'Do not do any work. Reply only with a comma-separated list of the exact names of every tool you can call right now, nothing else.' Then print only the subagent's reply, verbatim." \
    --output-format text 2>&1)
  missing=()
  for tool in "${STANDARD[@]}"; do
    grep -qw "$tool" <<<"$reply" || missing+=("$tool")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    _pass "$NAME ($agent has Read, Write, Edit, Bash)"
  else
    _fail "$NAME ($agent)" "missing ${missing[*]} — agent replied: $(head -c 300 <<<"$reply")"
  fi
done

smoke_test_summary
