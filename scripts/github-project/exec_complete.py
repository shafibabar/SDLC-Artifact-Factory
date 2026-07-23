#!/usr/bin/env python3
"""exec-complete <sub-issue-number> "<commit message>"

Commits staged changes, pushes, and moves the sub-issue to Status = In
Review.

For a sub-issue started with exec_start.py --base <branch> (the
issue-level-integration-branch pattern, D025): this command ALSO marks its
PR ready, merges it into <branch>, closes the sub-issue with a comment
referencing the merged PR, and sets Status = Done. This exists because a
--base PR never carries "Closes #N" (merging into a non-default branch
must not falsely claim the issue closed before the real work reaches
main), so GitHub's own auto-close never fires for these sub-issues --
without this step they stay open forever even after merging cleanly.

For a sub-issue started without --base (targeting the default branch
directly): behavior is unchanged. Review, merge, and close remain fully
manual -- that path lands on main directly and still needs a real human
review gate.

The commit message's subject line is whatever is passed in, but the tool
always appends a deterministic `git diff --staged --stat` block as the
body, so every commit objectively records which files changed regardless
of how descriptive the subject line is.
"""
import argparse
import re
import subprocess
import sys

from ghp import gh, project, state

_REPO_ROOT = state._REPO_ROOT


def run_git(args, input_text=None):
    result = subprocess.run(
        ["git"] + args, cwd=_REPO_ROOT, capture_output=True, text=True, input=input_text
    )
    if result.returncode != 0:
        raise gh.GhError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def run_gh(args):
    result = subprocess.run(
        ["gh"] + args, cwd=_REPO_ROOT, capture_output=True, text=True
    )
    if result.returncode != 0:
        raise gh.GhError(f"gh {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def pr_number_from_url(pr_url):
    match = re.search(r"/pull/(\d+)", pr_url or "")
    if not match:
        raise gh.GhError(f"Could not parse a PR number out of recorded pr_url {pr_url!r}.")
    return match.group(1)


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

        staged_stat = run_git(["diff", "--staged", "--stat"]).strip()
        if not staged_stat:
            raise gh.GhError(
                "Nothing is staged (git diff --staged --stat is empty). "
                "Stage the files you want committed first."
            )

        full_message = f"{args.message}\n\nFiles changed:\n{staged_stat}"
        run_git(["commit", "-F", "-"], input_text=full_message)
        run_git(["push"])

        project.set_status(item_id, "in_review")

        st["executions"].setdefault(str(args.issue_number), {})
        st["executions"][str(args.issue_number)]["status"] = "in_review"
        state.save(st)

        print(f"#{args.issue_number} \"{title}\" -> In Review")
        print("Committed and pushed.")

        base = (exec_info or {}).get("base")
        if not base:
            print("Review/merge/close remain manual.")
        else:
            pr_url = (exec_info or {}).get("pr_url")
            pr_number = pr_number_from_url(pr_url)

            run_gh(["pr", "ready", pr_number])
            run_gh(["pr", "merge", pr_number, "--merge", "--delete-branch"])
            run_gh([
                "issue", "close", str(args.issue_number),
                "--reason", "completed",
                "--comment",
                f"PR #{pr_number} merged into the integration branch (`{base}`). "
                f"Closing automatically: a --base PR never carries \"Closes #N\", "
                f"so GitHub's own auto-close does not fire for this sub-issue.",
            ])
            project.set_status(item_id, "done")

            st["executions"][str(args.issue_number)]["status"] = "done"
            state.save(st)

            print(f"PR #{pr_number} merged into `{base}`. Sub-issue #{args.issue_number} closed, Status -> Done.")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
