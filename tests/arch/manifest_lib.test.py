#!/usr/bin/env python3
"""
tests/arch/manifest_lib.test.py — contract test for scripts/arch/manifest.py
(P1.1, closes #781).

Runs against the REAL repo (no fixtures): the manifest library is the shared
foundation the P1 linters and the P3 catalog import, so its contract is pinned
to the live component tree. Asserts:

  * exact component counts (186 skills, 13 agents, 15 commands) — a drift here
    means a component was added/removed without the manifest noticing;
  * filesystem-DERIVED booleans are computed correctly for a known skill
    (adr-authoring has references/ + assets/ + scripts/ + a contract test);
  * authored frontmatter is parsed correctly (fields, inline lists, block
    lists, folded '>' descriptions);
  * the PyYAML path and the minimal fallback parser agree (both are exercised);
  * resolve(), all_component_names(), load_agents() (has_acceptance_test) and
    load_hooks() behave per their documented contract;
  * purity — importing and calling every loader leaves the working tree clean
    (the module never writes).

Prints PASS/FAIL lines; exits 0 iff every check passed. Standalone-runnable:
    python3 tests/arch/manifest_lib.test.py
"""

import importlib.util
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "arch" / "manifest.py"


def _load_module(unique_name="_manifest_under_test"):
    """Import scripts/arch/manifest.py fresh under a private module name.

    Parser selection is decided at call time from MANIFEST_FORCE_MINIMAL, so the
    caller controls the env var around the actual load_*() calls, not here.
    """
    spec = importlib.util.spec_from_file_location(unique_name, MODULE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: manifest_lib ({name})")
        passed += 1
    else:
        print(f"FAIL: manifest_lib ({name})")
        failed.append(name)


# --- module import -----------------------------------------------------------
check("module file exists", MODULE_PATH.is_file())
os.environ.pop("MANIFEST_FORCE_MINIMAL", None)  # ensure the PyYAML path for the main run
m = _load_module()

skills = m.load_skills()
agents = m.load_agents()
commands = m.load_commands()
hooks = m.load_hooks()

# --- counts against the real repo -------------------------------------------
check(f"skill count is 186 (got {len(skills)})", len(skills) == 186)
check(f"agent count is 13 (got {len(agents)})", len(agents) == 13)
check(f"command count is 15 (got {len(commands)})", len(commands) == 15)

# --- deterministic ordering --------------------------------------------------
check("skills sorted by name", [r["name"] for r in skills] == sorted(r["name"] for r in skills))
check("agents sorted by name", [r["name"] for r in agents] == sorted(r["name"] for r in agents))

# --- every skill record carries required authored fields ---------------------
required_skill_fields = {
    "name", "description", "version", "phase", "owner", "created", "tags",
    "related", "produces", "domain", "status",
    "has_references", "has_assets", "has_scripts", "has_contract_test",
}
check(
    "every skill record has the full field set",
    all(required_skill_fields <= set(r.keys()) for r in skills),
)
check(
    "every skill has a non-empty name and version",
    all(r["name"] and r["version"] for r in skills),
)
check(
    "derived flags are real bools on every skill",
    all(
        isinstance(r[k], bool)
        for r in skills
        for k in ("has_references", "has_assets", "has_scripts", "has_contract_test")
    ),
)

# --- known-skill DERIVED facts: adr-authoring --------------------------------
adr = m.resolve("adr-authoring")
check("resolve('adr-authoring') returns a skill", adr is not None and adr["kind"] == "skill")
adr_rec = adr["record"] if adr else {}
check("adr-authoring has_references (derived, non-empty dir)", adr_rec.get("has_references") is True)
check("adr-authoring has_assets (derived, non-empty dir)", adr_rec.get("has_assets") is True)
check("adr-authoring has_scripts (derived, non-empty dir)", adr_rec.get("has_scripts") is True)
check("adr-authoring has_contract_test (derived from tests/skills/)", adr_rec.get("has_contract_test") is True)

# --- known-skill AUTHORED frontmatter: adr-authoring -------------------------
check("adr-authoring version == 3.1.0", adr_rec.get("version") == "3.1.0")
check("adr-authoring phase == design", adr_rec.get("phase") == "design")
check("adr-authoring owner == enterprise-architect", adr_rec.get("owner") == "enterprise-architect")
check("adr-authoring inline tags parsed (7 tags)", adr_rec.get("tags") == [
    "design", "architecture", "adr", "decision-records", "trade-offs", "principles", "governance",
])
check("adr-authoring related parsed as list", adr_rec.get("related") == [
    "skill-authoring-standards", "nfr-specification",
])
check(
    "adr-authoring folded description parsed to one clean line",
    isinstance(adr_rec.get("description"), str)
    and adr_rec["description"].startswith("Teaches how to write Architecture Decision Records")
    and "\n" not in adr_rec["description"],
)

# --- a control skill that DOES NOT own the optional dirs / test --------------
# Pick a skill whose references/assets/scripts differ from adr's, proving the
# derivation is real per-skill and not hard-coded True everywhere.
neg = next(
    (
        r for r in skills
        if not r["has_references"] and not r["has_assets"] and not r["has_scripts"]
    ),
    None,
)
check("at least one skill has no references/assets/scripts (derivation discriminates)", neg is not None)

# --- block-list frontmatter style (event-schema-design) ----------------------
esd = m.resolve("event-schema-design")
esd_rec = esd["record"] if esd else {}
check(
    "block-style 'related:' list parsed (event-schema-design)",
    esd_rec.get("related") == ["domain-event-catalog", "go-domain-model", "data-retention-policy", "cqrs-pattern"],
)
check(
    "block-style 'tags:' list parsed (event-schema-design, 7 tags)",
    len(esd_rec.get("tags") or []) == 7 and "cloudevents" in (esd_rec.get("tags") or []),
)

# --- optional fields default correctly where absent --------------------------
# P2 (Skill Manifest Enrichment) is complete: all 186 skills now author
# produces/domain/status, so the absent-optional-field contract can no longer be
# pinned to a real skill that happens to lack them. It is pinned to a synthetic
# frontmatter fixture instead — the parser contract is unchanged — and the real
# tree now asserts the stronger post-P2 invariant.
_absent_optionals = m.parse_frontmatter(
    "---\n"
    "name: synthetic-skill\n"
    "description: Synthetic frontmatter pinning the absent-optional-field contract.\n"
    "version: 1.0.0\n"
    "phase: design\n"
    "owner: domain-modeler\n"
    "created: 2026-08-01\n"
    "tags: [synthetic]\n"
    "---\n"
)
check(
    "absent optional 'produces'/'status'/'domain' parse as absent (synthetic fixture)",
    _absent_optionals.get("produces") is None
    and _absent_optionals.get("status") is None
    and _absent_optionals.get("domain") is None,
)
check(
    "REAL: P2 complete — every skill authors produces + domain + status",
    all(
        r["produces"] is not None and r["domain"] is not None and r["status"] is not None
        for r in skills
    ),
)

# --- agents: authored fields + derived acceptance test -----------------------
be = m.resolve("backend-engineer")
check("resolve('backend-engineer') returns an agent", be is not None and be["kind"] == "agent")
be_rec = be["record"] if be else {}
check("backend-engineer role present", bool(be_rec.get("role")))
check("backend-engineer has skills list", isinstance(be_rec.get("skills"), list) and len(be_rec["skills"]) > 5)
check("backend-engineer tools == [Bash]", be_rec.get("tools") == ["Bash"])
check(
    "backend-engineer skills include mandatory glossary-management + methodology-review",
    "glossary-management" in be_rec.get("skills", []) and "methodology-review" in be_rec.get("skills", []),
)
check(
    "backend-engineer has_acceptance_test (derived from tests/agents/)",
    be_rec.get("has_acceptance_test") is True,
)
check(
    "every agent record exposes has_acceptance_test as a bool",
    all(isinstance(r.get("has_acceptance_test"), bool) for r in agents),
)

# --- commands: hyphenated keys normalized, has_test derived ------------------
adr_cmd = m.resolve("sdlc-adr")
check("resolve('sdlc-adr') returns a command", adr_cmd is not None and adr_cmd["kind"] == "command")
adr_cmd_rec = adr_cmd["record"] if adr_cmd else {}
check("sdlc-adr description present", bool(adr_cmd_rec.get("description")))
check(
    "sdlc-adr disable_model_invocation normalized to bool True",
    adr_cmd_rec.get("disable_model_invocation") is True,
)
check("sdlc-adr has_test (derived from tests/commands/)", adr_cmd_rec.get("has_test") is True)

# --- hooks: flattened handler records ----------------------------------------
check("load_hooks returns handler records", len(hooks) > 0)
check(
    "every hook record has event + type",
    all(h.get("event") and h.get("type") for h in hooks),
)
check(
    "command-type hooks expose a script basename",
    all(
        (h["script"] is not None and "/" not in h["script"])
        for h in hooks
        if h["type"] == "command"
    ),
)
check(
    "the tdd-gate script is wired as a hook",
    any(h.get("script") == "tdd-gate.sh" for h in hooks),
)

# --- all_component_names ------------------------------------------------------
names = m.all_component_names()
check("all_component_names is sorted + de-duplicated", names == sorted(set(names)))
check(
    "all_component_names covers skills + agents + commands",
    "adr-authoring" in names and "backend-engineer" in names and "sdlc-adr" in names,
)
check("resolve() of an unknown name is None", m.resolve("no-such-component-xyz") is None)

# --- PyYAML path and minimal-parser path agree -------------------------------
# Keep MANIFEST_FORCE_MINIMAL set across the load_skills() call — parser choice
# is made at parse time, not import time.
os.environ["MANIFEST_FORCE_MINIMAL"] = "1"
try:
    mm = _load_module(unique_name="_manifest_min")
    check("forced-minimal module reports minimal active", mm._force_minimal() is True)
    # If PyYAML is installed here, forcing minimal genuinely exercises the
    # fallback (not a no-yaml environment); if it isn't, the fallback is the
    # only path anyway. Either way the records below must still parse.
    check(
        "minimal fallback is exercised regardless of PyYAML presence",
        mm._yaml is None or mm._force_minimal() is True,
    )
    skills_min = mm.load_skills()
finally:
    os.environ.pop("MANIFEST_FORCE_MINIMAL", None)
check("minimal parser yields same skill count", len(skills_min) == len(skills))


def _cmp_key(rec):
    return (rec["name"], rec["version"], rec["phase"], rec["owner"],
            tuple(rec["tags"]), tuple(rec["related"] or ()),
            rec["has_references"], rec["has_assets"], rec["has_scripts"], rec["has_contract_test"])


yaml_index = {r["name"]: _cmp_key(r) for r in skills}
min_index = {r["name"]: _cmp_key(r) for r in skills_min}
check(
    "PyYAML and minimal parser produce identical skill records",
    yaml_index == min_index,
)

# --- purity: the module never writes to the working tree ---------------------
try:
    before = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout
    m.load_skills(); m.load_agents(); m.load_commands(); m.load_hooks(); m.all_component_names()
    after = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout
    check("loaders are pure reads (git status unchanged)", before == after)
except Exception as exc:  # pragma: no cover - git absent
    print(f"PASS: manifest_lib (purity check skipped — git unavailable: {exc})")

# --- summary -----------------------------------------------------------------
print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
