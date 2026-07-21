#!/bin/bash
# harness.sh — shared functions for the SDLC Artifact Factory smoke-test suite.
# Source this from a test script; do not execute it directly.
#
# Design:
# - Every live invocation loads THIS repo as a session plugin via
#   `claude --plugin-dir`, exactly like Chunks 19-21's manual testing —
#   real discovery, real content, not a mock of Claude Code itself.
# - Skill/agent tests ask a narrow question with a quotable, near-verbatim
#   expected substring (a named format, a threshold, a term) rather than an
#   open-ended question — keeps substring assertion reliable against
#   paraphrasing.
# - All scratch/mock files live under a fresh mktemp -d per test, trapped
#   for cleanup. Nothing is ever written inside the repo tree by a test.
# - Console output: one line per test — "PASS: <name>" or "FAIL: <name>:
#   <reason>". A summary line at the end of a run.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMEOUT_SECS="${SMOKE_TEST_TIMEOUT:-90}"
# Plugin slash commands only resolve in their bare form (/sdlc-status)
# interactively. Non-interactive `-p` invocation requires the namespaced
# form (/<plugin-name>:<command>) -- found by live testing (the bare form
# returned "Unknown command" every time under -p). smoke_test_command_contains
# auto-namespaces so individual test files can keep using the bare form.
PLUGIN_NAME="$(python3 -c "import json; print(json.load(open('$REPO_ROOT/.claude-plugin/plugin.json'))['name'])")"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_TESTS=()

# Call once per test file, before using any mock/output paths.
# Sets $SCRATCH_DIR to a fresh temp dir and registers cleanup on exit.
smoke_test_scratch_init() {
  SCRATCH_DIR="$(mktemp -d /tmp/sdlc-smoke-test.XXXXXX)"
  trap 'rm -rf "$SCRATCH_DIR"' EXIT
}

_pass() {
  local name="$1"
  echo "PASS: $name"
  PASS_COUNT=$((PASS_COUNT + 1))
}

_fail() {
  local name="$1" reason="$2"
  echo "FAIL: $name: $reason"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_TESTS+=("$name")
}

# smoke_test_skill <skill-name> <question> <expect-substring>
# Live-invokes the plugin, asks a skill-scoped question, asserts the
# response contains the expected substring.
smoke_test_skill() {
  local name="$1" question="$2" expect="$3"
  local prompt="Using ONLY the '${name}' skill from this plugin (do not use general knowledge, do not consult any other skill), answer this question in one or two sentences: ${question}"
  local output
  output="$(timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" -p "$prompt" --output-format text 2>&1)"
  if [[ -z "$output" ]]; then
    _fail "skills/$name" "empty response (timeout or invocation error)"
    return 1
  fi
  if [[ "$output" == *"$expect"* ]]; then
    _pass "skills/$name"
    return 0
  else
    _fail "skills/$name" "response did not contain expected substring '$expect'. Got: ${output:0:200}"
    return 1
  fi
}

# smoke_test_agent <agent-name> <question> <expect-substring>
# Live Agent-tool dispatch of the named subagent with a bounded question.
smoke_test_agent() {
  local name="$1" question="$2" expect="$3"
  local prompt="Use the Agent tool to dispatch the '${name}' subagent with exactly this prompt, and report back its answer verbatim: \"Answer in one sentence, from your own agent file content only: ${question}\""
  local output
  output="$(timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" -p "$prompt" --output-format text 2>&1)"
  if [[ -z "$output" ]]; then
    _fail "agents/$name" "empty response (timeout or invocation error)"
    return 1
  fi
  if [[ "$output" == *"$expect"* ]]; then
    _pass "agents/$name"
    return 0
  else
    _fail "agents/$name" "response did not contain expected substring '$expect'. Got: ${output:0:200}"
    return 1
  fi
}

# smoke_test_command_contains <command-invocation-text> <expect-substring> <test-name>
# Live-invokes a real slash command (namespaced), asserts substring present.
smoke_test_command_contains() {
  local invocation="$1" expect="$2" name="$3"
  local output
  if [[ "$invocation" == /* && "$invocation" != *:* ]]; then
    invocation="/${PLUGIN_NAME}:${invocation:1}"
  fi
  output="$(timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" -p "$invocation" --output-format text 2>&1)"
  if [[ -z "$output" ]]; then
    _fail "commands/$name" "empty response (timeout or invocation error)"
    return 1
  fi
  if [[ "$output" == *"$expect"* ]]; then
    _pass "commands/$name"
    return 0
  else
    _fail "commands/$name" "response did not contain expected substring '$expect'. Got: ${output:0:300}"
    return 1
  fi
}

# smoke_test_script <script-name> <stdin-json> <expected-decision: allow|deny|warn> [expect-substring-in-reason]
# Direct-invokes a hook-backing script (no LLM call) with synthetic JSON on
# stdin, per the pattern manually verified in Chunk 20.
smoke_test_script() {
  local name="$1" stdin_json="$2" expected="$3" expect_substr="${4:-}"
  local output
  output="$(echo "$stdin_json" | "$REPO_ROOT/scripts/${name}.sh" 2>&1)"
  local decision="allow"
  if echo "$output" | grep -q '"permissionDecision": "deny"'; then
    decision="deny"
  elif echo "$output" | grep -qi 'terminology drift\|does not block'; then
    decision="warn"
  fi
  if [[ "$decision" != "$expected" ]]; then
    _fail "scripts/$name" "expected decision '$expected', got '$decision'. Output: ${output:0:300}"
    return 1
  fi
  if [[ -n "$expect_substr" && "$output" != *"$expect_substr"* ]]; then
    _fail "scripts/$name" "decision correct ($decision) but missing expected substring '$expect_substr'"
    return 1
  fi
  _pass "scripts/$name (case: $expected)"
  return 0
}

# smoke_test_acceptance <name> <dispatch-prompt> <expected-path> <validator-fn>
# Live-dispatches an agent (or the plugin directly) to produce a real work
# product under $SCRATCH_DIR (set by smoke_test_scratch_init), per the same
# --add-dir pattern proven in tests/hooks/hooks-wiring.test.sh, but with
# --permission-mode auto rather than acceptEdits/bypassPermissions. Found by
# live testing: bypassPermissions maps to --dangerously-skip-permissions,
# which Claude Code refuses to honor when the process is running as
# root/sudo (this sandbox runs as root); acceptEdits auto-accepts Write/Edit
# but still blocks Bash approval, and several agents in this plugin declare
# `tools: [Bash]` only (e.g. backend-engineer, frontend-engineer — no Write
# tool at all, so they create files via Bash heredocs) — under acceptEdits
# those agents hang or error indefinitely waiting for a Bash approval that
# never comes in a headless -p session. auto grants both non-interactively.
# Fails fast if the anchor file at <expected-path> never lands; otherwise
# hands $SCRATCH_DIR to <validator-fn>, which knows the rest of the
# convention-derived paths and does structural (and, where a toolchain
# exists, mechanical) validation. Passes iff the validator function exits 0.
smoke_test_acceptance() {
  local name="$1" prompt="$2" expected_path="$3" validator_fn="$4"
  local output reason
  output="$(timeout "$TIMEOUT_SECS" claude --plugin-dir "$REPO_ROOT" --add-dir "$SCRATCH_DIR" \
    --permission-mode auto -p "$prompt" --output-format text 2>&1)"
  if [[ ! -f "$expected_path" ]]; then
    _fail "$name" "expected artifact not found at $expected_path. Agent output: ${output:0:300}"
    return 1
  fi
  if reason="$("$validator_fn" "$SCRATCH_DIR" 2>&1)"; then
    _pass "$name"
    return 0
  else
    _fail "$name" "$reason"
    return 1
  fi
}

smoke_test_summary() {
  echo ""
  echo "--- Summary: $PASS_COUNT passed, $FAIL_COUNT failed ---"
  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "Failed:"
    for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
    return 1
  fi
  return 0
}
