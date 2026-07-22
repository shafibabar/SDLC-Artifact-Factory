#!/usr/bin/env python3
"""exec-complete <sub-issue-number> "<commit message>"

Commits staged changes, pushes, and moves the sub-issue to Status = In
Review. Invoking this command IS the approval checkpoint. Nothing past
In Review (review, merge, close) is automated by this tooling.
"""
import argparse
import subprocess
import sys

from ghp import gh, project, state

_REPO_ROOT = state._REPO_ROOT


def run_git(args):
    result = subprocess.run(["git"] + args, cwd=_REPO_ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise gh.GhError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("issue_number", type=int)
    parser.add_argument("message")
    args = parser.parse_args()

    try:
        gh.check_auth()
        st = state.load()
        cached = st["sub_issues"].get(str(args.issue_number))
        if cached:
            issue_id, item_id, title = cached["id"], cached["item_id"], cached["title"]
        else:
            issue_id, item_id, title = project.find_item(args.issue_number)

        exec_info = st["executions"].get(str(args.issue_number))
        current_branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"]).strip()
        if exec_info and exec_info.get("branch") != current_branch:
            print(
                f"warning: currently on branch \"{current_branch}\", but "
                f"exec-start recorded \"{exec_info['branch']}\" for #{args.issue_number}. "
                f"Proceeding on the current branch anyway.",
                file=sys.stderr,
            )

        run_git(["commit", "-m", args.message])
        run_git(["push"])

        project.set_status(item_id, "in_review")

        st["executions"].setdefault(str(args.issue_number), {})
        st["executions"][str(args.issue_number)]["status"] = "in_review"
        state.save(st)

        print(f"#{args.issue_number} \"{title}\" -> In Review")
        print("Committed and pushed. Review/merge/close remain manual.")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
