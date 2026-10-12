"""Derivation rules for the SKILL GEN Project's Insights fields (#1266).

Pure functions only -- no gh/GraphQL calls -- so every rule is unit-tested
(tests/scripts/github-project-insights.test.py). The backfill script and the
plan/exec tooling both call derive_all() / derive_one(), so a board item gets
the same values whether it was backfilled or created going forward.

Input: "facts" dicts produced by normalize() from a Project item node.
Output: {field name: value} -- option name for single-selects, float for the
number fields, iteration title for Sprint. A value of None means "leave unset".
"""

import datetime as _dt
import re

from . import config

FRESH_EYES_START = "2026-10-11"
TOOLING_START = "2026-07-22"  # first plan_start.py-tracked issue (#43)

EFFORT_POINTS = {"XS": 1, "S": 2, "M": 3, "L": 5, "XL": 8}
_COMPLEXITY = ["XS", "S", "M", "L", "XL"]

_ISSUE_HEAD = re.compile(r"^issue-(\d+)-")
_ARCH_TITLE = re.compile(r"^\[P\d")
_SKILL_TITLE = re.compile(
    r"^(\[(Refactor|New Skill|Fix|Polish|Agent Update)\]|Refactor |Rebuild |Extensive rebuild)", re.I
)
_TOOLING = re.compile(r"github-project|plan[-_ ]start|exec[-_ ]|smoke test|harness|tooling|labels", re.I)
_DOCS = re.compile(r"\b(readme|changelog|housekeeping|typo|polish|docs?)\b", re.I)
_P0 = re.compile(r"\b(gate|ci|crash|broken|never|blocks?|blocking|fails?)\b", re.I)
_S1 = re.compile(r"\b(gate|ci|crash|data loss|broken|never|blocks?|blocking)\b", re.I)
_S2 = re.compile(r"\b(wrong|incorrect|missing|fails?|not|no)\b", re.I)
_S4 = re.compile(r"\b(typo|wording|format(ting)?|cosmetic)\b", re.I)


# --- normalisation -----------------------------------------------------------

def normalize(node):
    """Flatten one ProjectV2 item node (see backfill_insights.ITEM_QUERY)."""
    c = node.get("content") or {}
    is_pr = node["type"] == "PULL_REQUEST"
    deps = c.get("issueDependenciesSummary") or {}
    return {
        "item_id": node["id"],
        "kind": "PR" if is_pr else "ISSUE",
        "number": c.get("number"),
        "title": c.get("title") or "",
        "labels": sorted(l["name"] for l in (c.get("labels") or {}).get("nodes", [])),
        "created": c.get("createdAt"),
        "closed": c.get("closedAt"),
        "parent": (c.get("parent") or {}).get("number"),
        "children": (c.get("subIssues") or {}).get("totalCount", 0),
        "head": c.get("headRefName") or "",
        "base": c.get("baseRefName") or "",
        "lines": (c.get("additions") or 0) + (c.get("deletions") or 0),
        "files": c.get("changedFiles") or 0,
        "closes": [n["number"] for n in (c.get("closingIssuesReferences") or {}).get("nodes", [])],
        "blocked_by": deps.get("totalBlockedBy", 0),
        "blocking": deps.get("totalBlocking", 0),
    }


# --- single-item rules -------------------------------------------------------

def _day(iso):
    return iso[:10] if iso else ""


_ARCH_HEAD = re.compile(r"^arch-review/p(\d+)-(.+)$")


def pr_issue(pr, issues):
    """The issue number a PR belongs to: its issue-N-* head, else what it
    closes, else (Arch Review) the [P<n>] issue whose title names the
    arch-review/p<n>-<slug> head's slug."""
    m = _ISSUE_HEAD.match(pr["head"])
    if m and int(m.group(1)) in issues:
        return int(m.group(1))
    for n in pr["closes"]:
        if n in issues:
            return n
    m = _ARCH_HEAD.match(pr["head"])
    if m:
        phase, slug = m.group(1), m.group(2)
        word = re.compile(r"(?<![a-z0-9-])" + re.escape(slug) + r"(?![a-z0-9-])")
        hits = [
            n for n, f in issues.items()
            if f["title"].startswith(f"[P{phase}") and word.search(f["title"].lower())
        ]
        if len(hits) == 1:
            return hits[0]
    return None


def hierarchy(f, issues):
    if f["kind"] == "ISSUE":
        if f["children"]:
            return "Parent"
        return "Sub-issue" if f["parent"] else "Standalone"
    if f["base"] != "main":
        return "Sub-issue PR"
    n = pr_issue(f, issues)
    if n and issues[n]["children"] and _ISSUE_HEAD.match(f["head"]):
        return "Integration PR"
    return "Direct PR"


def branch_type(f, issues):
    if f["kind"] == "ISSUE":
        return "n/a"
    h = f["head"]
    m = _ISSUE_HEAD.match(h)
    if m:
        n = int(m.group(1))
        return "issue-integration" if n in issues and issues[n]["children"] else "issue-sub"
    if h.startswith("arch-review/"):
        return "arch"
    if h.startswith(("feature/", "improve/")) or re.match(r"^\d+-", h) or re.search(r"Skills?-.*Agent", h):
        return "feature"
    if h.startswith("research/"):
        return "research"
    if h.startswith(("fix/", "bug/")):
        return "fix"
    if h.startswith(("discovery/", "fresh-eyes/")):
        return "discovery"
    return "other"


def merge_target(f):
    if f["kind"] == "ISSUE":
        return "n/a"
    return "main" if f["base"] == "main" else "integration"


def _own_work_type(f):
    labels = set(f["labels"])
    t = f["title"]
    if "bug" in labels or f["head"].startswith(("fix/", "bug/")) or t.startswith("[dogfood]"):
        return "Bug"
    if "discovery" in labels or t.startswith("[Research]") or f["head"].startswith("research/"):
        return "Discovery"
    if _ARCH_TITLE.match(t) or f["head"].startswith("arch-review/"):
        return "Governance"
    if _TOOLING.search(t) or f["head"].startswith("tooling/"):
        return "Tooling"
    if "skill" in labels or _SKILL_TITLE.match(t):
        return "Skill"
    if "agent" in labels:
        return "Agent"
    if "documentation" in labels or _DOCS.search(t):
        return "Docs"
    if f["kind"] == "PR" and branch_type(f, {}) == "feature":
        return "Skill"
    return "Enhancement"


def _own_campaign(f):
    t, h, day = f["title"], f["head"], _day(f["created"])
    if _ARCH_TITLE.match(t) or h.startswith("arch-review/"):
        return "Arch-Review"
    if day >= FRESH_EYES_START or h.startswith(("fresh-eyes/", "discovery/")):
        return "Fresh-Eyes"
    if t.startswith("[Research]") or h.startswith("research/"):
        return "Research"
    if h.startswith("skill-refactor/") or _SKILL_TITLE.match(t):
        return "Skill-Refactor"
    if f["kind"] == "PR" and branch_type(f, {}) == "feature":
        return "Foundation"
    if day < TOOLING_START:
        return "Foundation"
    return "Maintenance"


def complexity(lines, files):
    i = (0 if lines < 20 else 1 if lines < 150 else 2 if lines < 600 else 3 if lines < 2000 else 4)
    if files > 15:
        i = min(i + 1, 4)
    return _COMPLEXITY[i]


def severity(f, work_type):
    if work_type != "Bug":
        return "N/A"
    t = f["title"]
    if _S1.search(t):
        return "S1"
    if _S4.search(t):
        return "S4"
    if _S2.search(t):
        return "S2"
    return "S3"


def priority(f, work_type, sev, hier):
    t = f["title"]
    if work_type == "Bug" and (_P0.search(t) or sev == "S1"):
        return "P0"
    if f["blocking"] or hier == "Parent" or sev == "S2":
        return "P1"
    if work_type == "Docs" or _DOCS.search(t):
        return "P3"
    return "P2"


def cycle_days(f):
    if not (f["created"] and f["closed"]):
        return None
    a = _dt.datetime.fromisoformat(f["created"].replace("Z", "+00:00"))
    b = _dt.datetime.fromisoformat(f["closed"].replace("Z", "+00:00"))
    return round(max((b - a).total_seconds(), 0) / 86400, 2)


def duration(days):
    if days is None:
        return "Open"
    if days < 1 / 24:
        return "<1h"
    if days < 1:
        return "<1d"
    if days < 3:
        return "1-3d"
    if days < 7:
        return "3-7d"
    return ">7d"


def dependency(blocked_by, blocking):
    if blocked_by and blocking:
        return "Both"
    if blocked_by:
        return "Blocked"
    if blocking:
        return "Blocking"
    return "Independent"


def sprint(f, today=None):
    day = _day(f["closed"]) or _day(f["created"]) or (today or _dt.date.today().isoformat())
    start = _dt.date.fromisoformat(config.SPRINT_START)
    idx = (_dt.date.fromisoformat(day) - start).days // config.SPRINT_DAYS
    idx = max(0, min(idx, config.SPRINT_COUNT - 1))
    return f"Sprint 2026 {idx + 1:02d}"


# --- whole-board derivation --------------------------------------------------

def derive_all(facts):
    """facts: list of normalize() dicts for every board item. Returns
    {item_id: {field: value}}. Cross-item rules (parent inheritance, PR→issue
    linkage, size roll-up) need the whole board, hence one pass over all."""
    issues = {f["number"]: f for f in facts if f["kind"] == "ISSUE"}
    prs = [f for f in facts if f["kind"] == "PR"]

    # PR → owning issue, and size roll-up onto issues.
    pr_owner = {f["item_id"]: pr_issue(f, issues) for f in prs}
    size = {n: [0, 0] for n in issues}
    for f in prs:
        n = pr_owner[f["item_id"]]
        if n:
            size[n][0] += f["lines"]
            size[n][1] += f["files"]

    def issue_size(n, seen=()):
        lines, files = size[n]
        kids = [k for k, v in issues.items() if v["parent"] == n and k not in seen]
        for k in kids:
            kl, kf = issue_size(k, seen + (n,))
            lines, files = lines + kl, files + kf
        return lines, files

    # Campaign / work type: an issue inherits its top-most parent's campaign.
    def root(n, seen=()):
        p = issues[n]["parent"]
        return root(p, seen + (n,)) if p in issues and p not in seen else n

    out = {}
    for f in facts:
        hier = hierarchy(f, issues)
        owner = issues.get(pr_owner.get(f["item_id"])) if f["kind"] == "PR" else f
        if owner:
            camp = _own_campaign(issues[root(owner["number"])])
            wtype = _own_work_type(owner)
            if wtype == "Enhancement":
                wtype = _own_work_type(f)
            deps = (owner["blocked_by"], owner["blocking"])
        else:
            camp, wtype, deps = _own_campaign(f), _own_work_type(f), (0, 0)
        if f["kind"] == "PR":
            lines, files = f["lines"], f["files"]
        else:
            lines, files = issue_size(f["number"])
        cx = complexity(lines, files)
        sev = severity(owner or f, wtype)
        pri = priority(owner or f, wtype, sev, hierarchy(owner, issues) if owner else hier)
        days = cycle_days(f)
        out[f["item_id"]] = {
            "Hierarchy": hier,
            "Work-Type": wtype,
            "Campaign": camp,
            "Branch-Type": branch_type(f, issues),
            "Merge-Target": merge_target(f),
            "Priority": pri,
            "Severity": sev,
            "Complexity": cx,
            "Effort-Points": float(EFFORT_POINTS[cx]),
            "Cycle-Days": days,
            "Duration": duration(days),
            "Dependency": dependency(*deps),
            "Blocked-By": float(deps[0]),
            "Data-Source": "Derived",
            config.SPRINT_FIELD_NAME: sprint(f),
        }
    return out
