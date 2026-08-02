#!/usr/bin/env python3
"""
scripts/arch/build-catalog.py — the P3 derived component catalog generator
(closes #1184, part of P3 Derived Component Catalog + CI Integration #1183).

WHAT IT DOES:
  Derives generated/catalog.json wholly from component frontmatter, via the
  shared parser scripts/arch/manifest.py. It NEVER re-parses frontmatter itself
  and NEVER authors anything: every value in the catalog is either an authored
  manifest field or a fact derived from one (or from the filesystem, by
  manifest.py). Per ARCHITECTURE-REVIEW-CAMPAIGN.md's locked decision #3 —
  "manifests = enriched frontmatter (source of truth) + a derived catalog; no
  parallel manifest files; author only non-derivable fields, derive everything
  else."

WHAT IT EMITS:
  components   skills / agents / commands / hooks, each carrying its authored
               manifest plus manifest.py's derived filesystem facts.
  edges        agent_skills   (agent  -> skill,    from an agent's skills:)
               agent_produces (agent  -> artifact, from an agent's produces:)
               skill_related  (skill  -> skill,    from a skill's related:)
               skill_produces (skill  -> artifact, from a skill's produces:)
  artifacts    the REVERSE index artifact -> {"agents": [...], "skills": [...]}.
               This is the seed of the artifact-dependency graph that P7 extends
               with workflow depends_on. Multiple producers are legitimate and
               are preserved verbatim: 'dockerfile' is produced by go-dockerfile,
               python-dockerfile AND react-dockerfile — one artifact kind, three
               stacks. Producers are KIND-TAGGED rather than pooled into one
               flat list: a skill is APPLIED and an agent is INVOKED, so a
               consumer resolving 'who produces X' must know which it got, and
               a single name can legitimately exist as both a skill and an
               artifact (user-persona). Both keys always appear; the one with no
               producers of that kind is an empty list.
  capabilities the DERIVED VIEW over domain: (charter decision #2 — "capability
               is a derived view over the relationship graph, never a
               hand-authored tier"). Per domain: its skills, the agents whose
               own domain: matches, the owners of those skills, and every
               artifact either kind produces.
  coverage     test/reference/asset/script coverage counts.
  counts       component and edge totals.

  'related:' is a bidirectional-by-convention see-also and is deliberately NOT
  cycle-checked here — per the charter, cycle/DAG validation belongs to the
  artifact-dependency graph (produces + workflow depends_on), not to related:.

DETERMINISM (a hard requirement, not a nicety):
  The catalog is a COMMITTED derived artifact, so its bytes must be stable
  across runs on the same tree. Every list is sorted, every mapping is emitted
  key-sorted, and the output carries NO timestamp and NO generator-version
  field. A generated_at stamp would make every regeneration a spurious diff and
  would defeat the staleness check that gates the catalog in CI. This also
  honours the charter's "never version-pin".

DESIGN (per ARCHITECTURE-REVIEW-CAMPAIGN.md §3): build_catalog() is PURE — it
takes already-loaded component lists and returns a dict, so the bundled test can
drive it with synthetic components. Only main() touches the filesystem.

Standalone:
    python3 scripts/arch/build-catalog.py            # write generated/catalog.json
    python3 scripts/arch/build-catalog.py --stdout   # print, write nothing
    python3 scripts/arch/build-catalog.py --check     # exit 1 if committed copy is stale
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import manifest  # noqa: E402  (scripts/arch/manifest.py — the shared parser)

REPO_ROOT = manifest.REPO_ROOT
CATALOG_PATH = REPO_ROOT / "generated" / "catalog.json"


# ---------------------------------------------------------------------------
# Normalization helpers (pure)
# ---------------------------------------------------------------------------

def _as_list(value) -> list[str]:
    """Normalize an authored scalar-or-list field to a sorted list of strings.

    'produces' is authored as either a single artifact name or a list of them
    (schemas/skill.schema.json permits both); manifest.py already normalizes it
    to a list, but this keeps build_catalog() total for synthetic inputs too.
    """
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    return [str(v) for v in value]


def _skill_entry(s: dict) -> dict:
    """One catalog record for a skill: authored manifest + derived facts."""
    return {
        "name": s.get("name"),
        "version": s.get("version"),
        "phase": s.get("phase"),
        "owner": s.get("owner"),
        "domain": s.get("domain"),
        "status": s.get("status"),
        "produces": sorted(_as_list(s.get("produces"))),
        "related": sorted(_as_list(s.get("related"))),
        "tags": sorted(_as_list(s.get("tags"))),
        "created": str(s.get("created")) if s.get("created") is not None else None,
        "has_references": bool(s.get("has_references")),
        "has_assets": bool(s.get("has_assets")),
        "has_scripts": bool(s.get("has_scripts")),
        "has_contract_test": bool(s.get("has_contract_test")),
        "dir": s.get("dir"),
    }


def _agent_entry(a: dict) -> dict:
    return {
        "name": a.get("name"),
        "version": a.get("version"),
        "phase": a.get("phase"),
        "role": a.get("role"),
        "domain": a.get("domain"),
        "status": a.get("status"),
        "produces": sorted(_as_list(a.get("produces"))),
        "skills": sorted(_as_list(a.get("skills"))),
        "tools": sorted(_as_list(a.get("tools"))),
        "tags": sorted(_as_list(a.get("tags"))),
        "created": str(a.get("created")) if a.get("created") is not None else None,
        "has_acceptance_test": bool(a.get("has_acceptance_test")),
        "file": a.get("file"),
    }


def _command_entry(c: dict) -> dict:
    return {
        "name": c.get("name"),
        "description": c.get("description"),
        "argument_hint": c.get("argument_hint"),
        "allowed_tools": sorted(_as_list(c.get("allowed_tools"))),
        "model": c.get("model"),
        "disable_model_invocation": bool(c.get("disable_model_invocation")),
        "has_test": bool(c.get("has_test")),
        "file": c.get("file"),
    }


def _hook_entry(h: dict) -> dict:
    return {
        "event": h.get("event"),
        "matcher": h.get("matcher"),
        "type": h.get("type"),
        "script": h.get("script"),
        "timeout": h.get("timeout"),
        "order": h.get("order"),
    }


# ---------------------------------------------------------------------------
# The catalog builder (PURE — no filesystem access)
# ---------------------------------------------------------------------------

def build_catalog(skills: list[dict], agents: list[dict],
                  commands: list[dict], hooks: list[dict]) -> dict:
    """Derive the whole catalog from already-loaded component records.

    Pure: same inputs -> byte-identical output. No clock, no randomness, no
    filesystem access, no mutation of the inputs.
    """
    skill_entries = sorted((_skill_entry(s) for s in skills), key=lambda r: r["name"] or "")
    agent_entries = sorted((_agent_entry(a) for a in agents), key=lambda r: r["name"] or "")
    command_entries = sorted((_command_entry(c) for c in commands), key=lambda r: r["name"] or "")
    hook_entries = sorted(
        (_hook_entry(h) for h in hooks),
        key=lambda r: (r["event"] or "", r["matcher"] or "", r["script"] or "", r["order"] or 0),
    )

    skill_names = {r["name"] for r in skill_entries}

    # --- edges -------------------------------------------------------------
    agent_skills = sorted(
        ({"agent": a["name"], "skill": sk} for a in agent_entries for sk in a["skills"]),
        key=lambda e: (e["agent"], e["skill"]),
    )
    skill_related = sorted(
        ({"skill": s["name"], "related": r} for s in skill_entries for r in s["related"]),
        key=lambda e: (e["skill"], e["related"]),
    )
    skill_produces = sorted(
        ({"skill": s["name"], "artifact": p} for s in skill_entries for p in s["produces"]),
        key=lambda e: (e["skill"], e["artifact"]),
    )
    agent_produces = sorted(
        ({"agent": a["name"], "artifact": p} for a in agent_entries for p in a["produces"]),
        key=lambda e: (e["agent"], e["artifact"]),
    )

    # --- artifact reverse index (seed of the artifact-dependency graph) -----
    # Each value is {"agents": [...], "skills": [...]} — a KIND-TAGGED index,
    # not a flat list of producer names. A flat list would be ambiguous the
    # moment agents joined it: an artifact's producers must be resolvable to a
    # component kind, because a skill is APPLIED and an agent is INVOKED, and
    # several names collide across kinds by design (the skill `user-persona`
    # and the artifact `user-persona` the product-strategist agent produces).
    # Both keys are always present (empty list when that kind produces nothing)
    # so consumers never branch on key existence.
    artifacts: dict[str, dict[str, list[str]]] = {}

    def _producer(artifact: str) -> dict:
        return artifacts.setdefault(artifact, {"agents": [], "skills": []})

    for edge in skill_produces:
        _producer(edge["artifact"])["skills"].append(edge["skill"])
    for edge in agent_produces:
        _producer(edge["artifact"])["agents"].append(edge["agent"])
    artifacts = {
        name: {"agents": sorted(set(v["agents"])), "skills": sorted(set(v["skills"]))}
        for name, v in sorted(artifacts.items())
    }

    # --- capability view (derived from domain:, never hand-authored) -------
    capabilities: dict[str, dict] = {}

    def _capability(dom: str) -> dict:
        return capabilities.setdefault(
            dom, {"skills": [], "agents": [], "owners": [], "artifacts": []}
        )

    for s in skill_entries:
        dom = s["domain"]
        if not dom:
            continue
        cap = _capability(dom)
        cap["skills"].append(s["name"])
        if s["owner"]:
            cap["owners"].append(s["owner"])
        cap["artifacts"].extend(s["produces"])
    # Agents roll up by their own domain:. 'owners' stays skills-only — it is the
    # roll-up of skill owner: values (which name agents), not the agent files'
    # own owner: (which names the human operator).
    for a in agent_entries:
        dom = a["domain"]
        if not dom:
            continue
        cap = _capability(dom)
        cap["agents"].append(a["name"])
        cap["artifacts"].extend(a["produces"])
    capabilities = {
        dom: {
            "skills": sorted(set(v["skills"])),
            "agents": sorted(set(v["agents"])),
            "owners": sorted(set(v["owners"])),
            "artifacts": sorted(set(v["artifacts"])),
            "skill_count": len(set(v["skills"])),
            "agent_count": len(set(v["agents"])),
        }
        for dom, v in sorted(capabilities.items())
    }

    # --- coverage ----------------------------------------------------------
    coverage = {
        "skills_with_contract_test": sum(1 for s in skill_entries if s["has_contract_test"]),
        "skills_with_references": sum(1 for s in skill_entries if s["has_references"]),
        "skills_with_assets": sum(1 for s in skill_entries if s["has_assets"]),
        "skills_with_scripts": sum(1 for s in skill_entries if s["has_scripts"]),
        "skills_with_produces": sum(1 for s in skill_entries if s["produces"]),
        "skills_with_domain": sum(1 for s in skill_entries if s["domain"]),
        "skills_with_status": sum(1 for s in skill_entries if s["status"]),
        "agents_with_acceptance_test": sum(1 for a in agent_entries if a["has_acceptance_test"]),
        "agents_with_produces": sum(1 for a in agent_entries if a["produces"]),
        "agents_with_domain": sum(1 for a in agent_entries if a["domain"]),
        "agents_with_status": sum(1 for a in agent_entries if a["status"]),
        "commands_with_test": sum(1 for c in command_entries if c["has_test"]),
    }

    counts = {
        "skills": len(skill_entries),
        "agents": len(agent_entries),
        "commands": len(command_entries),
        "hooks": len(hook_entries),
        "artifacts": len(artifacts),
        "domains": len(capabilities),
        "edges_agent_skills": len(agent_skills),
        "edges_agent_produces": len(agent_produces),
        "edges_skill_related": len(skill_related),
        "edges_skill_produces": len(skill_produces),
        "orphan_skills": sum(
            1 for s in skill_entries
            if not s["domain"] and s["name"] not in {e["skill"] for e in agent_skills}
        ),
        "unresolved_skill_related": sum(
            1 for e in skill_related if e["related"] not in skill_names
        ),
    }

    return {
        "artifacts": artifacts,
        "capabilities": capabilities,
        "components": {
            "agents": agent_entries,
            "commands": command_entries,
            "hooks": hook_entries,
            "skills": skill_entries,
        },
        "counts": counts,
        "coverage": coverage,
        "edges": {
            "agent_produces": agent_produces,
            "agent_skills": agent_skills,
            "skill_produces": skill_produces,
            "skill_related": skill_related,
        },
    }


def render(catalog: dict) -> str:
    """Serialize the catalog to its canonical, byte-stable JSON form."""
    return json.dumps(catalog, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def build_from_repo() -> dict:
    """Load the real component tree and build the catalog from it."""
    return build_catalog(
        manifest.load_skills(),
        manifest.load_agents(),
        manifest.load_commands(),
        manifest.load_hooks(),
    )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    to_stdout = "--stdout" in argv
    check_only = "--check" in argv

    rendered = render(build_from_repo())

    if to_stdout:
        sys.stdout.write(rendered)
        return 0

    if check_only:
        if not CATALOG_PATH.exists():
            print(f"STALE: {CATALOG_PATH.relative_to(REPO_ROOT)} does not exist.")
            print("       Run: python3 scripts/arch/build-catalog.py")
            return 1
        committed = CATALOG_PATH.read_text(encoding="utf-8")
        if committed != rendered:
            print(f"STALE: {CATALOG_PATH.relative_to(REPO_ROOT)} does not match the component tree.")
            print("       A component's frontmatter changed without the catalog being rebuilt.")
            print("       Run: python3 scripts/arch/build-catalog.py")
            return 1
        print(f"catalog is current ({CATALOG_PATH.relative_to(REPO_ROOT)}).")
        return 0

    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(rendered, encoding="utf-8")
    catalog = json.loads(rendered)
    c = catalog["counts"]
    print(f"catalog written -> {CATALOG_PATH.relative_to(REPO_ROOT)}")
    print(f"  components: {c['skills']} skills, {c['agents']} agents, "
          f"{c['commands']} commands, {c['hooks']} hook handlers")
    print(f"  derived:    {c['artifacts']} artifacts, {c['domains']} capability domains")
    print(f"  edges:      {c['edges_agent_skills']} agent->skill, "
          f"{c['edges_agent_produces']} agent->artifact, "
          f"{c['edges_skill_produces']} skill->artifact, "
          f"{c['edges_skill_related']} skill->related")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
