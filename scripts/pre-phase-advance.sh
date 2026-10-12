#!/bin/bash
# pre-phase-advance.sh — PreToolUse hook, matcher: Agent
# Purpose: block an agent from being invoked when its phase's prerequisite
#          phase has not been approved (product state in the manifest,
#          written by scripts/product-state.py), for a product in progress.
# Contract: JSON on stdin (PreToolUse schema). Exit 0 to allow, JSON with
#           hookSpecificOutput.permissionDecision:"deny" + reason to block.
# Consolidates the originally separate pre-phase-advance, pre-code-generation,
# and pre-implement hooks — all three reduced to the same check once given
# a real event to bind to (see sdlc-context.json decision D014).
#
# Limitation: agents with more than one phase (requirements-analyst;
# security-engineer/test-strategist) are gated on their FIRST listed phase
# only. Re-entry for a later phase is not distinguished. See
# skills/pre-phase-advance references, if extended later.
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

# An installed plugin's agents are invoked by their namespaced name
# ("sdlc-artifact-factory:product-strategist"); only --plugin-dir/dev sessions
# may use the bare name. Strip OUR prefix only — another plugin's agent that
# happens to share a short name (e.g. "other-plugin:backend-engineer") is not
# ours to gate. (#1247: without this the gate never matched for real users.)
PLUGIN_PREFIX = "sdlc-artifact-factory:"
if subagent.startswith(PLUGIN_PREFIX):
    subagent = subagent[len(PLUGIN_PREFIX):]

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

# Product state lives in the manifest (proposal 13). No manifest = no product
# started in this repo, so there is nothing to gate (plugin development, other repos).
manifests = sorted(pathlib.Path(cwd).glob("artifacts/*/_manifest.json"))
if not manifests:
    allow()
if len(manifests) > 1:
    allow()  # several products: the gate can't tell which one this agent is for

try:
    manifest = json.loads(manifests[0].read_text())
except Exception:
    allow()  # malformed manifest — don't block on our own governance failing

phases = manifest.get("phases")
if isinstance(phases, dict):
    if phases.get(preceding, {}).get("status") == "approved":
        allow()
    deny(
        f"'{subagent}' works in the {phase} phase, but the {preceding} phase hasn't been approved yet. "
        f"Run /sdlc-status to see what's missing or unapproved; when the user approves the {preceding} "
        f"phase, record it with product-state.py complete {preceding}. If the user explicitly wants to "
        f"proceed anyway, run product-state.py complete {preceding} --override \"<their reason>\" first."
    )

# A manifest from before product state existed: fall back to the old check
# (the preceding phase's folder has at least one file).
preceding_dir = manifests[0].parent / preceding
if preceding_dir.exists() and any(preceding_dir.iterdir()):
    allow()
deny(
    f"'{subagent}' operates in the {phase} phase, which requires the {preceding} "
    f"phase's artifacts to exist first (expected under artifacts/<product>/{preceding}/). "
    f"None were found. Run the {preceding} phase driver command first, or confirm this "
    f"is intentional before proceeding manually."
)
PYEOF
