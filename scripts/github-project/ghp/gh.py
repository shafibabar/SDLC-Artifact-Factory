"""Thin wrapper around the `gh` CLI: subprocess plumbing, GraphQL calls, auth check.

Every function here either returns parsed JSON or raises GhError with a message
already formatted for a non-programmer to read and act on.
"""

import json
import subprocess

from . import config


class GhError(RuntimeError):
    pass


def _run(args, input_text=None):
    try:
        result = subprocess.run(
            ["gh"] + args,
            input=input_text,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        raise GhError(
            "The `gh` CLI is not installed or not on PATH. Install it from "
            "https://cli.github.com/ before using this tooling."
        )
    if result.returncode != 0:
        raise GhError(f"gh {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def check_auth():
    """Fail fast with the exact remediation command if auth/scopes are missing."""
    try:
        result = subprocess.run(
            ["gh", "auth", "status"], capture_output=True, text=True, check=False
        )
    except FileNotFoundError:
        raise GhError(
            "The `gh` CLI is not installed or not on PATH. Install it from "
            "https://cli.github.com/ before using this tooling."
        )
    output = result.stdout + result.stderr
    if result.returncode != 0 or "Logged in" not in output:
        raise GhError(
            "Not logged into `gh`. Run: gh auth login"
        )
    missing = [s for s in config.REQUIRED_SCOPES if s not in output]
    if missing:
        raise GhError(
            "Missing required gh auth scope(s): "
            + ", ".join(missing)
            + ". Run: gh auth refresh -s "
            + ",".join(config.REQUIRED_SCOPES)
        )


def gql_string(value):
    """Render a Python string as a GraphQL string literal (JSON escaping is a
    valid subset of GraphQL string escaping, so json.dumps does the job)."""
    return json.dumps(value if value is not None else "")


def graphql(query):
    """Run a fully-formed GraphQL query/mutation (values already inlined via
    gql_string). Keeping this to raw query text — not gh's -f/-F variable
    flags — avoids ambiguity around how those flags encode null/optional
    values for a modest number of call sites."""
    stdout = _run(["api", "graphql", "-f", f"query={query}"])
    data = json.loads(stdout)
    if "errors" in data:
        raise GhError("GitHub API error: " + json.dumps(data["errors"], indent=2))
    return data["data"]


def validate_labels(labels):
    """Every issue/sub-issue/PR created by this tooling must carry at least
    one canonical label (Shafi's decision, 2026-07-24). Raises GhError with
    a message a non-programmer can act on if the set is empty or unknown."""
    if not labels:
        raise GhError(
            "At least one label is required: " + ", ".join(config.CANONICAL_LABELS)
        )
    unknown = [l for l in labels if l not in config.CANONICAL_LABELS]
    if unknown:
        raise GhError(
            f"Unknown label(s): {', '.join(unknown)}. Choose from: "
            + ", ".join(config.CANONICAL_LABELS)
        )


def add_labels(number, labels):
    """Attach labels to an issue or PR. Deliberately goes through the REST
    labels endpoint (`gh api .../issues/<n>/labels`, which treats PRs as
    issues) rather than `gh issue edit`/`gh pr edit --add-label` -- both of
    those trigger a GraphQL query touching deprecated "Projects (classic)"
    fields that fails outright for PRs on this repo (confirmed empirically:
    `gh pr edit --add-label` returns exit 1 and the label is never applied,
    while the REST endpoint works for both issues and PRs)."""
    if not labels:
        return
    args = ["api", f"repos/{config.REPO_OWNER}/{config.REPO_NAME}/issues/{number}/labels"]
    for label in labels:
        args += ["-f", f"labels[]={label}"]
    _run(args)


def get_issue_labels(number):
    stdout = _run(["issue", "view", str(number), "--repo",
                    f"{config.REPO_OWNER}/{config.REPO_NAME}", "--json", "labels"])
    return [l["name"] for l in json.loads(stdout)["labels"]]
