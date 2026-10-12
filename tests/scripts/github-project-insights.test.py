#!/usr/bin/env python3
"""Tests scripts/github-project/ghp/insights.py — the Insights-field derivation
rules (#1266). Pure functions, so every case is a synthetic fixture: no gh call.
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts/github-project"))
from ghp import insights  # noqa: E402

passed, failed = 0, []


def check(name, got, want):
    global passed
    if got == want:
        print(f"PASS: github-project-insights ({name})")
        passed += 1
    else:
        print(f"FAIL: github-project-insights ({name}): got {got!r}, want {want!r}")
        failed.append(name)


def issue(n, title="Do a thing", labels=(), parent=None, children=0, created="2026-07-25T10:00:00Z",
          closed="2026-07-25T10:30:00Z", blocked_by=0, blocking=0):
    return {"item_id": f"I{n}", "kind": "ISSUE", "number": n, "title": title, "labels": list(labels),
            "created": created, "closed": closed, "parent": parent, "children": children, "head": "",
            "base": "", "lines": 0, "files": 0, "closes": [], "blocked_by": blocked_by, "blocking": blocking}


def pr(n, head, base="main", lines=10, files=1, closes=(), title="PR", labels=(),
       created="2026-07-25T10:00:00Z", closed="2026-07-25T10:20:00Z"):
    return {"item_id": f"P{n}", "kind": "PR", "number": n, "title": title, "labels": list(labels),
            "created": created, "closed": closed, "parent": None, "children": 0, "head": head, "base": base,
            "lines": lines, "files": files, "closes": list(closes), "blocked_by": 0, "blocking": 0}


# A Fresh-Eyes parent with one discovery sub-issue and one skill sub-issue, its
# sub-issue PRs into the integration branch, and the integration PR to main.
board = [
    issue(100, "Fresh-Eyes Phase C", labels=["skill"], children=2, created="2026-10-11T09:00:00Z",
          closed="2026-10-14T09:00:00Z", blocking=0),
    issue(101, "Discovery: research", labels=["discovery"], parent=100, created="2026-10-11T09:05:00Z",
          closed="2026-10-11T09:40:00Z", blocking=1),
    issue(102, "Write references", labels=["skill"], parent=100, created="2026-10-11T09:06:00Z",
          closed="2026-10-12T12:00:00Z", blocked_by=1),
    pr(201, "issue-101-discovery-research", base="issue-100-phase-c", lines=300, files=2),
    pr(202, "issue-102-write-references", base="issue-100-phase-c", lines=1900, files=20),
    pr(203, "issue-100-phase-c", base="main", lines=2200, files=22),
    issue(300, "[P2] enrich go-unit-test — produces/domain/status", labels=["enhancement"],
          created="2026-08-01T10:00:00Z", closed="2026-08-01T10:10:00Z"),
    pr(301, "arch-review/p2-go-unit-test", base="arch-review/p2-skill-manifest-enrichment", lines=3),
    issue(400, "[dogfood] Phase gate never fires for installed users", labels=["bug", "discovery"],
          created="2026-10-12T10:00:00Z", closed=None),
    issue(401, "[dogfood] Typo in wording of the README", labels=["bug"],
          created="2026-10-12T10:00:00Z", closed="2026-10-12T11:00:00Z"),
    pr(500, "feature/8-data-architecture-skills", lines=5000, files=40,
       created="2026-06-26T10:00:00Z", closed="2026-06-27T10:00:00Z"),
]
out = insights.derive_all(board)

# Hierarchy
check("parent", out["I100"]["Hierarchy"], "Parent")
check("sub-issue", out["I101"]["Hierarchy"], "Sub-issue")
check("standalone", out["I300"]["Hierarchy"], "Standalone")
check("sub-issue PR", out["P201"]["Hierarchy"], "Sub-issue PR")
check("integration PR", out["P203"]["Hierarchy"], "Integration PR")
check("direct PR", out["P500"]["Hierarchy"], "Direct PR")

# Branch type / merge target
check("branch issue-sub", out["P201"]["Branch-Type"], "issue-sub")
check("branch issue-integration", out["P203"]["Branch-Type"], "issue-integration")
check("branch arch", out["P301"]["Branch-Type"], "arch")
check("branch feature", out["P500"]["Branch-Type"], "feature")
check("branch n/a for issue", out["I100"]["Branch-Type"], "n/a")
check("merge integration", out["P201"]["Merge-Target"], "integration")
check("merge main", out["P203"]["Merge-Target"], "main")

# Work type: precedence + PR inherits its issue's type
check("discovery label", out["I101"]["Work-Type"], "Discovery")
check("PR inherits Discovery", out["P201"]["Work-Type"], "Discovery")
check("[P2] is Governance", out["I300"]["Work-Type"], "Governance")
check("bug beats discovery", out["I400"]["Work-Type"], "Bug")
check("feature PR is Skill", out["P500"]["Work-Type"], "Skill")

# Campaign: children and their PRs inherit the parent's
check("parent Fresh-Eyes", out["I100"]["Campaign"], "Fresh-Eyes")
check("sub-issue inherits", out["I102"]["Campaign"], "Fresh-Eyes")
check("sub-issue PR inherits", out["P202"]["Campaign"], "Fresh-Eyes")
check("arch PR linked by slug", out["P301"]["Campaign"], "Arch-Review")
check("foundation chunk", out["P500"]["Campaign"], "Foundation")

# Complexity: thresholds, >15-files bump, roll-up onto issues and parents
check("M from 300 lines", out["I101"]["Complexity"], "M")
check("L bumped to XL by files", out["P202"]["Complexity"], "XL")
check("parent rolls up children", out["I100"]["Complexity"], "XL")
check("XS from 3 lines (arch slug link)", out["I300"]["Complexity"], "XS")
check("effort points", out["I101"]["Effort-Points"], 3.0)
check("thresholds", [insights.complexity(n, 1) for n in (19, 20, 149, 150, 599, 600, 1999, 2000)],
      ["XS", "S", "S", "M", "M", "L", "L", "XL"])

# Severity / priority
check("S1 from 'never'", out["I400"]["Severity"], "S1")
check("P0 for S1 bug", out["I400"]["Priority"], "P0")
check("S4 cosmetic", out["I401"]["Severity"], "S4")
check("non-bug N/A", out["I101"]["Severity"], "N/A")
check("P1 when blocking", out["I101"]["Priority"], "P1")
check("P1 for parent", out["I100"]["Priority"], "P1")
check("P2 default", out["I300"]["Priority"], "P2")

# Duration / cycle days
check("cycle days", out["I101"]["Cycle-Days"], round(35 / 1440, 2))
check("<1h", out["I101"]["Duration"], "<1h")
check("1-3d", out["I102"]["Duration"], "1-3d")
check("open", out["I400"]["Duration"], "Open")
check("open has no cycle days", out["I400"]["Cycle-Days"], None)
check("bucket edges", [insights.duration(d) for d in (1 / 24 - 0.001, 1 / 24, 0.999, 1, 3, 7)],
      ["<1h", "<1d", "<1d", "1-3d", "3-7d", ">7d"])

# Dependencies
check("blocking", out["I101"]["Dependency"], "Blocking")
check("blocked", out["I102"]["Dependency"], "Blocked")
check("PR inherits deps", out["P202"]["Dependency"], "Blocked")
check("both", insights.dependency(1, 1), "Both")
check("blocked-by count", out["I102"]["Blocked-By"], 1.0)

# Sprint: by closed date, else created; clamped to the configured range
check("sprint by closed date", out["P500"]["Sprint"], "Sprint 2026 01")
check("sprint 9", out["I101"]["Sprint"], "Sprint 2026 08")
check("sprint clamps early", insights.sprint(issue(1, created="2026-06-20T00:00:00Z", closed=None)),
      "Sprint 2026 01")
check("data source", out["I100"]["Data-Source"], "Derived")

print(f"\n{passed} passed, {len(failed)} failed")
sys.exit(1 if failed else 0)
