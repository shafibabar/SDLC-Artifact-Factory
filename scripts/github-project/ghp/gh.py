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
