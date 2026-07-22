#!/usr/bin/env python3
"""plan-exit [--confirm]

Without --confirm: prints the current draft table for review (dry run, no
GitHub mutation). This is the "show it back to me" checkpoint.

With --confirm: creates each draft row as a native GitHub sub-issue of the
tracked parent, adds each to the Project (Status = Todo), sets its Sequence
field, wires cross-sub-issue dependencies via the native issue Relationships
(blocked-by) mechanism, then moves the parent to Status = In Progress.

Safe to re-run: rows already created (tracked in local state) are skipped.
"""
import argparse
import sys

from ghp import gh, project, state


def _sort_key(draft_id):
    try:
        return int(draft_id.lstrip("d"))
    except ValueError:
        return draft_id


def print_table(rows):
    if not rows:
        print("(draft is empty — nothing to exit with)")
        return
    for row_id in sorted(rows, key=_sort_key):
        row = rows[row_id]
        deps = ", ".join(row["depends_on"]) or "-"
        print(f"[{row_id}] {row['title']}")
        print(f"      description: {row['description']}")
        print(f"      depends_on:  {deps}")
        print(f"      sequence:    {row['sequence'] or '(none)'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--confirm", action="store_true")
    args = parser.parse_args()

    st = state.load()
    plan = st.get("current_plan")
    if not plan:
        print("No active plan. Run plan-start first.", file=sys.stderr)
        sys.exit(1)

    rows = st["draft"]["rows"]
    created = st["draft"].setdefault("created", {})

    print(f"Parent: #{plan['issue_number']} \"{plan['title']}\"")
    print_table(rows)

    if not args.confirm:
        if rows:
            print(
                "\nDry run only — nothing was created. Re-run with --confirm "
                "to create these on GitHub."
            )
        return

    if not rows:
        print("\nNothing to do.")
        return

    try:
        gh.check_auth()

        # Pass 1: create (or reuse) each sub-issue.
        for row_id in sorted(rows, key=_sort_key):
            row = rows[row_id]
            if row_id in created:
                print(f"skip (already created): {row_id} -> #{created[row_id]['number']}")
                continue
            issue = project.create_issue(
                row["title"], row["description"], parent_issue_id=plan["issue_id"]
            )
            item_id = project.add_item_to_project(issue["id"])
            project.set_status(item_id, "todo")
            if row["sequence"]:
                project.set_sequence(item_id, row["sequence"])
            created[row_id] = {
                "number": issue["number"],
                "id": issue["id"],
                "item_id": item_id,
                "title": issue["title"],
                "sequence": row["sequence"],
            }
            state.save(st)
            print(f"created {row_id} -> #{issue['number']} \"{issue['title']}\"")

        # Pass 2: wire cross-sub-issue dependencies via native Relationships.
        for row_id in sorted(rows, key=_sort_key):
            row = rows[row_id]
            for dep_id in row["depends_on"]:
                if dep_id not in created:
                    continue
                this_issue_id = created[row_id]["id"]
                dep_issue_id = created[dep_id]["id"]
                try:
                    project.add_blocked_by(this_issue_id, dep_issue_id)
                    print(f"  {row_id} (#{created[row_id]['number']}) blocked by "
                          f"{dep_id} (#{created[dep_id]['number']})")
                except gh.GhError as e:
                    print(f"  warning: could not link {row_id} -> {dep_id}: {e}", file=sys.stderr)

        # Move parent to In Progress and record the sub-issues, then clear the draft.
        project.set_status(plan["item_id"], "in_progress")
        plan["status"] = "in_progress"
        for row_id, info in created.items():
            st["sub_issues"][str(info["number"])] = {
                "id": info["id"],
                "item_id": info["item_id"],
                "title": info["title"],
                "sequence": info["sequence"],
            }
        st["draft"] = {"next_id": 1, "rows": {}}
        state.save(st)

        print(f"\nParent #{plan['issue_number']} -> In Progress. "
              f"{len(created)} sub-issue(s) created.")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
