#!/usr/bin/env python3
"""
tests/arch/lint-manifests.test.py — contract test for scripts/lint-manifests.py
(P1.6, closes #787).

Verifies the manifest linter both mechanically (it flags a synthetic component
that violates its schema) and end-to-end (it imports, runs against the REAL
repo, and returns a well-formed result + an integer exit code). Asserts:

  * the linter module imports and exposes its documented API;
  * a synthetic SKILL record missing a required field ('version') is flagged,
    and the reason names the missing field;
  * a synthetic AGENT missing the mandatory 'methodology-review' skill is
    flagged (the schema's non-negotiable cross-field rule);
  * a well-formed synthetic skill produces ZERO violations (no false positive);
  * record_to_instance() drops manifest's derived keys and None-valued optional
    fields, and maps command snake_case keys back to the schema's hyphenated
    keys — so additionalProperties:false schemas are validated fairly;
  * REGRESSION (#1211): an AGENT's produces/domain/status reach the validator,
    and a typo'd/unknown key on an agent (or a command) is REJECTED by
    additionalProperties:false rather than silently dropped by the projection;
  * lint() returns {'violations','summary','ok'} with per-kind pass/total and
    the real-repo counts (186 skills, 13 agents, 15 commands, 1 hooks.json);
  * ok is the boolean complement of 'any violations';
  * main() runs and returns an int in {0,1}.

Prints PASS/FAIL lines; exits 0 iff every check passed. Standalone-runnable:
    python3 tests/arch/lint-manifests.test.py
"""

import importlib.util
import io
import sys
from contextlib import redirect_stdout
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lint-manifests.py"


def _load_module(unique_name="_lint_manifests_under_test"):
    """Import scripts/lint-manifests.py (hyphenated filename) under a private
    module name via importlib — a plain `import` cannot name a hyphenated file."""
    spec = importlib.util.spec_from_file_location(unique_name, MODULE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: lint-manifests ({name})")
        passed += 1
    else:
        print(f"FAIL: lint-manifests ({name})")
        failed.append(name)


# --- module import + API surface --------------------------------------------
check("module file exists", MODULE_PATH.is_file())
lm = _load_module()
for fn in ("load_schema", "record_to_instance", "validate_instance", "lint", "main"):
    check(f"exposes {fn}()", callable(getattr(lm, fn, None)))

skill_schema = lm.load_schema("skill")
agent_schema = lm.load_schema("agent")
command_schema = lm.load_schema("command")

# --- synthetic: a skill missing a required field is flagged ------------------
good_skill = {
    "name": "synthetic-skill",
    "description": "a synthetic skill used only by this test",
    "version": "1.0.0",
    "phase": "quality",
    "owner": "test",
    "created": "2026-08-01",
    "tags": ["testing"],
    # manifest injects these as None when absent — the linter must drop them:
    "related": None, "produces": None, "domain": None, "status": None,
    # derived keys the linter must NOT forward to an additionalProperties view:
    "has_references": True, "has_assets": False, "has_scripts": False,
    "has_contract_test": True, "dir": "skills/synthetic-skill",
}

good_instance = lm.record_to_instance("skill", good_skill)
check(
    "record_to_instance drops derived + None-optional keys",
    set(good_instance.keys()) == {
        "name", "description", "version", "phase", "owner", "created", "tags"
    },
)
check(
    "well-formed synthetic skill has ZERO violations",
    lm.validate_instance(good_instance, skill_schema) == [],
)

bad_skill = dict(good_skill)
del bad_skill["version"]
bad_reasons = lm.validate_instance(lm.record_to_instance("skill", bad_skill), skill_schema)
check("skill missing 'version' is flagged", len(bad_reasons) >= 1)
check(
    "the reason names the missing 'version' field",
    any("version" in r for r in bad_reasons),
)

# --- synthetic: an agent missing the mandatory methodology-review skill ------
base_agent = {
    "name": "synthetic-agent",
    "description": "a synthetic agent for this test",
    "role": "test role",
    "version": "1.0.0",
    "phase": "quality",
    "owner": "test",
    "created": "2026-08-01",
    "inputs": ["something"],
    "outputs": ["something-else"],
    "skills": ["glossary-management", "methodology-review", "some-domain-skill"],
    "tools": ["Bash"],
    "tags": ["testing"],
    "has_acceptance_test": True, "has_contract_test": True,
    "file": "agents/synthetic-agent.md",
}
check(
    "well-formed synthetic agent has ZERO violations",
    lm.validate_instance(lm.record_to_instance("agent", base_agent), agent_schema) == [],
)
missing_methodology = dict(base_agent)
missing_methodology["skills"] = ["glossary-management", "some-domain-skill"]
mm_reasons = lm.validate_instance(
    lm.record_to_instance("agent", missing_methodology), agent_schema
)
check("agent missing methodology-review in skills is flagged", len(mm_reasons) >= 1)

# --- REGRESSION (#1211): the agent projection must not silently drop fields ---
# The linter used to project a hard-coded 12-field _AGENT_FIELDS tuple, so the
# P5 manifest fields never reached the validator and a typo'd key was invisible:
# injecting `domainn:` into agents/product-strategist.md still produced
# 'TOTAL 0 violation(s) / RESULT: PASS'. These checks pin that hole shut.
enriched_agent = dict(base_agent)
enriched_agent.update({"produces": ["some-artifact"], "domain": "quality",
                       "status": "stable"})
enriched_instance = lm.record_to_instance("agent", enriched_agent)
check(
    "agent instance carries the P5 manifest fields (produces/domain/status)",
    {"produces", "domain", "status"} <= set(enriched_instance.keys()),
)
check(
    "well-formed enriched agent still has ZERO violations",
    lm.validate_instance(enriched_instance, agent_schema) == [],
)
unenriched = dict(base_agent)
unenriched.update({"produces": None, "domain": None, "status": None})
check(
    "an unenriched agent's None manifest fields are dropped, not type-errors",
    lm.validate_instance(lm.record_to_instance("agent", unenriched), agent_schema) == [],
)

typo_agent = dict(base_agent)
typo_agent["extra"] = {"domainn": "strategy"}
typo_instance = lm.record_to_instance("agent", typo_agent)
typo_reasons = lm.validate_instance(typo_instance, agent_schema)
check("a typo'd/unknown AGENT field reaches the schema instance",
      "domainn" in typo_instance)
check("a typo'd/unknown AGENT field is REJECTED by additionalProperties:false",
      any("domainn" in r and "Additional properties" in r for r in typo_reasons))

empty_typo = dict(base_agent)
empty_typo["extra"] = {"domainn": None}
check(
    "an unknown AGENT field authored with an EMPTY value is still rejected",
    any("domainn" in r for r in lm.validate_instance(
        lm.record_to_instance("agent", empty_typo), agent_schema)),
)

# The same must hold for commands (additionalProperties:false) without breaking
# the snake_case -> hyphenated key mapping the command projection depends on.
typo_command = {
    "name": "sdlc-thing", "description": "does a thing",
    "argument_hint": None, "allowed_tools": None, "model": None,
    "disable_model_invocation": None, "has_test": True,
    "file": "commands/sdlc-thing.md", "extra": {"arguments-hint": "typo"},
}
typo_cmd_instance = lm.record_to_instance("command", typo_command)
check(
    "command projection still maps keys AND surfaces unknown ones",
    typo_cmd_instance == {"description": "does a thing", "arguments-hint": "typo"}
    and any("arguments-hint" in r
            for r in lm.validate_instance(typo_cmd_instance, command_schema)),
)

# --- synthetic: command snake_case keys map back to hyphenated ---------------
cmd_record = {
    "name": "sdlc-thing", "description": "does a thing",
    "argument_hint": "a string hint", "allowed_tools": None,
    "model": None, "disable_model_invocation": True,
    "has_test": True, "file": "commands/sdlc-thing.md",
}
cmd_instance = lm.record_to_instance("command", cmd_record)
check(
    "command instance uses hyphenated schema keys, no 'name'/derived keys",
    "argument-hint" in cmd_instance
    and "disable-model-invocation" in cmd_instance
    and "name" not in cmd_instance
    and "has_test" not in cmd_instance,
)
check(
    "well-formed synthetic command has ZERO violations",
    lm.validate_instance(cmd_instance, command_schema) == [],
)

# --- end-to-end: lint() runs against the real repo --------------------------
result = lm.lint()
check("lint() returns a dict with the documented keys",
      isinstance(result, dict) and {"violations", "summary", "ok"} <= set(result))
summary = result.get("summary", {})
check("summary reports 186 skills", summary.get("skill", {}).get("total") == 186)
check("summary reports 13 agents", summary.get("agent", {}).get("total") == 13)
check("summary reports 15 commands", summary.get("command", {}).get("total") == 15)
check("summary reports the hooks.json file", summary.get("hook", {}).get("total") == 1)
check("violations is a list of '<file>: <reason>' strings",
      isinstance(result["violations"], list)
      and all(isinstance(v, str) and ": " in v for v in result["violations"]))
check("ok is the boolean complement of any-violations",
      result["ok"] is (len(result["violations"]) == 0))

# --- main() runs and returns an int exit code -------------------------------
buf = io.StringIO()
with redirect_stdout(buf):
    rc = lm.main()
out = buf.getvalue()
check("main() returns an int exit code in {0,1}", isinstance(rc, int) and rc in (0, 1))
check("main() prints a summary section", "lint-manifests summary:" in out)
check("main() exit code agrees with lint() ok",
      (rc == 0) == result["ok"])

# --- verdict -----------------------------------------------------------------
print("")
if failed:
    print(f"FAIL: lint-manifests — {len(failed)} check(s) failed: {failed}")
    sys.exit(1)
print(f"PASS: lint-manifests — all {passed} checks passed")
sys.exit(0)
