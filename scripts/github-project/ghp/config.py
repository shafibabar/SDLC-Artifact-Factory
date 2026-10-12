"""Static config discovered during the INVESTIGATION.md investigation pass.

These IDs describe the live "SKILL GEN Project" (github.com/users/shafibabar/projects/1).
Re-run the investigation queries in INVESTIGATION.md if this project's schema changes
(e.g. Status options get renamed) and update this file to match.
"""

REPO_OWNER = "shafibabar"
REPO_NAME = "SDLC-Artifact-Factory"
REPO_ID = "R_kgDOS_2DcA"

PROJECT_OWNER = "shafibabar"
PROJECT_NUMBER = 1
PROJECT_ID = "PVT_kwHOA4gFKc4Bbj6Q"

STATUS_FIELD_ID = "PVTSSF_lAHOA4gFKc4Bbj6QzhWTl28"

# Shafi's decision (2026-07-22): reuse the board's existing near-miss options
# ("Todo" / "In progress") rather than create exact-spec duplicates
# ("To Do" / "In Progress"). Do not add new Status options for this workflow.
STATUS_OPTION_IDS = {
    "todo": "f75ad846",        # existing option: "Todo"
    "in_planning": "f21b3f44", # existing option: "In Planning"
    "in_progress": "47fc9ee4", # existing option: "In progress"
    "in_review": "1e0d67d2",   # existing option: "In Review"
    "done": "98236657",        # existing option: "Done" (manual parent close only)
}

SEQUENCE_FIELD_NAME = "Sequence"

# Shafi's decision (2026-07-24): every issue, sub-issue, and PR created through
# this tooling must carry at least one of these labels (multiple allowed).
# Enforced in plan_start.py, save_draft.py, and plan_exit.py.
CANONICAL_LABELS = ("discovery", "agent", "skill", "bug", "documentation", "enhancement")

REQUIRED_SCOPES = ("repo", "project")

STATE_FILE = "scripts/github-project/.state.json"

# --- Insights fields (#1266) -------------------------------------------------
# Custom fields that the SKILL GEN Project's Insights charts slice by. Each one
# is resolved by NAME at runtime (project.insights_fields()), so no field or
# option IDs are hard-coded here. Names are hyphenated so chart filters need no
# quoting (e.g. `work-type:Bug`). Option order is the order a chart's axis shows.
# Colours are ProjectV2SingleSelectFieldOptionColor values.
INSIGHTS_SINGLE_SELECT = {
    "Hierarchy": [
        ("Parent", "PURPLE", "Issue with sub-issues (a plan / campaign phase)"),
        ("Sub-issue", "BLUE", "Issue under a parent"),
        ("Standalone", "GRAY", "Issue with no parent and no sub-issues"),
        ("Sub-issue PR", "GREEN", "PR merging into an integration branch"),
        ("Integration PR", "ORANGE", "issue-N-* integration branch -> main"),
        ("Direct PR", "YELLOW", "Any other PR straight to main"),
    ],
    "Work-Type": [
        ("Discovery", "BLUE", "Research / investigation before building"),
        ("Skill", "PURPLE", "Skill content or structure"),
        ("Agent", "PINK", "Agent definitions"),
        ("Governance", "ORANGE", "Architecture-review / linters / schemas / catalog"),
        ("Tooling", "YELLOW", "Plan/exec scripts, tests, harness"),
        ("Bug", "RED", "Defect fix"),
        ("Docs", "GRAY", "Documentation / housekeeping"),
        ("Enhancement", "GREEN", "Other feature work"),
    ],
    "Campaign": [
        ("Foundation", "GRAY", "Original feature/<n> build chunks"),
        ("Skill-Refactor", "PURPLE", "Per-skill depth refactors (issue-NNN)"),
        ("Arch-Review", "ORANGE", "Architecture Review campaign (arch-*)"),
        ("Fresh-Eyes", "GREEN", "Fresh-Eyes refactor (2026-10-11 ->)"),
        ("Research", "BLUE", "research/ library building"),
        ("Maintenance", "YELLOW", "Everything else"),
    ],
    "Branch-Type": [
        ("issue-integration", "ORANGE", "issue-N-* branch whose PR targets main"),
        ("issue-sub", "GREEN", "issue-N-* branch whose PR targets an integration branch"),
        ("arch", "PURPLE", "arch-* branches"),
        ("feature", "GRAY", "feature/<n>-* chunk branches"),
        ("research", "BLUE", "research* branches"),
        ("fix", "RED", "fix* / bug* branches"),
        ("discovery", "PINK", "discovery/* / fresh-* branches"),
        ("other", "YELLOW", "Any other branch"),
        ("n/a", "GRAY", "Issues (no branch of their own)"),
    ],
    "Merge-Target": [
        ("main", "ORANGE", "PR base is main"),
        ("integration", "GREEN", "PR base is an integration branch"),
        ("n/a", "GRAY", "Issues"),
    ],
    "Priority": [
        ("P0", "RED", "Critical: broken gate / blocking defect"),
        ("P1", "ORANGE", "High: blocks other work or leads the active campaign"),
        ("P2", "YELLOW", "Medium: default"),
        ("P3", "GRAY", "Low: docs / housekeeping"),
    ],
    "Severity": [
        ("S1", "RED", "Blocker: gate/CI broken, data loss, work blocked"),
        ("S2", "ORANGE", "Major: wrong output / behaviour"),
        ("S3", "YELLOW", "Minor: default for defects"),
        ("S4", "GRAY", "Cosmetic: wording, typo, formatting"),
        ("N/A", "GRAY", "Not a defect"),
    ],
    "Complexity": [
        ("XS", "GRAY", "< 20 lines changed"),
        ("S", "BLUE", "< 150 lines"),
        ("M", "GREEN", "< 600 lines"),
        ("L", "ORANGE", "< 2000 lines"),
        ("XL", "RED", ">= 2000 lines (or bumped for > 15 files)"),
    ],
    "Duration": [
        ("<1h", "GREEN", "Created to closed in under an hour"),
        ("<1d", "BLUE", "Under a day"),
        ("1-3d", "YELLOW", "1 to 3 days"),
        ("3-7d", "ORANGE", "3 to 7 days"),
        (">7d", "RED", "Over a week"),
        ("Open", "GRAY", "Not closed yet"),
    ],
    "Dependency": [
        ("Blocked", "RED", "Has an open-or-closed blocked-by link"),
        ("Blocking", "ORANGE", "Blocks another issue"),
        ("Both", "PURPLE", "Blocked by and blocking"),
        ("Independent", "GRAY", "No dependency links"),
    ],
    "Data-Source": [
        ("Derived", "GRAY", "Priority/Severity/Complexity derived by backfill rules"),
        ("Triaged", "GREEN", "Set deliberately by a person"),
    ],
}

INSIGHTS_NUMBER = ("Effort-Points", "Cycle-Days", "Blocked-By")

# Fields a person may set by hand (--priority/--complexity/--severity on
# plan-start and save-draft). Setting any of them marks the item
# Data-Source=Triaged, and the backfill then never overwrites it.
TRIAGE_FLAGS = ("Priority", "Complexity", "Severity")

# Sprint iterations: consecutive 14-day sprints from the first sprint's Monday.
SPRINT_FIELD_NAME = "Sprint"
SPRINT_START = "2026-06-22"
SPRINT_DAYS = 14
SPRINT_COUNT = 10  # through 2026-11-08; extend when the board runs past it
