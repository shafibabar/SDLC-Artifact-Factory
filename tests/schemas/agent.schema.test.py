#!/usr/bin/env python3
"""Validates schemas/agent.schema.json — the canonical Agent frontmatter shape.

Confirms a known-good agent frontmatter (with glossary-management AND
methodology-review in skills) is accepted, and that shape violations are
rejected: missing 'role'; skills missing methodology-review; outputs not a list.
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/agent.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/agent ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/agent ({name}): {detail}")
        failed.append(name)


def good():
    """A complete, valid agent frontmatter (structure mirrors agents/test-strategist.md)."""
    return {
        "name": "test-strategist",
        "description": "Elite SDET. Owns the test discipline and the Test Pyramid.",
        "role": "SDET — test discipline, Test Pyramid, and cross-cutting system tests",
        "version": "1.2.0",
        "phase": "implement, quality",
        "owner": "shafi",
        "created": "2026-06-25",
        "inputs": ["Acceptance criteria in Gherkin", "Implementations to test"],
        "outputs": ["Test strategy with pyramid targets", "Executable Gherkin feature files"],
        "skills": ["test-pyramid", "bdd-feature-file", "glossary-management", "methodology-review"],
        "tools": ["Bash"],
        "tags": ["implement", "quality", "sdet", "testing"],
    }


# Positive: the known-good instance
check("known-good agent frontmatter", good(), True)

# Positive: forward-compat optional fields are permitted
fc = good()
fc.update({"produces": ["x"], "domain": "testing", "status": "active", "capability": "y"})
check("forward-compat optional fields accepted", fc, True)

# Positive: empty tools array is allowed (agent runs no shell commands)
no_tools = good()
no_tools["tools"] = []
check("empty tools array accepted", no_tools, True)

# Negative: missing 'role'
missing_role = good()
del missing_role["role"]
check("missing role rejected", missing_role, False)

# Negative: skills missing methodology-review
no_methodology = good()
no_methodology["skills"] = ["test-pyramid", "glossary-management"]
check("skills missing methodology-review rejected", no_methodology, False)

# Negative: skills missing glossary-management
no_glossary = good()
no_glossary["skills"] = ["test-pyramid", "methodology-review"]
check("skills missing glossary-management rejected", no_glossary, False)

# Negative: outputs not a list
bad_outputs = good()
bad_outputs["outputs"] = "a single string, not a list"
check("outputs not a list rejected", bad_outputs, False)

# Negative: bad name (uppercase)
bad_name = good()
bad_name["name"] = "TestStrategist"
check("bad name pattern rejected", bad_name, False)

# Negative: non-semver version
bad_version = good()
bad_version["version"] = "1.2"
check("non-semver version rejected", bad_version, False)

# Negative: empty skills array
empty_skills = good()
empty_skills["skills"] = []
check("empty skills array rejected", empty_skills, False)

# Negative: unknown top-level field
unknown_field = good()
unknown_field["made_up_field"] = "nope"
check("unknown top-level field rejected", unknown_field, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
