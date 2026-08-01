#!/usr/bin/env python3
"""Contract test for schemas/hook.schema.json (P1 Governance Foundation, closes #785).

Validates the STRUCTURE of hooks/hooks.json:
  - the real hooks/hooks.json MUST pass (the schema faithfully encodes the observed shape);
  - synthetic invalids MUST be rejected (unknown event name; entry missing matcher;
    handler type not in the enum; plus command/agent field-shape violations).

Standalone. Prints PASS/FAIL lines; exits 0 iff every case passed.
"""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/hook.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/hook ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/hook ({name}): {detail}")
        if should_pass and errors:
            print(f"       first error: {errors[0].message}")
        failed.append(name)


# ---- Positive: the REAL file must validate ----
real = json.loads((REPO_ROOT / "hooks/hooks.json").read_text())
check("real hooks/hooks.json", real, True)

# ---- Positive: minimal well-formed synthetic instances ----
check("minimal command handler", {
    "hooks": {
        "PreToolUse": [
            {"matcher": "Write", "hooks": [
                {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/x.sh", "timeout": 10}
            ]}
        ]
    }
}, True)

check("agent handler with prompt", {
    "hooks": {
        "PostToolUse": [
            {"matcher": "Write|Edit", "hooks": [
                {"type": "agent", "prompt": "do a review", "timeout": 90}
            ]}
        ]
    }
}, True)

check("prompt handler", {
    "hooks": {
        "Stop": [
            {"matcher": "", "hooks": [{"type": "prompt", "prompt": "judge this"}]}
        ]
    }
}, True)

check("_meta block accepted", {
    "_meta": {"purpose": "x", "last_updated": "2026-08-01"},
    "hooks": {"SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "s.sh"}]}]}
}, True)

# ---- Negative cases (>=3 required by the issue) ----
# 1. unknown event name
check("unknown event name", {
    "hooks": {"BeforeFileCreate": [{"matcher": "Write", "hooks": [{"type": "command", "command": "x.sh"}]}]}
}, False)

# 2. entry missing matcher
check("entry missing matcher", {
    "hooks": {"PreToolUse": [{"hooks": [{"type": "command", "command": "x.sh"}]}]}
}, False)

# 3. handler type not in the enum
check("handler type not in enum", {
    "hooks": {"PreToolUse": [{"matcher": "Write", "hooks": [{"type": "webhook", "command": "x.sh"}]}]}
}, False)

# ---- Extra negatives for field-shape fidelity ----
check("command handler missing command field", {
    "hooks": {"PreToolUse": [{"matcher": "Write", "hooks": [{"type": "command", "timeout": 10}]}]}
}, False)

check("agent handler missing prompt field", {
    "hooks": {"PostToolUse": [{"matcher": "Write", "hooks": [{"type": "agent", "timeout": 90}]}]}
}, False)

check("command handler carrying a prompt field", {
    "hooks": {"PreToolUse": [{"matcher": "Write", "hooks": [{"type": "command", "command": "x.sh", "prompt": "nope"}]}]}
}, False)

check("missing hooks top-level key", {"_meta": {"purpose": "x"}}, False)

check("entry hooks array empty", {
    "hooks": {"PreToolUse": [{"matcher": "Write", "hooks": []}]}
}, False)

check("unknown field on handler", {
    "hooks": {"PreToolUse": [{"matcher": "Write", "hooks": [{"type": "command", "command": "x.sh", "foo": 1}]}]}
}, False)

check("event maps to object not array", {
    "hooks": {"PreToolUse": {"matcher": "Write", "hooks": []}}
}, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
