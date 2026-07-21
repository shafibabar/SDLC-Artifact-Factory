#!/usr/bin/env python3
"""Formalizes the manual validation run during Chunk 21 development.
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/sdlc-config.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/sdlc-config ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/sdlc-config ({name}): {detail}")
        failed.append(name)


base_meta = {"purpose": "x", "how_to_use": "x", "last_updated": "2026-07-20", "updated_by": "D1"}

# Positive: the skill's own worked example
check("worked example", {
    "_meta": {
        "purpose": "Per-product configuration. Records only fields that differ from CLAUDE.md's Tech Stack Defaults and standard methodology parameters. Absence of a field means the CLAUDE.md default applies.",
        "how_to_use": "1. Check this file before applying any CLAUDE.md default. 2. If a field is present here, it overrides CLAUDE.md. 3. If absent, use the CLAUDE.md default. 4. Only Shafi may change this file; every change is recorded in sdlc-context.json's decisions array.",
        "last_updated": "2026-07-20",
        "updated_by": "D012 — /sdlc-start questionnaire, confirming MongoDB and Option B deployment for the pilot customer instance",
    },
    "product": "Data Estate Mapping and Compliance Intelligence",
    "product_slug": "dataestate",
    "tech_stack_overrides": {
        "optional_database": {"included": True, "value": "MongoDB", "rationale": "Entity extraction output and crawl metadata are variable-schema."}
    },
    "compliance_frameworks": ["SOC 2 - CC6, CC7, A1"],
    "deployment_model": "Option B — managed private cloud, dedicated tenant, no data commingling",
    "methodology_parameters": {},
}, True)

check("minimal all-defaults instance", {"_meta": base_meta, "product": "x", "product_slug": "minimal"}, True)
check("arbitrary tech-stack override key", {"_meta": base_meta, "product": "x", "product_slug": "x", "tech_stack_overrides": {"graph_database": "Neo4j Community"}}, True)

# Negative cases
check("missing _meta", {"product": "x", "product_slug": "x"}, False)
check("missing product_slug", {"_meta": base_meta, "product": "x"}, False)
check("bad product_slug uppercase", {"_meta": base_meta, "product": "x", "product_slug": "BadSlug"}, False)
check("bad date format", {"_meta": {**base_meta, "last_updated": "not-a-date"}, "product": "x", "product_slug": "x"}, False)
check("optional_database missing rationale", {"_meta": base_meta, "product": "x", "product_slug": "x", "tech_stack_overrides": {"optional_database": {"included": True, "value": "MongoDB"}}}, False)
check("unknown top-level field", {"_meta": base_meta, "product": "x", "product_slug": "x", "made_up_field": "nope"}, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
