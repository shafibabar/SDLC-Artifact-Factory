"""Local working state: the currently tracked parent issue, its in-progress
sub-issue draft, and per-sub-issue execution tracking.

Gitignored — this is per-machine session state, not a durable artifact.
Structure:
{
  "current_plan": {"issue_number", "issue_id", "title", "item_id", "status"},
  "draft": {"next_id": int, "rows": {"d1": {"title", "description",
            "depends_on": [draft ids], "sequence"}}},
  "sub_issues": {"<number>": {"id", "item_id", "title", "sequence"}},
  "executions": {"<number>": {"branch", "status"}}
}
"""

import json
import os

from . import config

_REPO_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..")
)
STATE_PATH = os.path.join(_REPO_ROOT, config.STATE_FILE)

DEFAULT_STATE = {
    "current_plan": None,
    "draft": {"next_id": 1, "rows": {}},
    "sub_issues": {},
    "executions": {},
}


def load():
    if not os.path.exists(STATE_PATH):
        return json.loads(json.dumps(DEFAULT_STATE))
    with open(STATE_PATH) as f:
        data = json.load(f)
    for key, value in DEFAULT_STATE.items():
        data.setdefault(key, json.loads(json.dumps(value)))
    return data


def save(state):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w") as f:
        json.dump(state, f, indent=2)
        f.write("\n")
