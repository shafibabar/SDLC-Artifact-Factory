#!/usr/bin/env python3
"""plan-start "<title>" [--body "<body>"]

Creates the parent issue for a new planning cycle, adds it to the Project,
sets Status = Todo then In Planning, and tracks it as the active plan in
local state. Invoking this command IS the approval checkpoint for stage 1 —
no further confirmation step.
"""
import argparse
import sys

from ghp import config, gh, project, state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("title")
    parser.add_argument("--body", default="")
    args = parser.parse_args()

    try:
        gh.check_auth()

        existing = state.load()
        if existing.get("current_plan"):
            cp = existing["current_plan"]
            print(
                f"A plan is already active: #{cp['issue_number']} \"{cp['title']}\" "
                f"({cp['status']}). Finish or clear it before starting a new one.",
                file=sys.stderr,
            )
            sys.exit(1)

        issue = project.create_issue(args.title, args.body)
        item_id = project.add_item_to_project(issue["id"])
        project.set_status(item_id, "todo")
        project.set_status(item_id, "in_planning")

        st = state.load()
        st["current_plan"] = {
            "issue_number": issue["number"],
            "issue_id": issue["id"],
            "title": issue["title"],
            "item_id": item_id,
            "status": "in_planning",
        }
        state.save(st)

        print(f"Created #{issue['number']} \"{issue['title']}\" — {issue['url']}")
        print("Status: Todo -> In Planning. Tracked as the active plan.")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
