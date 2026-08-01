#!/usr/bin/env python3
"""Validates schemas/command.schema.json — the SHAPE of a plugin command
file's YAML frontmatter (commands/<name>.md) per CLAUDE.md's 'Command and Hook
Mechanics'. Commands are real Claude Code mechanics: their frontmatter is fixed
by the platform (description required; argument-hint, allowed-tools, model,
disable-model-invocation optional) and must NOT carry Skill/Agent-only fields.

Prints PASS/FAIL lines; exits 0 iff every case passed. Standalone-runnable."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/command.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/command ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/command ({name}): {detail}")
        failed.append(name)


# --- Positive cases ---
check("minimal (description only)", {"description": "Advance the SDLC to the next phase."}, True)
check("full valid frontmatter", {
    "description": "Author an Architecture Decision Record for a decision.",
    "argument-hint": "<decision-title>",
    "allowed-tools": ["Read", "Write", "Bash"],
    "model": "claude-opus-4-8",
    "disable-model-invocation": False,
}, True)
check("allowed-tools as a single string", {
    "description": "Show current SDLC status.",
    "allowed-tools": "Read",
}, True)

# --- Negative cases ---
check("missing description", {"argument-hint": "<x>"}, False)
check("Skill/Agent-only 'skills' field present", {
    "description": "Do the thing.",
    "skills": ["glossary-management", "methodology-review"],
}, False)
check("disable-model-invocation not boolean", {
    "description": "Do the thing.",
    "disable-model-invocation": "true",
}, False)
check("Agent-only 'role' field present", {"description": "Do the thing.", "role": "backend-engineer"}, False)
check("empty description", {"description": ""}, False)
check("unknown top-level field", {"description": "Do the thing.", "made_up_field": "nope"}, False)
check("allowed-tools as empty array", {"description": "Do the thing.", "allowed-tools": []}, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
