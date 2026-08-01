#!/usr/bin/env python3
"""Validates schemas/skill.schema.json — the SHAPE of every SKILL.md frontmatter block.
Exercises one known-good frontmatter dict plus a spread of invalid ones.
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/skill.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/skill ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/skill ({name}): {detail}")
        failed.append(name)


# Positive: a realistic, complete frontmatter block with all required fields.
good = {
    "name": "bdd-feature-file",
    "description": "Use when authoring Gherkin feature files for acceptance criteria — Given/When/Then scenarios, Scenario Outlines, and Specification by Example.",
    "version": "2.1.0",
    "phase": "Implement",
    "owner": "test-strategist",
    "created": "2026-07-20",
    "tags": ["testing", "bdd", "gherkin"],
}
check("complete known-good frontmatter", good, True)

# Positive: required set only (no optional fields) still validates.
check("required-set only", {
    "name": "vision-statement",
    "description": "Author a product vision statement.",
    "version": "1.0.0",
    "phase": "Strategy",
    "owner": "product-strategist",
    "created": "2026-01-05",
    "tags": ["strategy"],
}, True)

# Positive: optional P2 fields (related, produces, domain, status) are permitted.
check("with optional P2 fields", {
    **good,
    "related": ["specification-by-example", "test-pyramid"],
    "produces": ["feature-file", "scenario"],
    "domain": "test-engineering",
    "status": "stable",
}, True)

# Positive: forward-compat field not in the schema is permitted (additionalProperties true).
check("forward-compat extra field", {**good, "future_field": "carried-forward"}, True)

# Positive: produces as a single string (oneOf branch).
check("produces as string", {**good, "produces": "feature-file"}, True)

# Negative cases
check("missing description", {k: v for k, v in good.items() if k != "description"}, False)
check("missing name", {k: v for k, v in good.items() if k != "name"}, False)
check("missing tags", {k: v for k, v in good.items() if k != "tags"}, False)
check("version not semver", {**good, "version": "2.1"}, False)
check("version with prefix", {**good, "version": "v2.1.0"}, False)
check("tags not a list", {**good, "tags": "testing"}, False)
check("tags empty list", {**good, "tags": []}, False)
check("tag not lowercase-hyphen", {**good, "tags": ["Testing"]}, False)
check("name uppercase", {**good, "name": "BddFeatureFile"}, False)
check("created not a date", {**good, "created": "July 20 2026"}, False)
check("status not in enum", {**good, "status": "draft"}, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
