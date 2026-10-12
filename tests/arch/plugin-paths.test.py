#!/usr/bin/env python3
"""
tests/arch/plugin-paths.test.py — commands and agents can find the plugin's own
files in a user's repo (closes #1250).

Commands, agents and skills run inside *other people's* repos, where a path like
`skills/x/SKILL.md` or `agents/y.md` does not exist; in the dogfood run Claude
searched the whole filesystem for an agent file and timed out. Claude Code
substitutes ${CLAUDE_PLUGIN_ROOT} in command, agent and skill text (verified
live 2026-10-12), so:

  1. commands/ and agents/ reference plugin files only as ${CLAUDE_PLUGIN_ROOT}/…
     (skills use ./relative paths, enforced by lint-skill-layout L5);
  2. every command that invokes one of this plugin's agents names the namespaced
     subagent_type (sdlc-artifact-factory:<agent>);
  3. the tech-stack defaults the plugin ships
     (skills/sdlc-config-management/resources/tech-stack-defaults.json) match
     the maintainers' copy in CLAUDE.md and the skill's field reference.

Runs in the governance gate (tests/arch/*.test.py), so it is BLOCKING.
Standalone:  python3 tests/arch/plugin-paths.test.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PLUGIN_DIRS = r"(?:skills|agents|scripts|schemas|commands|hooks)"
# A plugin-relative path not anchored at ${CLAUDE_PLUGIN_ROOT}/ (or any other
# prefix such as artifacts/…/ or a URL).
BARE = re.compile(r"(?<![\w/{}$.:-])" + PLUGIN_DIRS + r"/[\w<>\[\].-]+")

passed, failed = 0, []


def check(name, condition, detail=""):
    global passed
    if condition:
        print(f"PASS: plugin-paths ({name})")
        passed += 1
    else:
        print(f"FAIL: plugin-paths ({name}){detail}")
        failed.append(name)


def body(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            return text[end + 4:]
    return text


# --- the pattern itself ------------------------------------------------------
check("pattern flags a bare skill path", bool(BARE.search("Read `skills/memory-recall/SKILL.md`")))
check("pattern flags a bare agent path", bool(BARE.search("see agents/test-strategist.md")))
check("pattern accepts the plugin-root form",
      not BARE.search("Read `${CLAUDE_PLUGIN_ROOT}/skills/memory-recall/SKILL.md`"))
check("pattern ignores product paths", not BARE.search("write artifacts/demo/design/scripts/x.sh"))

# --- 1. no bare plugin paths in commands/ and agents/ ------------------------
hits = []
for d in ("commands", "agents"):
    for path in sorted((REPO_ROOT / d).glob("*.md")):
        for lineno, line in enumerate(body(path).splitlines(), 1):
            for m in BARE.finditer(line):
                hits.append(f"{path.relative_to(REPO_ROOT)} (body line {lineno}): {m.group(0)}")
check("commands and agents reference plugin files only via ${CLAUDE_PLUGIN_ROOT}",
      not hits, "".join(f"\n    {h}" for h in hits[:20]))

# --- 2. agent invocations name the namespaced subagent_type ------------------
agent_names = {p.stem for p in (REPO_ROOT / "agents").glob("*.md")}
missing = []
for path in sorted((REPO_ROOT / "commands").glob("*.md")):
    text = body(path)
    invokes_ours = "Agent tool" in text and any(f"`{a}`" in text for a in agent_names)
    if invokes_ours and 'subagent_type: "sdlc-artifact-factory:' not in text:
        missing.append(path.name)
check("every command that invokes a plugin agent names sdlc-artifact-factory:<agent>",
      not missing, f"\n    missing in: {', '.join(missing)}")

# --- 3. shipped tech-stack defaults == CLAUDE.md == field reference ----------
shipped = json.loads((REPO_ROOT / "skills/sdlc-config-management/resources/tech-stack-defaults.json").read_text())
rows = {r["concern"]: (r["default"], r["override_key"]) for r in shipped["defaults"]}


def md_table(text: str, header_start: str) -> list[list[str]]:
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith(header_start))
    out = []
    for l in lines[start + 2:]:
        if not l.startswith("|"):
            break
        out.append([c.strip() for c in l.strip().strip("|").split("|")])
    return out


claude = {c[0]: c[1] for c in md_table((REPO_ROOT / "CLAUDE.md").read_text(), "| Concern | Default |")}
check("CLAUDE.md § Tech Stack Defaults matches the shipped defaults file",
      claude == {k: v[0] for k, v in rows.items()},
      f"\n    CLAUDE.md: {claude}\n    shipped:   { {k: v[0] for k, v in rows.items()} }")

ref = md_table((REPO_ROOT / "skills/sdlc-config-management/references/config-field-reference.md").read_text(),
               "| Concern | Default | Override key |")
ref_keys = {c[0]: c[2].strip("`").split()[0].strip("`") for c in ref if c[0] in rows}
check("field reference's override keys match the shipped defaults file",
      ref_keys == {k: v[1] for k, v in rows.items()},
      f"\n    reference: {ref_keys}")

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
sys.exit(1 if failed else 0)
