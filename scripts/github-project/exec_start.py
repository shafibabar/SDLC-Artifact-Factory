#!/usr/bin/env python3
"""exec-start <sub-issue-number> [--base <branch>]

Creates a branch + draft PR for the given sub-issue and moves it to
Status = In Progress. Invoking this command IS the approval checkpoint.

By default the branch is cut from current HEAD and the PR targets the
repo's default branch. Pass --base to cut from and target a different
branch instead (e.g. an issue-level integration branch that sub-issue
PRs merge into, rather than main directly) -- current HEAD must already
be that branch (or a descendant of it) when this runs.
"""
import argparse
import re
import subprocess
import sys

from ghp import config, gh, project, state

_REPO_ROOT = state._REPO_ROOT


def slugify(title):
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return slug[:50] or "work"


def run_git(args):
    result = subprocess.run(["git"] + args, cwd=_REPO_ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise gh.GhError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("issue_number", type=int)
    parser.add_argument("--base", default=None, help="Branch to cut from and target (default: repo default branch)")
    args = parser.parse_args()

    try:
        gh.check_auth()
        st = state.load()
        cached = st["sub_issues"].get(str(args.issue_number))
        if cached:
            issue_id, item_id, title = cached["id"], cached["item_id"], cached["title"]
        else:
            issue_id, item_id, title = project.find_item(args.issue_number)

        branch = f"issue-{args.issue_number}-{slugify(title)}"
        run_git(["checkout", "-b", branch])
        run_git(["commit", "--allow-empty", "-m", f"Start #{args.issue_number}: {title}"])
        run_git(["push", "-u", "origin", branch])

        if args.base:
            pr_body = (
                f"Part of #{args.issue_number}. Merges into `{args.base}`, not directly "
                f"into the default branch -- this does not auto-close #{args.issue_number}; "
                f"that happens when `{args.base}` itself merges."
            )
        else:
            pr_body = f"Closes #{args.issue_number}"

        pr_cmd = [
            "gh", "pr", "create",
            "--repo", f"{config.REPO_OWNER}/{config.REPO_NAME}",
            "--title", f"{title} (#{args.issue_number})",
            "--body", pr_body,
            "--draft",
        ]
        if args.base:
            pr_cmd += ["--base", args.base]

        pr_out = subprocess.run(pr_cmd, cwd=_REPO_ROOT, capture_output=True, text=True)
        if pr_out.returncode != 0:
            raise gh.GhError(f"gh pr create failed:\n{pr_out.stderr.strip()}")
        pr_url = pr_out.stdout.strip()

        project.set_status(item_id, "in_progress")

        st["executions"][str(args.issue_number)] = {
            "branch": branch, "pr_url": pr_url, "status": "in_progress",
        }
        state.save(st)

        print(f"#{args.issue_number} \"{title}\" -> In Progress")
        print(f"branch: {branch}")
        print(f"PR: {pr_url}")
    except gh.GhError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
