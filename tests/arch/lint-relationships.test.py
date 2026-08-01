#!/usr/bin/env python3
"""
tests/arch/lint-relationships.test.py — contract test for
scripts/lint-relationships.py (P1.7, closes #788).

Two kinds of assertions:

  1. SYNTHETIC records exercise the detectors precisely, independent of the live
     tree — a deliberately broken 'related:' target must be flagged, a
     bidirectional 'related:' pair (A related-> B, B related-> A) must NOT be
     reported as a cycle (that DAG check was removed — 'related:' is inherently
     bidirectional, so acyclicity is not a real requirement for it), and an
     orphan-only dataset must NOT raise a hard failure (orphans are warnings).

  2. REAL-REPO hard checks that are genuinely green today are asserted green: the
     agent-skills contract (every agent 'skills:' entry resolves to a real skill,
     and every agent carries the two mandatory cross-cutting skills). The broken
     'related:' targets the linter finds on the real repo are KNOWN, pre-existing
     findings that P2/P4/P5 will resolve — the test asserts the linter *reports*
     them (non-crashing, deterministic, well-formed) without pretending the tree
     is already clean.

Prints PASS/FAIL lines; exits 0 iff every check passed. Standalone-runnable:
    python3 tests/arch/lint-relationships.test.py
"""

import importlib.util
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lint-relationships.py"


def _load_linter():
    """Import scripts/lint-relationships.py under a private name. The module
    itself injects scripts/arch onto sys.path so `import manifest` resolves."""
    spec = importlib.util.spec_from_file_location("_lint_relationships_under_test", MODULE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: lint-relationships ({name})")
        passed += 1
    else:
        print(f"FAIL: lint-relationships ({name})")
        failed.append(name)


# --- module import -----------------------------------------------------------
check("module file exists", MODULE_PATH.is_file())
L = _load_linter()


# --- helpers to build synthetic records --------------------------------------
def skill(name, related=None, domain=None):
    return {"name": name, "related": related, "domain": domain}


def agent(name, skills):
    return {"name": name, "skills": skills}


# ===========================================================================
# 1. SYNTHETIC detectors
# ===========================================================================

# (a) broken 'related:' target -----------------------------------------------
synth_skills_broken = [
    skill("alpha", related=["beta", "ghost-skill"], domain="design"),
    skill("beta", related=[], domain="design"),
]
res_broken = L.run_checks(synth_skills_broken, agents=[])
check(
    "synthetic broken 'related:' target is detected",
    res_broken["broken_skill_related"] == [{"skill": "alpha", "target": "ghost-skill"}],
)
check(
    "a real 'related:' target ('beta') is NOT flagged",
    all(f["target"] != "beta" for f in res_broken["broken_skill_related"]),
)
check("broken 'related:' target is a hard failure", res_broken["hard_failure"] is True)

# 'related:' cycle detection was intentionally REMOVED ------------------------
# `related:` is a bidirectional see-also link, so a normal A<->B pair is
# inherently "cyclic" and MUST NOT be reported as a defect (the old DAG check
# raised 267 such false positives with no real defect behind any of them).
# Acyclicity is a real requirement only on the artifact-dependency graph
# (P2 produces: + P7 depends_on), which this linter does not build. So a
# bidirectional related: pair must produce NO cycle finding and NO hard failure.
synth_related_pair = [
    skill("aaa", related=["bbb"], domain="x"),
    skill("bbb", related=["aaa"], domain="x"),  # legitimate bidirectional see-also
]
res_pair = L.run_checks(synth_related_pair, agents=[])
check(
    "a bidirectional related: pair (A<->B) is NOT reported as a cycle",
    "cycles" not in res_pair,
)
check(
    "a bidirectional related: pair with valid targets is not a hard failure",
    res_pair["hard_failure"] is False,
)

# (b) synthetic broken agent skill + missing mandatory ------------------------
synth_skills_for_agents = [
    skill("real-skill-one", domain="d"),
    skill("glossary-management", domain="cross-cutting"),
    skill("methodology-review", domain="cross-cutting"),
]
synth_agents_bad = [
    agent("bad-agent", ["real-skill-one", "not-a-skill"]),  # broken ref + missing both mandatory
]
res_agent = L.run_checks(synth_skills_for_agents, synth_agents_bad)
check(
    "synthetic broken agent 'skills:' target is detected",
    res_agent["broken_agent_skills"] == [{"agent": "bad-agent", "target": "not-a-skill"}],
)
check(
    "agent missing BOTH mandatory cross-cutting skills is flagged twice",
    sorted(f["missing"] for f in res_agent["agent_missing_mandatory"])
    == ["glossary-management", "methodology-review"],
)
check("broken agent skill / missing mandatory is a hard failure", res_agent["hard_failure"] is True)

synth_agents_good = [
    agent("good-agent", ["real-skill-one", "glossary-management", "methodology-review"]),
]
res_agent_good = L.run_checks(synth_skills_for_agents, synth_agents_good)
check(
    "a well-formed agent produces no agent-skills findings",
    not res_agent_good["broken_agent_skills"] and not res_agent_good["agent_missing_mandatory"],
)

# (d) orphan is a WARNING, never a hard failure -------------------------------
synth_orphan = [
    skill("used-skill", domain=None),          # used by the agent -> not orphan
    skill("domained-skill", domain="design"),  # has domain -> not orphan even if unused
    skill("true-orphan", domain=None),         # unused + no domain -> orphan
    skill("glossary-management", domain="c"),  # present so the agent stays clean
    skill("methodology-review", domain="c"),
]
# The agent is otherwise well-formed (real skills + both mandatory) so the ONLY
# thing under test here is orphan classification, not agent-skills failures.
synth_orphan_agents = [
    agent("some-agent", ["used-skill", "glossary-management", "methodology-review"]),
]
res_orphan = L.run_checks(synth_orphan, synth_orphan_agents)
check("orphan skill (no agent + no domain) is reported", res_orphan["orphans"] == ["true-orphan"])
check("a skill with a domain is not an orphan", "domained-skill" not in res_orphan["orphans"])
check("a skill used by an agent is not an orphan", "used-skill" not in res_orphan["orphans"])
check("orphans alone do NOT cause a hard failure (exit 0)", res_orphan["hard_failure"] is False)

# fully clean synthetic set ---------------------------------------------------
clean = [
    skill("s-one", related=["s-two"], domain="d"),
    skill("s-two", related=[], domain="d"),
    skill("glossary-management", domain="c"),
    skill("methodology-review", domain="c"),
]
clean_agents = [agent("a-one", ["s-one", "glossary-management", "methodology-review"])]
res_clean = L.run_checks(clean, clean_agents)
check("a fully clean synthetic set has no hard failure", res_clean["hard_failure"] is False)


# ===========================================================================
# 2. REAL-REPO hard checks that are green today
# ===========================================================================
real_skills = L.manifest.load_skills()
real_agents = L.manifest.load_agents()
real = L.run_checks(real_skills, real_agents)

check(f"real repo has 186 skills (got {len(real_skills)})", len(real_skills) == 186)
check(f"real repo has 13 agents (got {len(real_agents)})", len(real_agents) == 13)

# The agent-skills contract IS clean on the real tree — assert it stays so.
check(
    "REAL: every agent 'skills:' entry resolves to a real skill (0 broken)",
    real["broken_agent_skills"] == [],
)
check(
    "REAL: every agent carries glossary-management + methodology-review (0 missing)",
    real["agent_missing_mandatory"] == [],
)

# P2 (Skill Manifest Enrichment) drove the real tree clean: broken 'related:'
# refs 11 -> 0, and orphan skills 48 -> 0 (every skill now authors domain:).
# The real-tree assertions therefore pin the post-P2 invariant — a clean tree is
# NOT a hard failure. The linter's ability to DETECT breakage is unaffected and
# stays covered by the synthetic-fixture checks above, which are untouched.
check(
    "REAL: broken 'related:' findings are well-formed {skill,target} records",
    all(set(f.keys()) == {"skill", "target"} for f in real["broken_skill_related"]),
)
check(
    "REAL: 'related:' cycle detection is removed (no 'cycles' key on the result)",
    "cycles" not in real,
)
check(
    "REAL: P2 complete — 0 broken 'related:' refs, so the run is not a hard failure",
    real["hard_failure"] is False and len(real["broken_skill_related"]) == 0,
)
check(
    "REAL: P2 complete — 0 orphan skills (every skill authors a domain)",
    real["orphans"] == [],
)
check(
    "REAL: counts block agrees with the finding lists",
    real["counts"]["broken_skill_related"] == len(real["broken_skill_related"])
    and real["counts"]["orphans"] == len(real["orphans"]),
)

# --- determinism: two runs over the real tree are byte-identical -------------
real2 = L.run_checks(real_skills, real_agents)
check("REAL: run_checks is deterministic (identical result on re-run)", real == real2)

# --- CLI exit code matches hard_failure --------------------------------------
proc = subprocess.run(
    [sys.executable, str(MODULE_PATH)],
    capture_output=True, text=True, cwd=str(REPO_ROOT),
)
check(
    "CLI exit code is 0 now that the real tree is clean (post-P2)",
    proc.returncode == 0,
)
proc_json = subprocess.run(
    [sys.executable, str(MODULE_PATH), "--json"],
    capture_output=True, text=True, cwd=str(REPO_ROOT),
)
check("CLI --json emits parseable JSON", proc_json.returncode in (0, 1) and proc_json.stdout.strip().startswith("{"))

# --- purity: the linter never writes to the working tree ---------------------
try:
    before = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout
    L.run_checks(L.manifest.load_skills(), L.manifest.load_agents())
    after = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout
    check("linter is a pure read (git status unchanged)", before == after)
except Exception as exc:  # pragma: no cover - git absent
    print(f"PASS: lint-relationships (purity check skipped — git unavailable: {exc})")


# --- summary -----------------------------------------------------------------
print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
