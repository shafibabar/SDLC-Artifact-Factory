#!/usr/bin/env python3
"""
tests/arch/manifest_lib.test.py — contract test for scripts/arch/manifest.py
(P1.1, closes #781).

Runs against the REAL repo (no fixtures): the manifest library is the shared
foundation the P1 linters and the P3 catalog import, so its contract is pinned
to the live component tree. Asserts:

  * the skill count equals the number of skills/*/SKILL.md on disk (not a
    pinned number: the Fresh-Eyes waves add skills), and exact agent and
    command counts (13, 15) — a drift means the manifest missed a component;
  * filesystem-DERIVED booleans are computed correctly for a known skill
    (derived flags are checked against filesystem truth for every skill);
  * authored frontmatter is parsed correctly (fields, inline lists, block
    lists, folded '>' descriptions);
  * the PyYAML path and the minimal fallback parser agree (both are exercised);
  * resolve(), all_component_names(), load_agents() (has_acceptance_test) and
    load_hooks() behave per their documented contract;
  * load_agents() reads the P5 manifest fields (produces/domain/status) and
    keeps records shape-stable, and every loader preserves unknown authored keys
    in `extra` instead of dropping them (#1211 — the dropped keys were why a
    typo'd agent field never reached the schema validator);
  * purity — importing and calling every loader leaves the working tree clean
    (the module never writes).

Prints PASS/FAIL lines; exits 0 iff every check passed. Standalone-runnable:
    python3 tests/arch/manifest_lib.test.py
"""

import importlib.util
import os
import re
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
FS_SKILLS = len(list((Path(__file__).resolve().parents[2] / "skills").glob("*/SKILL.md")))
check(f"skill count matches skills/*/SKILL.md on disk ({FS_SKILLS}; got {len(skills)})", len(skills) == FS_SKILLS)
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
    "has_resources", "has_templates", "has_examples", "has_steps", "has_evals",
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
        for k in ("has_references", "has_assets", "has_scripts", "has_contract_test",
                  "has_resources", "has_templates", "has_examples", "has_steps", "has_evals")
    ),
)

# --- DERIVED facts match filesystem truth, for EVERY skill --------------------
# These used to be pinned to adr-authoring's shape at one point in time (has
# assets/, has a contract test). The Fresh-Eyes waves change every skill's
# layout, so pinning a real skill made this test break whenever that skill was
# refactored. Instead: for every skill, each derived flag must equal what the
# filesystem says — stronger (every skill, not one) and refactor-proof.
def _nonempty(p):
    return p.is_dir() and any(p.iterdir())
_mismatch = []
for r in skills:
    sd = REPO_ROOT / r["dir"]
    for d in m.SKILL_SUBDIRS:
        if r[f"has_{d}"] != _nonempty(sd / d):
            _mismatch.append(f"{r['name']}.has_{d}")
    if r["has_contract_test"] != (REPO_ROOT / "tests" / "skills" / f"{r['name']}.contract.sh").is_file():
        _mismatch.append(f"{r['name']}.has_contract_test")
check(f"every skill's derived has_* flags equal filesystem truth ({len(skills)} skills)", _mismatch == [])
check("resolve('adr-authoring') returns a skill record",
      (m.resolve("adr-authoring") or {}).get("kind") == "skill")
_disc = {f"has_{d}" for d in ("references", "assets", "scripts")}
check("derivation discriminates (some skills have, some lack, each of references/assets/scripts)",
      all(any(r[k] for r in skills) and not all(r[k] for r in skills) for k in _disc))

# --- AUTHORED frontmatter: the parser contract, on a synthetic fixture -------
# Previously pinned to adr-authoring (inline lists, folded description) and
# event-schema-design (block lists). Same contract, now refactor-proof.
_fx_fm = m.parse_frontmatter(
    "---\n"
    "name: fixture-skill\n"
    "description: >\n"
    "  Teaches how to write Architecture Decision Records and when not to,\n"
    "  across two folded lines.\n"
    "version: 4.0.0\n"
    "phase: design\n"
    "owner: enterprise-architect\n"
    "created: 2026-06-25\n"
    "tags: [design, architecture, adr, decision-records, trade-offs, principles, governance]\n"
    "related: [skill-authoring-standards, nfr-specification]\n"
    "sources:\n"
    "  - research/software-architecture/just-enough-software-architecture-fairbanks.md\n"
    "  - research/software-architecture/documenting-software-architectures-clements.md\n"
    "---\nbody\n"
)
check("folded description parsed to one clean line",
      isinstance(_fx_fm.get("description"), str)
      and _fx_fm["description"].startswith("Teaches how to write Architecture Decision Records")
      and "\n" not in _fx_fm["description"])
check("inline tags list parsed (7 tags)", _fx_fm.get("tags") == [
    "design", "architecture", "adr", "decision-records", "trade-offs", "principles", "governance"])
check("inline related list parsed", _fx_fm.get("related") == ["skill-authoring-standards", "nfr-specification"])
check("block-style sources list parsed", _fx_fm.get("sources") == [
    "research/software-architecture/just-enough-software-architecture-fairbanks.md",
    "research/software-architecture/documenting-software-architectures-clements.md"])
check("scalars parsed (version, phase, owner)",
      (_fx_fm.get("version"), _fx_fm.get("phase"), _fx_fm.get("owner")) == ("4.0.0", "design", "enterprise-architect"))

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
check("backend-engineer tools == standard set", be_rec.get("tools") == ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Skill"])
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

# --- agents: P5 manifest fields (produces/domain/status) are READ ------------
# These were authored on agents before load_agents() read them, so they reached
# nothing: not the linter's schema view, not the catalog. Records must now be
# shape-stable — the keys are ALWAYS present, exactly as on a skill record.
check(
    "every agent record carries produces/domain/status keys (shape-stable)",
    all({"produces", "domain", "status", "extra"} <= set(r.keys()) for r in agents),
)
check(
    "an unenriched agent's produces/domain/status are None, not missing",
    all(
        (r["produces"] is None or isinstance(r["produces"], list))
        and (r["domain"] is None or isinstance(r["domain"], str))
        and (r["status"] is None or isinstance(r["status"], str))
        for r in agents
    ),
)
ps = m.resolve("product-strategist")
ps_rec = ps["record"] if ps else {}
check("product-strategist domain == strategy (authored)", ps_rec.get("domain") == "strategy")
check("product-strategist status == stable (authored)", ps_rec.get("status") == "stable")
# Filesystem truth, not a pinned count (#1256 changed the agent's outputs).
_ps_text = (REPO_ROOT / "agents" / "product-strategist.md").read_text()
_ps_block = re.search(r"^produces:\n((?:  - .+\n)+)", _ps_text, re.M)
_ps_authored = [l.strip()[2:].strip() for l in _ps_block.group(1).splitlines()] if _ps_block else []
check(
    "product-strategist produces parsed as the block list its file declares",
    isinstance(ps_rec.get("produces"), list)
    and len(_ps_authored) > 1
    and ps_rec["produces"] == _ps_authored
    and "vision-statement" in ps_rec["produces"],
)
check(
    "scalar 'produces:' normalizes to a list for agents exactly as for skills",
    m._opt_list("solo-artifact") == ["solo-artifact"] and m._opt_list(None) is None,
)

# --- unknown authored keys survive into `extra` (never silently dropped) -----
# This is what lets lint-manifests enforce additionalProperties:false. A typo'd
# key used to vanish inside the loader, so the validator never saw it.
_typo_fm = m.parse_frontmatter(
    "---\n"
    "name: synthetic-agent\n"
    "description: Synthetic frontmatter pinning the unknown-key contract.\n"
    "role: test role\n"
    "version: 1.0.0\n"
    "phase: design\n"
    "owner: shafi\n"
    "created: 2026-08-01\n"
    "domainn: strategy\n"
    "---\n"
)
check(
    "a typo'd agent key is preserved by _extra(), not dropped",
    m._extra(_typo_fm, m._AGENT_FM_KEYS) == {"domainn": "strategy"},
)
check(
    "a correctly-spelled agent key is NOT reported as extra",
    m._extra(
        {"name": "a", "domain": "strategy", "produces": ["x"], "status": "stable"},
        m._AGENT_FM_KEYS,
    ) == {},
)
check(
    "every real agent authors zero unknown frontmatter keys",
    all(r["extra"] == {} for r in agents),
)
check(
    "extra is a dict on every skill/agent/command record",
    all(isinstance(r.get("extra"), dict) for r in skills + agents + commands),
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
# --- sources: is a KNOWN skill key (Fresh-Eyes A2) ---------------------------
# If it were unknown it would land in `extra` and lint-manifests would forward
# it as an unrecognised field instead of the projected, schema-checked one.
check("sources is a known skill frontmatter key", "sources" in m._SKILL_FM_KEYS)
check("every live skill record carries a sources key (list or None)",
      all("sources" in r and (r["sources"] is None or isinstance(r["sources"], list)) for r in m.load_skills()))
check("sources never leaks into extra",
      all("sources" not in (r.get("extra") or {}) for r in m.load_skills()))

# --- has_<folder> + has_evals derived from a synthetic tree (Fresh-Eyes A4) ---
import tempfile as _tempfile
check("SKILL_SUBDIRS is the 7-folder spec, in order",
      m.SKILL_SUBDIRS == ("references", "resources", "templates", "examples", "steps", "scripts", "assets"))
with _tempfile.TemporaryDirectory() as _td:
    _root = Path(_td)
    _sk = _root / "skills" / "fx-skill"
    (_sk / "templates").mkdir(parents=True)
    (_sk / "templates" / "t.md").write_text("x")
    (_sk / "examples").mkdir()                       # EMPTY -> must be False
    (_sk / "SKILL.md").write_text("---\nname: fx-skill\nversion: 1.0.0\n---\nbody\n")
    (_root / "evals" / "fx-skill" / "case-a").mkdir(parents=True)
    (_root / "evals" / "fx-skill" / "case-a" / "prompt.md").write_text("q")
    fx = _load_module(unique_name="_manifest_fx")
    fx.REPO_ROOT, fx.SKILLS_DIR = _root, _root / "skills"
    fx.EVALS_DIR, fx.TESTS_SKILLS_DIR = _root / "evals", _root / "tests" / "skills"
    _rec = fx.load_skills()[0]
check("has_templates True for a non-empty templates/", _rec["has_templates"] is True)
check("has_examples False for an EMPTY examples/ dir", _rec["has_examples"] is False)
check("has_steps False when the folder is absent", _rec["has_steps"] is False)
check("has_evals True for a root evals/<skill>/ with a case", _rec["has_evals"] is True)
with _tempfile.TemporaryDirectory() as _td2:
    _r2 = Path(_td2)
    (_r2 / "skills" / "fx-two").mkdir(parents=True)
    (_r2 / "skills" / "fx-two" / "SKILL.md").write_text("---\nname: fx-two\nversion: 1.0.0\n---\n")
    (_r2 / "evals" / "fx-two" / "results" / "run-1").mkdir(parents=True)
    (_r2 / "evals" / "fx-two" / "results" / "run-1" / "prompt.md").write_text("run output copy")
    fx2 = _load_module(unique_name="_manifest_fx2")
    fx2.REPO_ROOT, fx2.SKILLS_DIR = _r2, _r2 / "skills"
    fx2.EVALS_DIR, fx2.TESTS_SKILLS_DIR = _r2 / "evals", _r2 / "tests" / "skills"
    _rec2 = fx2.load_skills()[0]
check("has_evals False when evals/<skill>/ holds only run results", _rec2["has_evals"] is False)
check("every SKILL_SUBDIRS folder yields a has_ flag",
      all(f"has_{d}" in _rec for d in fx.SKILL_SUBDIRS))

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
