#!/usr/bin/env python3
"""Validates schemas/workflow.schema.json — the FORWARD CONTRACT for P7's
declarative, workflows-as-data phase specs (Architecture Review Campaign, P1 #786).

The contract this test defends: a workflow spec is DATA, not a program. It must
accept a well-formed declarative spec (ordered stages, a depends_on edge, a gate)
and REJECT (a) an instance missing the required 'stages', (b) a stage missing its
producing 'agent', and (c) any imperative control-flow field — proven here with a
forbidden 'retry' — which additionalProperties:false rejects at every level.

Prints PASS/FAIL lines; exits 0 iff every case passed. Standalone."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/workflow.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/workflow ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/workflow ({name}): {detail}")
        failed.append(name)


# --- Positive: a small, well-formed 'design' workflow with a depends_on edge and a gate ---
design_workflow = {
    "name": "design-phase",
    "phase": "Design",
    "entry_conditions": {
        "requires_complete": ["vision-statement", "product-strategy"]
    },
    "stages": [
        {
            "id": "event-storm",
            "agent": "domain-modeler",
            "produces": ["event-storming-board", "bounded-context-map"]
        },
        {
            "id": "domain-model",
            "agent": "domain-modeler",
            "produces": ["aggregate-design"],
            "depends_on": ["event-storm"]
        },
        {
            "id": "adr",
            "agent": "software-architect",
            "produces": ["architecture-decision-record"],
            "depends_on": ["domain-model"]
        }
    ],
    "gates": [
        {"after": "adr", "kind": "hook", "enforce": "pre-phase-advance"}
    ],
    "completion": {
        "artifacts_required": ["bounded-context-map", "aggregate-design", "architecture-decision-record"]
    }
}
check("well-formed design workflow (depends_on edge + hook gate)", design_workflow, True)

# A minimal spec: only the four required keys, single stage.
check("minimal required-only workflow", {
    "name": "ideate-phase",
    "phase": "Ideate",
    "stages": [{"id": "s1", "agent": "product-strategist"}],
    "completion": {"artifacts_required": ["opportunity-brief"]}
}, True)

# An 'approval' gate before a stage is valid too.
check("approval gate positioned before a stage", {
    "name": "deploy-phase",
    "phase": "Deploy",
    "stages": [{"id": "release", "agent": "platform-engineer", "produces": ["helm-release"]}],
    "gates": [{"before": "release", "kind": "approval"}],
    "completion": {"artifacts_required": ["helm-release"]}
}, True)

# --- Negative cases (>= 3) ---

# 1. Missing the required 'stages' array.
check("missing 'stages' (required)", {
    "name": "broken-phase",
    "phase": "Design",
    "completion": {"artifacts_required": ["adr"]}
}, False)

# 2. A stage missing its required 'agent'.
check("stage missing 'agent' (required)", {
    "name": "broken-stage",
    "phase": "Design",
    "stages": [{"id": "s1", "produces": ["adr"]}],
    "completion": {"artifacts_required": ["adr"]}
}, False)

# 3. A forbidden imperative field — 'retry' — at the root. Declarative-only ban.
check("forbidden imperative 'retry' at root", {
    "name": "imperative-phase",
    "phase": "Design",
    "stages": [{"id": "s1", "agent": "domain-modeler"}],
    "retry": {"max_attempts": 3},
    "completion": {"artifacts_required": ["adr"]}
}, False)

# Extra guards proving the imperative ban holds at nested levels and enums/shape are tight.
check("forbidden 'rollback' inside a stage", {
    "name": "imperative-stage",
    "phase": "Implement",
    "stages": [{"id": "s1", "agent": "backend-engineer", "rollback": "git-reset"}],
    "completion": {"artifacts_required": ["service"]}
}, False)

check("forbidden 'if' branch inside a gate", {
    "name": "imperative-gate",
    "phase": "Quality",
    "stages": [{"id": "s1", "agent": "test-strategist"}],
    "gates": [{"after": "s1", "kind": "hook", "if": "coverage<80"}],
    "completion": {"artifacts_required": ["test-report"]}
}, False)

check("gate 'kind' not in enum", {
    "name": "bad-gate-kind",
    "phase": "Quality",
    "stages": [{"id": "s1", "agent": "test-strategist"}],
    "gates": [{"after": "s1", "kind": "loop"}],
    "completion": {"artifacts_required": ["test-report"]}
}, False)

check("empty gate object (minProperties)", {
    "name": "empty-gate",
    "phase": "Quality",
    "stages": [{"id": "s1", "agent": "test-strategist"}],
    "gates": [{}],
    "completion": {"artifacts_required": ["test-report"]}
}, False)

check("empty stages array (minItems)", {
    "name": "no-stages",
    "phase": "Design",
    "stages": [],
    "completion": {"artifacts_required": ["adr"]}
}, False)

check("unknown top-level field", {
    "name": "extra-field",
    "phase": "Design",
    "stages": [{"id": "s1", "agent": "domain-modeler"}],
    "completion": {"artifacts_required": ["adr"]},
    "loop": True
}, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
