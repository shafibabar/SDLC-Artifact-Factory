#!/usr/bin/env python3
"""Tests scripts/github-project/ghp/project.py add_item_to_project against a
stubbed gh.graphql: no gh call. When the Project's auto-add workflow has
already added the issue, the mutation fails with "Content already exists";
the function must return the existing item, not raise (a raise left the
created issue untracked, and a plan-exit retry created it twice).
Prints PASS/FAIL lines; exits 0 iff every case passed."""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts/github-project"))
from ghp import config, gh, project  # noqa: E402

passed, failed = 0, []


def check(name, ok, detail=""):
    global passed
    if ok:
        print(f"PASS: github-project-add-item ({name})")
        passed += 1
    else:
        print(f"FAIL: github-project-add-item ({name}) {detail}")
        failed.append(name)


def stub(mutation_error=None, items=()):
    def graphql(query):
        if "addProjectV2ItemById" in query:
            if mutation_error:
                raise gh.GhError(mutation_error)
            return {"addProjectV2ItemById": {"item": {"id": "NEW"}}}
        return {"node": {"projectItems": {"nodes": [{"id": i, "project": {"id": p}} for i, p in items]}}}
    gh.graphql = graphql


stub()
check("adds a new item", project.add_item_to_project("I1") == "NEW")

stub("gh: Content already exists in this project", [("OTHER", "PX"), ("EXISTING", config.PROJECT_ID)])
got = project.add_item_to_project("I1")
check("already on the Project returns the existing item", got == "EXISTING", f"got {got!r}")

stub("gh: Content already exists in this project", [("OTHER", "PX")])
try:
    project.add_item_to_project("I1")
    check("already-exists with no item on this Project raises", False, "did not raise")
except gh.GhError:
    check("already-exists with no item on this Project raises", True)

stub("gh: Could not resolve to a node")
try:
    project.add_item_to_project("I1")
    check("any other error still raises", False, "did not raise")
except gh.GhError:
    check("any other error still raises", True)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
sys.exit(1 if failed else 0)
