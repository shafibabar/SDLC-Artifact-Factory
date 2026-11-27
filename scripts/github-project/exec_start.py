#!/usr/bin/env python3
"""exec-start <sub-issue-number> [--base <branch>]

Creates a branch + draft PR for the given sub-issue and moves it to
Status = In Progress. Invoking this command IS the approval checkpoint.

The branch is always cut from current HEAD, and the PR targets the branch it
was cut from:

  * on the repo's default branch: the PR targets the default branch;
  * on any other branch (an integration or wave branch that sub-issue PRs
    merge into, rather than main directly): the PR targets THAT branch. It
    used to target the default branch unless --base was typed, which opened
    a wave's sub-issue PR against main (#1510);
  * on another sub-issue's `issue-<n>-...` branch: refused unless --base is
    given, since stacking one sub-issue on another is rarely meant.

--base names the branch explicitly and wins over the above; current HEAD
must already be that branch (or a descendant of it) when this runs.

The resolved base, when it is not the default branch, is recorded in local state so exec_complete.py knows to
auto-merge and auto-close this sub-issue once its PR is ready (see that
script's docstring) -- default-branch sub-issues (no --base) are unaffected
and still stop at Status: In Review, review/merge/close manual as always.
"""
import argparse
import re
import subprocess
import sys

from ghp import config, gh, insights_sync, project, state

_REPO_ROOT = state._REPO_ROOT


def slugify(title):
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return slug[:50] or "work"


def run_git(args):
    result = subprocess.run(["git"] + args, cwd=_REPO_ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise gh.GhError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def default_branch():
    """The repo's default branch, from the local origin/HEAD pointer (no network)."""
    result = subprocess.run(["git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
                            cwd=_REPO_ROOT, capture_output=True, text=True)
    name = result.stdout.strip()
    return name.split("/", 1)[1] if result.returncode == 0 and "/" in name else "main"


def resolve_base(explicit, current, default):
    """Which branch the sub-issue's PR targets; None means the default branch.

    Pure: `explicit` is --base (or None), `current` the checked-out branch
    ("" when HEAD is detached), `default` the repo's default branch.
    """
    if explicit:
        return explicit
    if not current:
        raise gh.GhError("HEAD is detached: check out the branch to cut from, or pass --base <branch>.")
    if current == default:
        return None
    if re.match(r"issue-\d+-", current):
        raise gh.GhError(
            f"You are on an issue branch ('{current}'). Check out the branch this sub-issue "
            f"should merge into, or pass --base <branch> if it is meant to merge into this one."
        )
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("issue_number", type=int)
    parser.add_argument("--base", default=None, help="Branch to cut from and target (default: the branch you are on)")
    args = parser.parse_args()

    try:
        gh.check_auth()
        st = state.load()
        cached = st["sub_issues"].get(str(args.issue_number))
        if cached:
            issue_id, item_id, title = cached["id"], cached["item_id"], cached["title"]
        else:
            issue_id, item_id, title = project.find_item(args.issue_number)

        current = run_git(["branch", "--show-current"]).strip()
        args.base = resolve_base(args.base, current, default_branch())
        if args.base:
            print(f"base: {args.base} (the PR targets this branch, not the default branch)")

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

        # Mirror the sub-issue's labels onto its PR (Shafi's decision, 2026-07-24:
        # every issue/sub-issue/PR must carry at least one canonical label). The
        # issue is the single source of truth; the PR never asks for its own set.
        labels = gh.get_issue_labels(args.issue_number)
        gh.validate_labels(labels)

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

        # Applied via the REST labels endpoint, not `gh pr create --label` --
        # that flag routes through the same GraphQL "Projects (classic)" query
        # that makes `gh pr edit --add-label` fail outright on this repo.
        pr_number_match = re.search(r"/pull/(\d+)", pr_url)
        if not pr_number_match:
            raise gh.GhError(f"Could not parse a PR number out of {pr_url!r}.")
        gh.add_labels(pr_number_match.group(1), labels)

        project.set_status(item_id, "in_progress")
        # The new PR lands on the board via the Project's auto-add workflow, if
        # one is set; sync() skips it when it isn't there yet. exec-complete
        # syncs it again once it exists.
        insights_sync.sync([args.issue_number, int(pr_number_match.group(1))])

        st["executions"][str(args.issue_number)] = {
            "branch": branch, "pr_url": pr_url, "status": "in_progress",
            "base": args.base,
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
