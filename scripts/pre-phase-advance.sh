#!/bin/bash
# pre-phase-advance.sh — PreToolUse hook, matcher: Agent
# Purpose: block an agent from being invoked when its phase's prerequisite
#          phase has no artifacts yet, for a product currently in progress.
# Contract: JSON on stdin (PreToolUse schema). Exit 0 to allow, JSON with
#           hookSpecificOutput.permissionDecision:"deny" + reason to block.
# Consolidates the originally separate pre-phase-advance, pre-code-generation,
# and pre-implement hooks — all three reduced to the same check once given
# a real event to bind to (see sdlc-context.json decision D014).
#
# Limitation: agents with more than one phase (requirements-analyst;
# security-engineer/test-strategist) are gated on their FIRST listed phase
# only. Re-entry for a later phase is not distinguished. See
# skills/governance/pre-phase-advance references, if extended later.
set -euo pipefail

INPUT="$(cat)"

python3 - "$INPUT" <<'PYEOF'
import json, sys, os, pathlib

try:
    payload = json.loads(sys.argv[1])
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    print(json.dumps({"continue": True}))
    sys.exit(0)
subagent = payload.get("tool_input", {}).get("subagent_type", "")
cwd = payload.get("cwd", ".")

AGENT_PHASE = {
    "product-strategist": "strategy",
    "requirements-analyst": "ideate",
    "domain-modeler": "design",
    "enterprise-architect": "design",
    "ux-architect": "design",
    "data-architect": "design",
    "security-architect": "design",
    "backend-engineer": "implement",
    "frontend-engineer": "implement",
    "security-engineer": "implement",
    "test-strategist": "implement",
    "data-engineer": "data",
    "platform-engineer": "deploy",
}

PRECEDING_PHASE = {
    "strategy": None,
    "ideate": "strategy",
    "design": "ideate",
    "implement": "design",
    "data": "implement",
    "quality": "implement",
    "deploy": "quality",
    "customer-validation": "deploy",
}

def allow(reason=""):
    print(json.dumps({"continue": True}))
    sys.exit(0)

def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)

# Not one of this plugin's named agents (e.g. general-purpose) — nothing to gate.
if subagent not in AGENT_PHASE:
    allow()

phase = AGENT_PHASE[subagent]
preceding = PRECEDING_PHASE[phase]

if preceding is None:
    allow()  # strategy has no prerequisite

context_path = pathlib.Path(cwd) / "sdlc-context.json"
if not context_path.exists():
    allow()  # can't determine product state — don't block

try:
    ctx = json.loads(context_path.read_text())
except Exception:
    allow()  # malformed context — don't block on our own governance failing

first_product = ctx.get("first_product", {})
status = first_product.get("status", "")
if "not yet started" in status.lower():
    allow()  # no product in progress — nothing to gate (factory dev/testing)

artifacts_root = pathlib.Path(cwd) / "artifacts"
if not artifacts_root.exists():
    allow()  # no product artifact tree yet — don't block

# Find the product's artifact directory (first subdirectory under artifacts/)
product_dirs = [d for d in artifacts_root.iterdir() if d.is_dir()]
if not product_dirs:
    allow()

preceding_dir = product_dirs[0] / preceding
if preceding_dir.exists() and any(preceding_dir.iterdir()):
    allow()

deny(
    f"'{subagent}' operates in the {phase} phase, which requires the {preceding} "
    f"phase's artifacts to exist first (expected under artifacts/<product>/{preceding}/). "
    f"None were found. Run the {preceding} phase driver command first, or confirm this "
    f"is intentional before proceeding manually."
)
PYEOF
