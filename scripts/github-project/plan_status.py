#!/usr/bin/env python3
"""plan-status <planning|in-progress|in-review|done>

Updates the Status of the currently tracked parent issue. Invoking this
command IS the approval checkpoint — no further confirmation step.
"""
import argparse
import sys

from ghp import gh, project, state

STATUS_MAP = {
    "planning": "in_planning",
    "in-progress": "in_progress",
    "in-review": "in_review",
    "done": "done",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("status", choices=sorted(STATUS_MAP.keys()))
    args = parser.parse_args()

    try:
        gh.check_auth()
        st = state.load()
        plan = st.get("current_plan")
        if not plan:
            print("No active plan. Run plan-start first.", file=sys.stderr)
            sys.exit(1)

        status_key = STATUS_MAP[args.status]
        project.set_status(plan["item_id"], status_key)
        plan["status"] = status_key
        state.save(st)

        print(f"#{plan['issue_number']} \"{plan['title']}\" -> {args.status}")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
