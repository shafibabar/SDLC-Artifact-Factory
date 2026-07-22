#!/usr/bin/env python3
"""plan-status <planning|in-progress|in-review|done>

Updates the Status of the currently tracked parent issue. Invoking this
command IS the approval checkpoint — no further confirmation step.

Marking a plan "done" also clears it as the tracked current_plan in local
state, since nothing else does — this is what frees up plan-start to begin
the next plan.
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

        issue_number, title = plan["issue_number"], plan["title"]
        if args.status == "done":
            st["current_plan"] = None
        else:
            plan["status"] = status_key
        state.save(st)

        print(f"#{issue_number} \"{title}\" -> {args.status}")
        if args.status == "done":
            print("Cleared as the tracked current_plan — plan-start is free to begin the next one.")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
