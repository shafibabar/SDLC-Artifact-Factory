#!/usr/bin/env python3
"""
tests/arch/migrate-skill-layout.test.py — contract for
scripts/arch/migrate-skill-layout.py (Fresh-Eyes A5, #1229).

Builds a synthetic repo in a temp dir, plans and applies a migration, and
asserts: the right files move (and mixed files do not), every broken pointer is
repointed (folder-rooted, $SKILL_DIR, bare sibling, moved file -> old sibling,
external repo-rooted), history is untouched, emptied folders are removed, the
result passes lint-skill-layout, and a second run is a no-op.

Standalone:  python3 tests/arch/migrate-skill-layout.test.py
"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def _load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


M = _load(REPO_ROOT / "scripts" / "arch" / "migrate-skill-layout.py", "_migrate_under_test")
LAYOUT = _load(REPO_ROOT / "scripts" / "lint-skill-layout.py", "_layout_for_migrate_test")

passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: migrate-skill-layout ({name})")
        passed += 1
    else:
        print(f"FAIL: migrate-skill-layout ({name})")
        failed.append(name)


def write(root: Path, rel: str, text: str) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    sk = "skills/fx"
    write(root, f"{sk}/SKILL.md",
          "---\nname: fx\n---\n"
          "Fill `references/output-format-template.md`; see ./references/worked-example.md.\n"
          "Read references/guide.md and references/notes-and-template.md.\n"
          "Run scripts/scaffold.sh.\n")
    write(root, f"{sk}/references/output-format-template.md", "template body\n")
    write(root, f"{sk}/references/worked-example.md", "Follows the rules in `guide.md`.\n")
    write(root, f"{sk}/references/guide.md",
          "Copy `output-format-template.md`, compare with [the example](worked-example.md).\n")
    write(root, f"{sk}/references/notes-and-template.md", "mixed content\n")
    write(root, f"{sk}/assets/fx-template.md", "asset template\n")
    write(root, f"{sk}/scripts/scaffold.sh", 'TEMPLATE="$SKILL_DIR/assets/fx-template.md"\n')
    write(root, "commands/sdlc-fx.md", "Use `skills/fx/references/output-format-template.md`.\n")
    write(root, "CHANGELOG.md", "- added skills/fx/references/output-format-template.md\n")

    plan = M.plan_skill(root / sk)
    moves = dict(plan["moves"])
    check("output-format-template -> templates/",
          moves.get("references/output-format-template.md") == "templates/output-format-template.md")
    check("worked-example -> examples/", moves.get("references/worked-example.md") == "examples/worked-example.md")
    check("asset template -> templates/", moves.get("assets/fx-template.md") == "templates/fx-template.md")
    check("a mixed '-and-' file is NOT moved", "references/notes-and-template.md" not in moves)
    check("the mixed file is listed for REVIEW", "references/notes-and-template.md" in plan["review"])
    check("plain prose stays put", "references/guide.md" not in moves)
    check("planning moved nothing on disk", (root / sk / "references/worked-example.md").is_file())

    res = M.apply_plan(plan, repo_root=root)
    s = lambda rel: (root / rel).read_text()
    check("apply reports 3 moves", res["moved"] == 3)
    check("files are at their new paths",
          (root / sk / "templates/output-format-template.md").is_file()
          and (root / sk / "examples/worked-example.md").is_file()
          and (root / sk / "templates/fx-template.md").is_file())
    body = s(f"{sk}/SKILL.md")
    check("SKILL.md folder-rooted pointer repointed", "`templates/output-format-template.md`" in body)
    check("SKILL.md ./-prefixed pointer repointed", "./examples/worked-example.md" in body)
    check("SKILL.md untouched pointers survive", "references/guide.md" in body)
    check("script's $SKILL_DIR/assets pointer repointed",
          '$SKILL_DIR/templates/fx-template.md' in s(f"{sk}/scripts/scaffold.sh"))
    guide = s(f"{sk}/references/guide.md")
    check("bare backtick sibling now cross-folder -> ../templates/",
          "`../templates/output-format-template.md`" in guide)
    check("markdown-link sibling now cross-folder -> ../examples/", "](../examples/worked-example.md)" in guide)
    check("moved file's pointer to a sibling left behind -> ../references/",
          "`../references/guide.md`" in s(f"{sk}/examples/worked-example.md"))
    check("external repo-rooted pointer repointed (commands/)",
          "skills/fx/templates/output-format-template.md" in s("commands/sdlc-fx.md"))
    check("history (CHANGELOG.md) is NOT rewritten",
          "skills/fx/references/output-format-template.md" in s("CHANGELOG.md"))
    check("emptied assets/ folder removed", not (root / sk / "assets").exists())
    check("migrated skill is clean under lint-skill-layout", LAYOUT.lint_skill(root / sk) == [])
    check("second plan is a no-op (idempotent)", M.plan_skill(root / sk)["moves"] == [])

# --- a destination clash is skipped, never overwritten ----------------------
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    write(root, "skills/fy/SKILL.md", "---\nname: fy\n---\nreferences/worked-example.md examples/worked-example.md\n")
    write(root, "skills/fy/references/worked-example.md", "A\n")
    write(root, "skills/fy/examples/worked-example.md", "B\n")
    plan = M.plan_skill(root / "skills/fy")
    check("destination clash is skipped, not planned", plan["moves"] == [] and plan["skipped"])

# --- CLI guard ---------------------------------------------------------------
check("--all --apply is refused (one skill per issue)", M.main(["--all", "--apply"]) == 2)

print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
