#!/usr/bin/env python3
"""
tests/scripts/exec-start-base.test.py — which branch a sub-issue's PR targets
(scripts/github-project/exec_start.py, resolve_base; #1510).

A sub-issue started from a wave branch must target that wave branch: its PR
opening against main would carry the whole wave there. No network, no git
writes: resolve_base is pure.

Standalone:  python3 tests/scripts/exec-start-base.test.py
"""
import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = REPO_ROOT / "scripts" / "github-project"
sys.path.insert(0, str(TOOL_DIR))
spec = importlib.util.spec_from_file_location("_exec_start_under_test", TOOL_DIR / "exec_start.py")
E = importlib.util.module_from_spec(spec)
spec.loader.exec_module(E)

passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: exec-start-base ({name})")
        passed += 1
    else:
        print(f"FAIL: exec-start-base ({name})")
        failed.append(name)


def refused(explicit, current):
    try:
        E.resolve_base(explicit, current, "main")
    except E.gh.GhError as exc:
        return str(exc)
    return None


check("on the default branch the PR targets the default branch", E.resolve_base(None, "main", "main") is None)
check("on a wave branch the PR targets the wave branch",
      E.resolve_base(None, "fresh-eyes/wave-3-testing", "main") == "fresh-eyes/wave-3-testing")
check("--base wins over the current branch",
      E.resolve_base("release-x", "fresh-eyes/wave-3-testing", "main") == "release-x")
check("--base is honoured on the default branch", E.resolve_base("release-x", "main", "main") == "release-x")
check("another sub-issue's branch is refused without --base",
      "issue branch" in (refused(None, "issue-1489-go-contract-test") or ""))
check("another sub-issue's branch is allowed with --base",
      E.resolve_base("issue-1489-go-contract-test", "issue-1489-go-contract-test", "main")
      == "issue-1489-go-contract-test")
check("a detached HEAD is refused without --base", "detached" in (refused(None, "") or ""))
check("a branch merely containing 'issue' is not mistaken for a sub-issue branch",
      E.resolve_base(None, "fix/issue-tracker", "main") == "fix/issue-tracker")
check("a different default branch name is respected", E.resolve_base(None, "trunk", "trunk") is None)
check("the default branch is read locally", isinstance(E.default_branch(), str) and E.default_branch() != "")

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    sys.exit(1)
