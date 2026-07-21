#!/usr/bin/env python3
"""Formalizes the manual validation run during Chunk 21 development.
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
schema = json.loads((REPO_ROOT / "schemas/sdlc-manifest.schema.json").read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())

passed, failed = 0, []


def check(name, instance, should_pass):
    global passed
    errors = list(validator.iter_errors(instance))
    ok = (not errors) if should_pass else bool(errors)
    if ok:
        print(f"PASS: schemas/sdlc-manifest ({name})")
        passed += 1
    else:
        detail = "expected to pass but got errors" if should_pass else "expected to fail but was accepted"
        print(f"FAIL: schemas/sdlc-manifest ({name}): {detail}")
        failed.append(name)


base_meta = {"purpose": "x", "how_to_use": "x", "last_updated": "2026-07-20", "updated_by": "x"}


def entry(**overrides):
    e = {
        "id": "p-adr-001", "type": "adr", "path": "artifacts/p/x.md", "version": "1.0.0",
        "status": "approved", "phase": "design", "producing_agent": "enterprise-architect",
        "traces_to": {"kind": "decision", "ref": "D009"}, "created": "2026-07-20", "updated": "2026-07-20",
    }
    e.update(overrides)
    return e


# Positive: the skill's own worked example, including the "-r2" revision
# suffix edge case beyond the base 3-segment ID scheme.
check("worked example incl. -r2 suffix", {
    "_meta": {
        "purpose": "Registry of every artifact produced for this product. Read before producing a new artifact to check whether it already exists; updated by the post-artifact-created hook on every artifact write.",
        "how_to_use": "1. Look up an artifact by id or type before creating a new one. 2. Check status before treating an entry as current. 3. Follow traces_to to find the requirement, decision, or event behind any artifact.",
        "last_updated": "2026-07-20", "updated_by": "post-artifact-created hook",
    },
    "product": "Data Estate Mapping and Compliance Intelligence",
    "product_slug": "dataestate",
    "artifacts": [
        entry(id="dataestate-adr-001", type="adr", path="artifacts/dataestate/design/decisions/ADR-001-transactional-outbox.md",
              version="1.0.0", status="approved", phase="design", producing_agent="enterprise-architect",
              traces_to={"kind": "decision", "ref": "D009"}, created="2026-07-21", updated="2026-07-21"),
        entry(id="dataestate-user-story-014", type="user-story", path="artifacts/dataestate/ideate/stories/dataestate-user-story-014.md",
              version="1.1.0", status="superseded", phase="ideate", producing_agent="requirements-analyst",
              traces_to={"kind": "requirement", "ref": "dataestate-epic-002"}, created="2026-07-15", updated="2026-07-22",
              **{"superseded_by": "dataestate-user-story-014-r2"}),
    ],
}, True)

check("empty artifacts array (new product)", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": []}, True)

# Negative cases
check("missing traces_to", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [{k: v for k, v in entry().items() if k != "traces_to"}]}, False)
check("bad status enum", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(status="in-review")]}, False)
check("bad phase enum", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(phase="testing")]}, False)
check("bad version not semver", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(version="v1.0")]}, False)
check("bad traces_to.kind enum", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(traces_to={"kind": "vibes", "ref": "D009"})]}, False)
check("empty traces_to.ref", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(traces_to={"kind": "decision", "ref": ""})]}, False)
check("unknown field on entry", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(made_up="x")]}, False)
check("bad created date format", {"_meta": base_meta, "product": "x", "product_slug": "x", "artifacts": [entry(created="July 20")]}, False)
check("missing artifacts array", {"_meta": base_meta, "product": "x", "product_slug": "x"}, False)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
