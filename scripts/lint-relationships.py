#!/usr/bin/env python3
"""
scripts/lint-relationships.py — the P1.7 relationship linter for the
Architecture Review campaign (closes #788, part of P1 #780).

Consumes the NORMALIZED records returned by scripts/arch/manifest.py (never raw
yaml.safe_load — the manifest already ISO-normalizes dates and derives
filesystem facts) and validates the cross-component relationship graph:

  (a) BROKEN skill 'related:' target — every entry in a skill's `related:` list
      must name a real skill.                                 [HARD FAILURE]
  (b) BROKEN agent 'skills:' target — every entry in an agent's `skills:` list
      must name a real skill; AND every agent's `skills:` list must include the
      two mandatory cross-cutting skills glossary-management + methodology-review
      (CLAUDE.md Component Frontmatter rule).                  [HARD FAILURE]
  (c) ORPHANS — a skill named by no agent's `skills:` list AND carrying no
      `domain:` field is reported as a WARNING only (it does not fail the lint;
      it informs P4/P5 de-dup + agent-refactor work).         [WARNING]

Exit code: 1 if any HARD FAILURE is found (broken skill/agent refs); 0 otherwise
(warnings alone never fail the lint).

Note: cycle detection over `related:` was intentionally removed — see the
"Graph helpers" section below for why acyclicity is not a real requirement for
the `related:` field.

Design constraints (ARCHITECTURE-REVIEW-CAMPAIGN.md §3 — Descriptors are data,
read never run): PURE READ, stdlib only, deterministic (every list sorted).

The check core (run_checks) takes plain records so it is unit-testable with
synthetic skills/agents; main() feeds it the real repo via manifest.py.

Standalone:
    python3 scripts/lint-relationships.py           # human-readable report
    python3 scripts/lint-relationships.py --json     # machine-readable findings
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Import the shared manifest library (scripts/arch/manifest.py).
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE / "arch"))

import manifest  # noqa: E402  (path injected above)

MANDATORY_AGENT_SKILLS = ("glossary-management", "methodology-review")


# ---------------------------------------------------------------------------
# Graph helpers
# ---------------------------------------------------------------------------

# DAG/cycle validation is deferred to the artifact-dependency graph (P2 produces:
#  + P7 depends_on), where acyclicity is a real requirement. 'related:' is a
#  bidirectional cross-reference and is not a DAG.
#
# (Cycle detection over the `related:` field was removed here: because `related:`
#  is a bidirectional see-also link, a normal A<->B pair is inherently a "cycle",
#  so the check produced 267 false positives on the real tree with no real defect
#  behind any of them.)


# ---------------------------------------------------------------------------
# Individual checks (operate on plain records — unit-testable)
# ---------------------------------------------------------------------------

def check_skill_related(skills: list[dict], skill_names: set[str]) -> list[dict]:
    """(a) Broken skill `related:` targets. Returns sorted findings."""
    findings = []
    for s in skills:
        for target in sorted(set(s.get("related") or [])):
            if target not in skill_names:
                findings.append({"skill": s["name"], "target": target})
    findings.sort(key=lambda f: (f["skill"], f["target"]))
    return findings


def check_agent_skills(agents: list[dict], skill_names: set[str]) -> dict:
    """(b) Broken agent `skills:` targets + missing mandatory cross-cutting
    skills. Returns {'broken': [...], 'missing_mandatory': [...]}, both sorted."""
    broken = []
    missing = []
    for a in agents:
        agent_skills = a.get("skills") or []
        for target in sorted(set(agent_skills)):
            if target not in skill_names:
                broken.append({"agent": a["name"], "target": target})
        for mand in MANDATORY_AGENT_SKILLS:
            if mand not in agent_skills:
                missing.append({"agent": a["name"], "missing": mand})
    broken.sort(key=lambda f: (f["agent"], f["target"]))
    missing.sort(key=lambda f: (f["agent"], f["missing"]))
    return {"broken": broken, "missing_mandatory": missing}


def find_orphans(skills: list[dict], agents: list[dict]) -> list[str]:
    """(c) Skills named by no agent's `skills:` list AND carrying no `domain:`.
    WARNING-only. Returns a sorted list of skill names."""
    used = set()
    for a in agents:
        used.update(a.get("skills") or [])
    orphans = [
        s["name"]
        for s in skills
        if s["name"] not in used and not s.get("domain")
    ]
    return sorted(orphans)


def run_checks(skills: list[dict], agents: list[dict]) -> dict:
    """Run every relationship check over the given records and return a result
    dict. `hard_failure` is True iff (a) or (b-broken/missing) fired.

    Note: there is deliberately no cycle check over `related:` — see the
    "Graph helpers" section for why acyclicity is not required for that field."""
    skill_names = {s["name"] for s in skills}

    broken_related = check_skill_related(skills, skill_names)
    agent_res = check_agent_skills(agents, skill_names)
    orphans = find_orphans(skills, agents)

    hard_failure = bool(
        broken_related
        or agent_res["broken"]
        or agent_res["missing_mandatory"]
    )
    return {
        "broken_skill_related": broken_related,
        "broken_agent_skills": agent_res["broken"],
        "agent_missing_mandatory": agent_res["missing_mandatory"],
        "orphans": orphans,
        "counts": {
            "skills": len(skills),
            "agents": len(agents),
            "broken_skill_related": len(broken_related),
            "broken_agent_skills": len(agent_res["broken"]),
            "agent_missing_mandatory": len(agent_res["missing_mandatory"]),
            "orphans": len(orphans),
        },
        "hard_failure": hard_failure,
    }


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def _print_report(result: dict) -> None:
    c = result["counts"]
    print("=== lint-relationships (P1.7) ===")
    print(f"skills: {c['skills']}   agents: {c['agents']}")
    print("")

    print(f"(a) broken skill 'related:' targets: {c['broken_skill_related']}")
    for f in result["broken_skill_related"]:
        print(f"    FAIL  {f['skill']} -> related '{f['target']}' is not a real skill")

    print(f"(b) broken agent 'skills:' targets: {c['broken_agent_skills']}")
    for f in result["broken_agent_skills"]:
        print(f"    FAIL  {f['agent']} -> skills '{f['target']}' is not a real skill")
    print(f"    agents missing mandatory cross-cutting skill: {c['agent_missing_mandatory']}")
    for f in result["agent_missing_mandatory"]:
        print(f"    FAIL  {f['agent']} is missing mandatory skill '{f['missing']}'")

    print(f"(c) orphan skills (no agent + no domain) [WARNING]: {c['orphans']}")
    for name in result["orphans"]:
        print(f"    warn  {name}")

    print("")
    if result["hard_failure"]:
        print("RESULT: FAIL (hard failures present — exit 1)")
    else:
        print("RESULT: PASS (no hard failures; warnings do not fail the lint — exit 0)")


def main(argv: list[str]) -> int:
    skills = manifest.load_skills()
    agents = manifest.load_agents()
    result = run_checks(skills, agents)
    if "--json" in argv:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        _print_report(result)
    return 1 if result["hard_failure"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
