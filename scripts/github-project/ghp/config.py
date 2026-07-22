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

REQUIRED_SCOPES = ("repo", "project")

STATE_FILE = "scripts/github-project/.state.json"
