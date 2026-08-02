#!/usr/bin/env python3
"""
tests/arch/build-catalog.test.py — contract test for scripts/arch/build-catalog.py
(P3.1, closes #1184).

build_catalog() is PURE (it takes already-loaded component lists and returns a
dict), so the behavioural assertions are driven with SYNTHETIC components — no
dependence on the live tree for the logic. The real tree is then used for the
invariants that only make sense against it (counts agree with manifest.py, no
dangling edges, every skill lands in exactly one capability domain).

Asserts:

  (a) DETERMINISM — the catalog is a COMMITTED derived artifact, so two builds
      over the same inputs must be byte-identical, and the rendered output must
      carry NO timestamp / generator-version field. A clock-dependent field
      would make every regeneration a spurious diff and defeat the staleness
      check that gates the catalog in CI.

  (b) THE ARTIFACT REVERSE INDEX — artifact -> [producing skills], with multiple
      producers preserved (the stack-neutral artifacts: one artifact kind
      produced by the go-*, python- and react-* skills alike).

  (c) THE CAPABILITY VIEW is DERIVED from domain:, never authored — every skill
      with a domain appears under exactly one domain, with its owner and its
      produced artifacts rolled up.

  (d) EDGE INTEGRITY — agent_skills / skill_related / skill_produces are emitted
      sorted, and over the real tree every edge endpoint resolves to a real
      component (no dangling references).

  (e) PURITY — build_catalog() does not mutate its inputs; --stdout and --check
      write nothing; running the generator leaves the working tree clean when
      the committed catalog is current.

Standalone-runnable:
    python3 tests/arch/build-catalog.test.py
"""

import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "arch" / "build-catalog.py"
MANIFEST_PATH = REPO_ROOT / "scripts" / "arch" / "manifest.py"
CATALOG_PATH = REPO_ROOT / "generated" / "catalog.json"


def _load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: build-catalog ({name})")
        passed += 1
    else:
        print(f"FAIL: build-catalog ({name})")
        failed.append(name)


check("module file exists", MODULE_PATH.is_file())
b = _load_module(MODULE_PATH, "_build_catalog_under_test")
m = _load_module(MANIFEST_PATH, "_manifest_for_catalog_test")

# ---------------------------------------------------------------------------
# Synthetic fixtures — the behavioural contract, independent of the live tree
# ---------------------------------------------------------------------------
SYN_SKILLS = [
    {"name": "beta-skill", "version": "1.0.0", "phase": "design", "owner": "agent-two",
     "domain": "architecture", "status": "stable", "produces": ["shared-artifact"],
     "related": ["alpha-skill"], "tags": ["design"], "created": "2026-01-02",
     "has_references": True, "has_assets": False, "has_scripts": False,
     "has_contract_test": True, "dir": "skills/beta-skill"},
    {"name": "alpha-skill", "version": "2.0.0", "phase": "design", "owner": "agent-one",
     "domain": "architecture", "status": "stable", "produces": "shared-artifact",
     "related": ["beta-skill"], "tags": ["design"], "created": "2026-01-01",
     "has_references": False, "has_assets": False, "has_scripts": False,
     "has_contract_test": False, "dir": "skills/alpha-skill"},
    {"name": "gamma-skill", "version": "1.0.0", "phase": "implement", "owner": "agent-one",
     "domain": "backend", "status": "experimental",
     "produces": ["first-artifact", "second-artifact"],
     "related": [], "tags": ["implement"], "created": "2026-01-03",
     "has_references": False, "has_assets": False, "has_scripts": True,
     "has_contract_test": True, "dir": "skills/gamma-skill"},
]
SYN_AGENTS = [
    {"name": "agent-one", "version": "1.0.0", "phase": "implement", "role": "r",
     "skills": ["gamma-skill", "alpha-skill"], "tools": ["Bash"], "tags": ["t"],
     "created": "2026-01-01", "has_acceptance_test": True, "file": "agents/agent-one.md"},
]
SYN_COMMANDS = [
    {"name": "sdlc-thing", "description": "d", "argument_hint": None, "allowed_tools": [],
     "model": None, "disable_model_invocation": False, "has_test": True,
     "file": "commands/sdlc-thing.md"},
]
SYN_HOOKS = [
    {"event": "PostToolUse", "matcher": "Write", "type": "command",
     "command": "x.sh", "script": "x.sh", "timeout": 10, "order": 0},
]

syn = b.build_catalog(SYN_SKILLS, SYN_AGENTS, SYN_COMMANDS, SYN_HOOKS)

# --- (a) determinism ---------------------------------------------------------
syn_again = b.build_catalog(SYN_SKILLS, SYN_AGENTS, SYN_COMMANDS, SYN_HOOKS)
check("two builds over identical inputs are equal", syn == syn_again)
check("two renders over identical inputs are byte-identical",
      b.render(syn) == b.render(syn_again))

rendered = b.render(syn)
_forbidden = ("generated_at", "timestamp", "built_at", "generator_version", "generated_on")
check("rendered catalog carries no timestamp/generator-version field",
      not any(f'"{k}"' in rendered for k in _forbidden))
check("render() output is valid JSON ending in a single newline",
      json.loads(rendered) == syn and rendered.endswith("}\n"))

# --- ordering is stable regardless of input order ---------------------------
shuffled = b.build_catalog(list(reversed(SYN_SKILLS)), SYN_AGENTS, SYN_COMMANDS, SYN_HOOKS)
check("output is independent of input ordering (skills sorted by name)",
      b.render(shuffled) == b.render(syn))
check("skills emitted sorted by name",
      [s["name"] for s in syn["components"]["skills"]] ==
      sorted(s["name"] for s in syn["components"]["skills"]))

# --- (b) artifact reverse index ---------------------------------------------
# Values are KIND-TAGGED {"agents": [...], "skills": [...]} (P5) rather than a
# flat producer list: a skill is applied and an agent is invoked, so a consumer
# resolving 'who produces X' must be able to tell the two apart.
check("artifact index maps artifact -> producing skills",
      syn["artifacts"]["shared-artifact"]["skills"] == ["alpha-skill", "beta-skill"])
check("a skill producing several artifacts appears under each",
      syn["artifacts"]["first-artifact"]["skills"] == ["gamma-skill"]
      and syn["artifacts"]["second-artifact"]["skills"] == ["gamma-skill"])
check("artifact index values are kind-tagged, with both keys always present",
      all(set(v.keys()) == {"agents", "skills"} for v in syn["artifacts"].values()))
check("an artifact with no agent producer carries an empty agents list",
      syn["artifacts"]["shared-artifact"]["agents"] == [])
check("scalar 'produces:' is normalized to a list (alpha-skill authored a string)",
      [s for s in syn["components"]["skills"] if s["name"] == "alpha-skill"][0]["produces"]
      == ["shared-artifact"])

# --- (c) capability view -----------------------------------------------------
check("capability view is keyed by domain",
      sorted(syn["capabilities"].keys()) == ["architecture", "backend"])
check("capability rolls up its skills",
      syn["capabilities"]["architecture"]["skills"] == ["alpha-skill", "beta-skill"])
check("capability rolls up the owning agents",
      syn["capabilities"]["architecture"]["owners"] == ["agent-one", "agent-two"])
check("capability rolls up produced artifacts",
      syn["capabilities"]["backend"]["artifacts"] == ["first-artifact", "second-artifact"])
check("capability carries a skill_count matching its skill list",
      all(c["skill_count"] == len(c["skills"]) for c in syn["capabilities"].values()))
check("capability carries an agents roll-up + agent_count (empty when unauthored)",
      all(c["agents"] == [] and c["agent_count"] == 0 for c in syn["capabilities"].values()))

# --- (d) edges ---------------------------------------------------------------
check("agent_skills edges are emitted sorted",
      syn["edges"]["agent_skills"] ==
      [{"agent": "agent-one", "skill": "alpha-skill"},
       {"agent": "agent-one", "skill": "gamma-skill"}])
check("an unenriched agent yields no agent_produces edges",
      syn["edges"]["agent_produces"] == []
      and syn["counts"]["edges_agent_produces"] == 0)
check("skill_produces edges cover every (skill, artifact) pair",
      len(syn["edges"]["skill_produces"]) == 4)
check("skill_related edges preserve the authored see-also",
      {"skill": "alpha-skill", "related": "beta-skill"} in syn["edges"]["skill_related"])

# --- counts ------------------------------------------------------------------
check("counts agree with the component lists",
      syn["counts"]["skills"] == 3 and syn["counts"]["agents"] == 1
      and syn["counts"]["commands"] == 1 and syn["counts"]["hooks"] == 1)
check("counts.artifacts counts distinct artifacts, not edges",
      syn["counts"]["artifacts"] == 3 and syn["counts"]["edges_skill_produces"] == 4)

# --- a skill with neither domain nor an owning agent is counted an orphan ----
orphan_set = b.build_catalog(
    SYN_SKILLS + [{"name": "zeta-skill", "version": "1.0.0", "phase": "design",
                   "owner": "agent-nine", "domain": None, "status": None,
                   "produces": [], "related": [], "tags": [], "created": "2026-01-04",
                   "has_references": False, "has_assets": False, "has_scripts": False,
                   "has_contract_test": False, "dir": "skills/zeta-skill"}],
    SYN_AGENTS, SYN_COMMANDS, SYN_HOOKS)
check("a skill with no domain and no owning agent is counted as an orphan",
      orphan_set["counts"]["orphan_skills"] == 1)
check("a domain-less skill is excluded from the capability view",
      "zeta-skill" not in
      {s for cap in orphan_set["capabilities"].values() for s in cap["skills"]})

# --- an unresolved related: target is counted, not silently dropped ----------
dangling = b.build_catalog(
    SYN_SKILLS + [{"name": "eta-skill", "version": "1.0.0", "phase": "design",
                   "owner": "agent-one", "domain": "architecture", "status": "stable",
                   "produces": [], "related": ["no-such-skill"], "tags": [],
                   "created": "2026-01-05", "has_references": False, "has_assets": False,
                   "has_scripts": False, "has_contract_test": False,
                   "dir": "skills/eta-skill"}],
    SYN_AGENTS, SYN_COMMANDS, SYN_HOOKS)
check("an unresolved 'related:' target is surfaced in counts",
      dangling["counts"]["unresolved_skill_related"] == 1)

# --- (e) purity: inputs are not mutated --------------------------------------
_before = copy.deepcopy(SYN_SKILLS)
b.build_catalog(SYN_SKILLS, SYN_AGENTS, SYN_COMMANDS, SYN_HOOKS)
check("build_catalog does not mutate its inputs", SYN_SKILLS == _before)

# ---------------------------------------------------------------------------
# (f) P5 — AGENT manifest fields (produces/domain/status) reach the catalog
#
# Before P5 these fields reached nothing: manifest.load_agents() never read them,
# lint-manifests projected a fixed 12-field tuple, and _agent_entry() emitted no
# such key — so `produces` on an agent could not link artifact -> producing agent,
# which was the entire point of authoring it.
# ---------------------------------------------------------------------------
P5_AGENTS = [
    # enriched: shares 'shared-artifact' with two skills (co-producer case) and
    # owns one artifact no skill produces.
    {"name": "agent-one", "version": "1.0.0", "phase": "implement", "role": "r",
     "domain": "backend", "status": "stable",
     "produces": ["shared-artifact", "agent-only-artifact"],
     "skills": ["gamma-skill", "alpha-skill"], "tools": ["Bash"], "tags": ["t"],
     "created": "2026-01-01", "has_acceptance_test": True, "file": "agents/agent-one.md"},
    # NOT yet enriched: keys present but None — records are shape-stable, and no
    # derivation may blow up or invent a domain for it.
    {"name": "agent-two", "version": "1.0.0", "phase": "design", "role": "r",
     "domain": None, "status": None, "produces": None,
     "skills": ["beta-skill"], "tools": [], "tags": ["t"],
     "created": "2026-01-02", "has_acceptance_test": False, "file": "agents/agent-two.md"},
    # authors 'produces' as a bare SCALAR — normalized to a list, exactly as a
    # skill's scalar produces: already is.
    {"name": "agent-three", "version": "1.0.0", "phase": "strategy", "role": "r",
     "domain": "strategy", "status": "experimental", "produces": "scalar-artifact",
     "skills": ["alpha-skill"], "tools": [], "tags": ["t"],
     "created": "2026-01-03", "has_acceptance_test": False, "file": "agents/agent-three.md"},
]
p5 = b.build_catalog(SYN_SKILLS, P5_AGENTS, SYN_COMMANDS, SYN_HOOKS)
p5_by_name = {a["name"]: a for a in p5["components"]["agents"]}

check("P5: agent entry emits produces/domain/status",
      p5_by_name["agent-one"]["produces"] == ["agent-only-artifact", "shared-artifact"]
      and p5_by_name["agent-one"]["domain"] == "backend"
      and p5_by_name["agent-one"]["status"] == "stable")
check("P5: an unenriched agent still carries the keys (None / empty list)",
      p5_by_name["agent-two"]["produces"] == []
      and p5_by_name["agent-two"]["domain"] is None
      and p5_by_name["agent-two"]["status"] is None)
check("P5: scalar 'produces:' on an agent is normalized to a list",
      p5_by_name["agent-three"]["produces"] == ["scalar-artifact"])

check("P5: agent_produces edges are emitted sorted by (agent, artifact)",
      p5["edges"]["agent_produces"] ==
      [{"agent": "agent-one", "artifact": "agent-only-artifact"},
       {"agent": "agent-one", "artifact": "shared-artifact"},
       {"agent": "agent-three", "artifact": "scalar-artifact"}]
      and p5["counts"]["edges_agent_produces"] == 3)

check("P5: artifact index links an artifact to its producing AGENT",
      p5["artifacts"]["agent-only-artifact"] ==
      {"agents": ["agent-one"], "skills": []})
check("P5: an artifact produced by both kinds keeps them separately resolvable",
      p5["artifacts"]["shared-artifact"] ==
      {"agents": ["agent-one"], "skills": ["alpha-skill", "beta-skill"]})
check("P5: an agent-only artifact is counted in counts.artifacts",
      p5["counts"]["artifacts"] == 5)

check("P5: capability rolls agents up by their own domain:",
      p5["capabilities"]["backend"]["agents"] == ["agent-one"]
      and p5["capabilities"]["backend"]["agent_count"] == 1)
check("P5: agent-produced artifacts roll into their capability domain",
      p5["capabilities"]["backend"]["artifacts"] ==
      ["agent-only-artifact", "first-artifact", "second-artifact", "shared-artifact"])
check("P5: an agent's own owner: does NOT pollute capability owners",
      p5["capabilities"]["backend"]["owners"] == ["agent-one"])
check("P5: an agent domain with no skills still forms a capability entry",
      p5["capabilities"]["strategy"] ==
      {"skills": [], "agents": ["agent-three"], "owners": [],
       "artifacts": ["scalar-artifact"], "skill_count": 0, "agent_count": 1})
check("P5: a domain-less agent joins no capability",
      "agent-two" not in
      {a for cap in p5["capabilities"].values() for a in cap["agents"]})

check("P5: coverage counts enriched agents",
      p5["coverage"]["agents_with_produces"] == 2
      and p5["coverage"]["agents_with_domain"] == 2
      and p5["coverage"]["agents_with_status"] == 2)

_p5_before = copy.deepcopy(P5_AGENTS)
check("P5: two builds with enriched agents are byte-identical",
      b.render(p5) == b.render(b.build_catalog(SYN_SKILLS, P5_AGENTS, SYN_COMMANDS, SYN_HOOKS)))
check("P5: build_catalog does not mutate the agent records", P5_AGENTS == _p5_before)


# ---------------------------------------------------------------------------
# REAL tree — invariants that only hold against the live components
# ---------------------------------------------------------------------------
real = b.build_from_repo()
real_skills = m.load_skills()
real_agents = m.load_agents()

check(f"REAL: skill count matches manifest.py ({len(real_skills)})",
      real["counts"]["skills"] == len(real_skills))
check(f"REAL: agent count matches manifest.py ({len(real_agents)})",
      real["counts"]["agents"] == len(real_agents))
check("REAL: every skill appears in the components block",
      {s["name"] for s in real["components"]["skills"]} == {s["name"] for s in real_skills})

_real_skill_names = {s["name"] for s in real["components"]["skills"]}
_real_agent_names = {a["name"] for a in real["components"]["agents"]}
check("REAL: every agent_skills edge resolves to a real agent and a real skill",
      all(e["agent"] in _real_agent_names and e["skill"] in _real_skill_names
          for e in real["edges"]["agent_skills"]))
check("REAL: no unresolved 'related:' targets (P2 drove this to 0)",
      real["counts"]["unresolved_skill_related"] == 0)
check("REAL: no orphan skills (P2 drove this to 0)",
      real["counts"]["orphan_skills"] == 0)

check("REAL: every skill lands in exactly one capability domain",
      sum(len(c["skills"]) for c in real["capabilities"].values()) == real["counts"]["skills"])
check("REAL: capability view covers the 14-value domain vocabulary",
      real["counts"]["domains"] == 14)
check("REAL: P2 invariant — every skill has produces + domain + status",
      real["coverage"]["skills_with_produces"] == real["counts"]["skills"]
      and real["coverage"]["skills_with_domain"] == real["counts"]["skills"]
      and real["coverage"]["skills_with_status"] == real["counts"]["skills"])

check("REAL: every produced artifact has at least one producer",
      all(len(v["skills"]) + len(v["agents"]) >= 1 for v in real["artifacts"].values()))
check("REAL: stack-neutral artifacts keep their multiple producers",
      real["artifacts"].get("dockerfile", {}).get("skills") ==
      ["go-dockerfile", "python-dockerfile", "react-dockerfile"])
check("REAL: every artifact index value is kind-tagged with both keys",
      all(set(v.keys()) == {"agents", "skills"} for v in real["artifacts"].values()))
check("REAL: every agent_produces edge resolves to a real agent",
      all(e["agent"] in _real_agent_names for e in real["edges"]["agent_produces"]))
check("REAL: every agent_produces edge is reflected in the artifact index",
      all(e["agent"] in real["artifacts"][e["artifact"]]["agents"]
          for e in real["edges"]["agent_produces"]))
# P5 child 1 enriched product-strategist; the remaining 12 agents follow. Once
# P5 closes, these become 13/13 — until then the invariant is 'the enriched ones
# actually reach the catalog', which is what this child fixes.
_ps = next((a for a in real["components"]["agents"] if a["name"] == "product-strategist"), {})
check("REAL: product-strategist's authored manifest fields reach the catalog",
      _ps.get("domain") == "strategy" and _ps.get("status") == "stable"
      and len(_ps.get("produces") or []) == 11)
check("REAL: product-strategist appears as a producing agent in the artifact index",
      all("product-strategist" in real["artifacts"][art]["agents"]
          for art in (_ps.get("produces") or [])))
check("REAL: coverage reports the agent manifest-field roll-out",
      real["coverage"]["agents_with_produces"] >= 1
      and real["coverage"]["agents_with_produces"] == real["coverage"]["agents_with_domain"]
      == real["coverage"]["agents_with_status"])

check("REAL: two consecutive real builds are byte-identical",
      b.render(real) == b.render(b.build_from_repo()))

# --- CLI ---------------------------------------------------------------------
proc = subprocess.run([sys.executable, str(MODULE_PATH), "--stdout"],
                      capture_output=True, text=True, cwd=str(REPO_ROOT))
check("CLI --stdout exits 0 and emits parseable JSON",
      proc.returncode == 0 and json.loads(proc.stdout)["counts"]["skills"] == len(real_skills))
check("CLI --stdout output matches build_from_repo()",
      proc.stdout == b.render(real))

_dirty_before = subprocess.run(["git", "status", "--porcelain"], capture_output=True,
                               text=True, cwd=str(REPO_ROOT)).stdout
subprocess.run([sys.executable, str(MODULE_PATH), "--stdout"],
               capture_output=True, text=True, cwd=str(REPO_ROOT))
_dirty_after = subprocess.run(["git", "status", "--porcelain"], capture_output=True,
                              text=True, cwd=str(REPO_ROOT)).stdout
check("CLI --stdout writes nothing (working tree unchanged)", _dirty_before == _dirty_after)

if CATALOG_PATH.is_file():
    chk = subprocess.run([sys.executable, str(MODULE_PATH), "--check"],
                         capture_output=True, text=True, cwd=str(REPO_ROOT))
    check("CLI --check exits 0 when the committed catalog is current",
          chk.returncode == 0)
    _after_check = subprocess.run(["git", "status", "--porcelain"], capture_output=True,
                                  text=True, cwd=str(REPO_ROOT)).stdout
    check("CLI --check writes nothing (working tree unchanged)",
          _dirty_after == _after_check)

# --- summary -----------------------------------------------------------------
print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
