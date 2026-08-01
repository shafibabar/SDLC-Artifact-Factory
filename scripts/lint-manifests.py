#!/usr/bin/env python3
"""
scripts/lint-manifests.py — the P1.6 manifest linter (closes #787).

Part of the Architecture Review campaign's Governance Foundation (parent #780).
This is a merge-blocking CI gate: for every plugin component it loads the
NORMALIZED record produced by scripts/arch/manifest.py and validates that
record against the component's shape contract:

    skills   -> schemas/skill.schema.json
    agents   -> schemas/agent.schema.json
    commands -> schemas/command.schema.json
    hooks    -> schemas/hook.schema.json   (whole hooks.json file)

Every violation is reported as '<file>: <reason>'. A summary line per kind
reports how many components pass. Exit status is 1 if ANY component violates
its schema, else 0.

WHY the normalized record (ARCHITECTURE-REVIEW-CAMPAIGN.md §5 CRITICAL RULE):
manifest.py returns records with dates already coerced to ISO strings and
filesystem facts derived. Validating raw `yaml.safe_load` output instead would
spuriously fail the `format: date` constraints, because PyYAML auto-parses
`created: 2026-06-25` into a Python `datetime.date` object (not a string).
So this linter ALWAYS inspects manifest.py records, never raw YAML.

The linter maps each normalized record back to the exact frontmatter-authored
field set the schema constrains — dropping manifest's derived, non-frontmatter
keys (has_references, dir, file, has_test, ...) and any `None`-valued optional
field manifest injects when the frontmatter omitted it — so that a schema with
`additionalProperties: false` (agents, commands) is validated fairly and a
genuinely-absent optional does not masquerade as a type error. It does NOT
paper over real drift: a field present with the wrong type/shape is reported.

hooks.json is pure JSON (json.load), so the YAML date-coercion hazard does not
apply; and hook.schema.json validates the whole-file structure, which the
flattened load_hooks() handler records cannot represent — so the file object is
validated directly, located via manifest.HOOKS_FILE.

Importable API (used by tests/arch/lint-manifests.test.py):
    load_schema(kind)                         -> dict
    record_to_instance(kind, record)          -> dict   (schema-shaped view)
    validate_instance(instance, schema)       -> list[str]   (reasons)
    lint()                                     -> dict
        {"violations": [...], "summary": {kind: {"passed": n, "total": m}},
         "ok": bool}
    main()                                     -> int  (process exit code)
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# --- wire in the shared frontmatter parser (P1.1) -------------------------
_HERE = Path(__file__).resolve().parent
_ARCH_DIR = _HERE / "arch"
if str(_ARCH_DIR) not in sys.path:
    sys.path.insert(0, str(_ARCH_DIR))

import manifest  # noqa: E402  (scripts/arch/manifest.py)

try:
    import jsonschema  # noqa: E402
    from jsonschema import Draft202012Validator  # noqa: E402
except Exception as exc:  # pragma: no cover - environment dependent
    print(f"lint-manifests: the 'jsonschema' library is required ({exc})", file=sys.stderr)
    raise SystemExit(2)

REPO_ROOT = manifest.REPO_ROOT
SCHEMAS_DIR = REPO_ROOT / "schemas"

_SCHEMA_FILES = {
    "skill": "skill.schema.json",
    "agent": "agent.schema.json",
    "command": "command.schema.json",
    "hook": "hook.schema.json",
}

# The exact frontmatter-authored field set each schema constrains. Manifest's
# derived facts (has_*, dir, file, order, ...) are intentionally excluded — the
# skill schema tolerates them (additionalProperties:true) but the agent and
# command schemas do not, so we present a clean, schema-shaped view for all.
_SKILL_FIELDS = (
    "name", "description", "version", "phase", "owner", "created", "tags",
    "related", "produces", "domain", "status",
)
_AGENT_FIELDS = (
    "name", "description", "role", "version", "phase", "owner", "created",
    "inputs", "outputs", "skills", "tools", "tags",
)
# command record keys are snake_cased by manifest; the platform (and schema)
# use the hyphenated keys. Map back so additionalProperties:false is fair.
_COMMAND_KEY_MAP = {
    "description": "description",
    "argument_hint": "argument-hint",
    "allowed_tools": "allowed-tools",
    "model": "model",
    "disable_model_invocation": "disable-model-invocation",
}


def load_schema(kind: str) -> dict:
    """Load and return the JSON Schema for a component kind."""
    fname = _SCHEMA_FILES[kind]
    return json.loads((SCHEMAS_DIR / fname).read_text(encoding="utf-8"))


def _drop_none(d: dict) -> dict:
    """Drop keys whose value is None (an optional frontmatter field manifest
    injects as None when absent). False/0/[] are kept — only None is dropped."""
    return {k: v for k, v in d.items() if v is not None}


def record_to_instance(kind: str, record: dict) -> dict:
    """Project a normalized manifest record onto the schema-shaped instance."""
    if kind == "skill":
        inst = {k: record.get(k) for k in _SKILL_FIELDS}
    elif kind == "agent":
        inst = {k: record.get(k) for k in _AGENT_FIELDS}
    elif kind == "command":
        inst = {schema_key: record.get(rec_key)
                for rec_key, schema_key in _COMMAND_KEY_MAP.items()}
    else:
        raise ValueError(f"unknown component kind: {kind}")
    return _drop_none(inst)


def _error_reason(err: "jsonschema.exceptions.ValidationError") -> str:
    """Format one validation error as 'json_path: message'."""
    loc = err.json_path if err.json_path and err.json_path != "$" else "$"
    return f"{loc}: {err.message}"


def validate_instance(instance, schema: dict) -> list[str]:
    """Validate an instance against a schema; return a sorted list of reasons
    (empty list == valid). Format assertion is enabled so `format: date` on the
    already-ISO-normalized `created` field is actually checked, not annotated."""
    validator = Draft202012Validator(
        schema, format_checker=Draft202012Validator.FORMAT_CHECKER
    )
    errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
    return [_error_reason(e) for e in errors]


def _file_for_skill(record: dict) -> str:
    return f"{record.get('dir', 'skills/' + record['name'])}/SKILL.md"


def lint() -> dict:
    """Run the full lint. Returns {'violations', 'summary', 'ok'}."""
    violations: list[str] = []
    summary: dict[str, dict[str, int]] = {}

    # ---- skills / agents / commands (per-record frontmatter validation) ----
    per_record = [
        ("skill", manifest.load_skills(), _file_for_skill),
        ("agent", manifest.load_agents(), lambda r: r["file"]),
        ("command", manifest.load_commands(), lambda r: r["file"]),
    ]
    for kind, records, file_of in per_record:
        schema = load_schema(kind)
        total = len(records)
        passed = 0
        for record in records:
            instance = record_to_instance(kind, record)
            reasons = validate_instance(instance, schema)
            if reasons:
                fpath = file_of(record)
                for reason in reasons:
                    violations.append(f"{fpath}: {reason}")
            else:
                passed += 1
        summary[kind] = {"passed": passed, "total": total}

    # ---- hooks (whole-file structure validation) ----------------------------
    hook_schema = load_schema("hook")
    hooks_file = manifest.HOOKS_FILE
    hooks_rel = str(hooks_file.relative_to(REPO_ROOT)) if hooks_file.is_file() else "hooks/hooks.json"
    if hooks_file.is_file():
        hooks_obj = json.loads(hooks_file.read_text(encoding="utf-8"))
        reasons = validate_instance(hooks_obj, hook_schema)
        if reasons:
            for reason in reasons:
                violations.append(f"{hooks_rel}: {reason}")
            summary["hook"] = {"passed": 0, "total": 1}
        else:
            summary["hook"] = {"passed": 1, "total": 1}
    else:
        violations.append(f"{hooks_rel}: file not found")
        summary["hook"] = {"passed": 0, "total": 1}

    return {"violations": violations, "summary": summary, "ok": not violations}


def main(argv=None) -> int:
    result = lint()
    summary = result["summary"]
    violations = result["violations"]

    if violations:
        print("Manifest lint violations:")
        for v in violations:
            print(f"  {v}")
        print("")

    print("lint-manifests summary:")
    order = ["skill", "agent", "command", "hook"]
    label = {"skill": "skills", "agent": "agents", "command": "commands", "hook": "hooks.json"}
    for kind in order:
        if kind in summary:
            s = summary[kind]
            print(f"  {label[kind]:<10} {s['passed']}/{s['total']} pass")
    print(f"  {'TOTAL':<10} {len(violations)} violation(s)")

    if result["ok"]:
        print("RESULT: PASS — every component conforms to its schema.")
        return 0
    print("RESULT: FAIL — schema violations found (see above).")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
