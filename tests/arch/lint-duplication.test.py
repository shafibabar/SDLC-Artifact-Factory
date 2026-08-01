#!/usr/bin/env python3
"""
tests/arch/lint-duplication.test.py — contract test for scripts/lint-duplication.py
(P1.8, closes #789).

The linter's detection functions are PURE (they take a {skill_name: corpus} dict
plus a parsed-standards dict), so this test drives them with SYNTHETIC skills —
no dependence on the live tree for the behavioural assertions. It asserts:

  (a) find_duplicate_blocks flags a set of synthetic skills that share an
      identical multi-line block, names every sharing skill in the cluster, and
      does NOT drag in an unrelated control skill; the >= 3-skill production
      threshold holds (a 2-skill block is NOT flagged by default) while the
      min_skills param still lets a synthetic PAIR be detected; near-identical
      (one-word-different) blocks still cluster via shared shingles.

  (b) load_claude_standards parses the four standards out of a CLAUDE.md snippet
      (naming regex, exactly the five methodologies with NO stray "defect",
      frugality phrases, glossary terms), and find_restatements flags a
      synthetic skill line that restates a standard (the naming regex; the
      frugality phrase) while (i) never flagging the standard's legitimate home
      skill and (ii) leaving a clean skill alone.

  (c) main() runs against the real repo, exits 0 (report-only), and writes the
      report to generated/duplication-report.md.

Prints PASS/FAIL lines; exits 0 iff every check passed. Standalone:
    python3 tests/arch/lint-duplication.test.py
"""

import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lint-duplication.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("_lint_dup_under_test", MODULE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: lint-duplication ({name})")
        passed += 1
    else:
        print(f"FAIL: lint-duplication ({name})")
        failed.append(name)


check("module file exists", MODULE_PATH.is_file())
d = _load_module()

# ---------------------------------------------------------------------------
# (a) duplicate-block detection on synthetic skills
# ---------------------------------------------------------------------------

SHARED = (
    "The bounded context owns its data exclusively.\n"
    "Cross-context reads go through a published contract.\n"
    "Writes are validated at the aggregate root only.\n"
    "Events are emitted through the transactional outbox pattern.\n"
    "Downstream consumers subscribe idempotently to those events."
)

corpus = {
    "skill-alpha": "Intro paragraph unique to alpha.\n\n" + SHARED + "\n\nAlpha tail.",
    "skill-beta": "Beta preamble that differs entirely.\n\n" + SHARED + "\n\nBeta tail here.",
    # near-identical: one word changed ("exclusively" -> "completely").
    "skill-gamma": SHARED.replace("exclusively", "completely") + "\n\nGamma unique closing line.",
    # control skill: NO shared block at all.
    "skill-control": (
        "This skill is about picking a colour palette for dashboards.\n"
        "It discusses contrast ratios and accessible legends at length.\n"
        "Nothing here overlaps with domain modelling guidance whatsoever.\n"
        "Sequential and diverging scales are chosen by data type."
    ),
}

clusters = d.find_duplicate_blocks(corpus)  # default min_skills = 3
check("a duplicated block is found across >= 3 synthetic skills", len(clusters) >= 1)

top = clusters[0] if clusters else {"skills": [], "text": ""}
check(
    "cluster names all three skills that share the block",
    set(top["skills"]) >= {"skill-alpha", "skill-beta", "skill-gamma"},
)
check(
    "control skill (no shared block) is NOT in the cluster",
    "skill-control" not in top["skills"],
)
check(
    "cluster block text carries the shared lines (multi-line)",
    "transactional outbox pattern" in top["text"].lower() and top["num_lines"] >= 3,
)

# The >= 3 production threshold: a block in only TWO skills is not flagged...
pair_only = {
    "skill-one": SHARED + "\n\none unique.",
    "skill-two": SHARED + "\n\ntwo unique.",
    "skill-lonely": "Totally unrelated content about kubernetes probes and readiness.",
}
check(
    "a block shared by only 2 skills is NOT flagged at the default threshold",
    d.find_duplicate_blocks(pair_only) == [],
)
# ...but the min_skills param lets a synthetic PAIR be detected explicitly.
pair_clusters = d.find_duplicate_blocks(pair_only, min_skills=2)
check(
    "min_skills=2 detects the synthetic pair sharing an identical block",
    any(set(c["skills"]) == {"skill-one", "skill-two"} for c in pair_clusters),
)

# ---------------------------------------------------------------------------
# (b) CLAUDE.md-standard parsing + restatement detection
# ---------------------------------------------------------------------------

CLAUDE_SNIPPET = """
# CLAUDE.md

## Non-Negotiable Methodology

These five methodologies are mandatory. Their absence is a **defect**.

| Methodology | Where It Applies |
|---|---|
| **Domain-Driven Design** | Design, Implement |
| **Event Storming** | Design |
| **Test-Driven Development** | Implement |
| **Behavior-Driven Development** | Implement, Quality |
| **SOLID** | Implement |

## Naming Conventions

All component names must match: `^[a-z0-9]+(-[a-z0-9]+)*$`

## Ubiquitous Language

`Bounded Context` · `Ubiquitous Language` · `Domain Event` · `Aggregate`

## Budget and Frugality

- Open-source over paid tooling at every decision point.
"""

std = d.load_claude_standards(CLAUDE_SNIPPET)
check("naming regex parsed out of CLAUDE.md", std["naming_regex"] == r"^[a-z0-9]+(-[a-z0-9]+)*$")
check(
    "exactly the five methodologies parsed (no stray 'defect')",
    std["methodologies"] == [
        "domain-driven design", "event storming", "test-driven development",
        "behavior-driven development", "solid",
    ],
)
check("'defect' is not miscounted as a methodology", "defect" not in std["methodologies"])
check("frugality phrases present", "open-source over paid" in std["frugality_phrases"])
check("glossary terms parsed", "bounded context" in std["ubiquitous_terms"])

# A synthetic skill LINE that restates the naming-convention regex is flagged.
restate_corpus = {
    "some-random-skill": (
        "This skill validates identifiers.\n"
        "Every name must match `^[a-z0-9]+(-[a-z0-9]+)*$` exactly.\n"
        "Reject anything else."
    ),
}
r1 = d.find_restatements(restate_corpus, std)
check("naming-regex restatement in a synthetic skill line is flagged", len(r1) == 1)
check(
    "flagged finding identifies the naming-convention standard + repoint home",
    bool(r1) and r1[0]["skill"] == "some-random-skill"
    and "naming" in r1[0]["standard"].lower()
    and "CLAUDE.md" in r1[0]["repoint_to"],
)

# A synthetic skill line that restates the frugality rule is flagged.
frug_corpus = {"my-skill": "We always choose open-source over paid tooling here."}
rf = d.find_restatements(frug_corpus, std)
check(
    "frugality restatement in a synthetic skill line is flagged",
    len(rf) == 1 and "frugal" in rf[0]["standard"].lower(),
)

# The legitimate HOME skill for a standard is never flagged for restating it.
home_corpus = {"skill-authoring-standards": restate_corpus["some-random-skill"]}
check(
    "the naming standard's home skill is NOT flagged",
    d.find_restatements(home_corpus, std) == [],
)

# A clean skill (uses no standard) produces no restatement finding.
clean_corpus = {"clean-skill": "This skill explains how to write a helpful tooltip label."}
check("a clean skill yields no restatement finding", d.find_restatements(clean_corpus, std) == [])

# ---------------------------------------------------------------------------
# (c) main() runs against the real repo, report-only (exit 0), writes report
# ---------------------------------------------------------------------------

rc = d.main()
check("main() exits 0 (report-only, never fails the build)", rc == 0)
check(
    "main() wrote generated/duplication-report.md",
    (REPO_ROOT / "generated" / "duplication-report.md").is_file(),
)

# --- summary -----------------------------------------------------------------
print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
