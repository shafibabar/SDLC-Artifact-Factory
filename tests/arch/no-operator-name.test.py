#!/usr/bin/env python3
"""
tests/arch/no-operator-name.test.py — the plugin's shipped components never
name this repo's operator (closes #1248).

The agents, skills, commands, hooks and schemas are instructions Claude follows
inside *other people's* product repos. When they named the operator ("present
each artifact to Shafi"), that name leaked into strangers' stakeholder maps,
decisions and status reports (dogfood run, discovery/fresh-eyes/01-dogfood.md).
Shipped components say "the user" (the person in the session) or "the product
owner" (the role) instead. The operator's name stays legitimate in this repo's
own working docs (CLAUDE.md, campaign charters, sdlc-context.json, discovery/)
and its internal tooling (scripts/github-project/), which users never load.

Runs in the governance gate (tests/arch/*.test.py), so it is BLOCKING.
Standalone:  python3 tests/arch/no-operator-name.test.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SHIPPED_DIRS = ("agents", "skills", "commands", "hooks", "schemas")
FORBIDDEN = re.compile(r"\bShafi\b|\bHan Solo\b")

passed, failed = 0, []


def check(name, condition, detail=""):
    global passed
    if condition:
        print(f"PASS: no-operator-name ({name})")
        passed += 1
    else:
        print(f"FAIL: no-operator-name ({name}){detail}")
        failed.append(name)


# The pattern itself: catches the name, ignores look-alikes.
check("pattern matches the name", bool(FORBIDDEN.search("present it to Shafi for approval")))
check("pattern matches the possessive", bool(FORBIDDEN.search("wait for Shafi's go")))
check("pattern ignores look-alike words", not FORBIDDEN.search("Shafique Shafiq shafi_id"))

hits = []
for d in SHIPPED_DIRS:
    for path in sorted((REPO_ROOT / d).rglob("*")):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            if FORBIDDEN.search(line):
                hits.append(f"{path.relative_to(REPO_ROOT)}:{lineno}: {line.strip()[:100]}")

detail = "".join(f"\n    {h}" for h in hits[:20])
if len(hits) > 20:
    detail += f"\n    … and {len(hits) - 20} more"
check(f"shipped components ({', '.join(SHIPPED_DIRS)}) never name the operator", not hits, detail)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
sys.exit(1 if failed else 0)
