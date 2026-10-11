#!/usr/bin/env python3
"""
scripts/arch/migrate-skill-layout.py — move a skill's files into the Fresh-Eyes
folder spec and rewrite every pointer the move breaks (closes #1229).

DRY-RUN BY DEFAULT. It prints a plan; --apply executes it. It is a mechanical
helper for the per-skill refactor issues (Phase B/C), not a bulk migration:
each skill's issue runs it, reviews the result, and keeps or reverts it.

MOVE RULES — only unambiguous, name-based moves; everything else is a judgment
call for the person refactoring the skill, reported as REVIEW:
  assets/*template*|*canvas*  (.md .feature .yaml .yml .json) -> templates/
  references/output-format-template.md, references/*-template.md -> templates/
  references/worked-example*.md, references/worked-*.md          -> examples/
Mixed files (e.g. `mission-examples-and-template.md`) are NEVER moved — a file
that is half template and half guidance has to be split by a person.

POINTER REWRITES after the moves:
  inside the skill  folder-rooted pointers (`references/x.md`, `./references/x.md`,
                    `$SKILL_DIR/assets/x.md`) to a moved file are repointed;
                    bare sibling references (`` `x.md` ``, `](x.md)`) that the
                    move turned into cross-folder references become `../<folder>/x.md`.
  outside the skill repo-rooted `skills/<name>/<old>` in commands/, agents/,
                    tests/, other skills, CLAUDE.md, README.md is repointed.
                    History (CHANGELOG.md, research/, discovery/, .sdlc-memory/,
                    generated/) is deliberately left alone — it records what was
                    true then.
A source folder emptied by the moves is removed (the spec forbids empty dirs).

Usage:
  python3 scripts/arch/migrate-skill-layout.py <skill> [<skill> ...]   # dry-run
  python3 scripts/arch/migrate-skill-layout.py <skill> --apply
  python3 scripts/arch/migrate-skill-layout.py --all                   # dry-run survey

Importable API (tests/arch/migrate-skill-layout.test.py):
  plan_skill(skill_dir) -> dict           pure
  apply_plan(plan, repo_root) -> dict     performs moves + rewrites
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import manifest  # noqa: E402

REPO_ROOT = manifest.REPO_ROOT
SKILLS_DIR = manifest.SKILLS_DIR
TEXT_EXT = {".md", ".sh", ".py", ".yaml", ".yml", ".json", ".feature", ".txt"}
EXTERNAL_ROOTS = ("commands", "agents", "tests", "skills", "CLAUDE.md", "README.md")

_TEMPLATE_ASSET = re.compile(r"(template|canvas)", re.I)
_TEMPLATE_ASSET_EXT = {".md", ".feature", ".yaml", ".yml", ".json"}
_REF_TEMPLATE = re.compile(r"^(output-format-template|[a-z0-9-]+-template)\.md$")
_REF_EXAMPLE = re.compile(r"^worked-[a-z0-9-]+\.md$|^worked-examples?\.md$")
_REVIEW_HINT = re.compile(r"(template|example|checklist|rules?|catalog|canvas|glossary|dictionary)", re.I)


def _is_mixed(name: str) -> bool:
    """A name that announces two kinds of content ('-and-', or both template
    and example) is a file a person must split — never auto-moved."""
    low = name.lower()
    return "-and-" in low or ("template" in low and "example" in low)


def _rule_for(rel: Path) -> str | None:
    """Destination folder for a skill-relative file, or None to leave it."""
    if len(rel.parts) != 2:
        return None
    folder, name = rel.parts
    if _is_mixed(name):
        return None
    if folder == "assets" and _TEMPLATE_ASSET.search(name) and rel.suffix in _TEMPLATE_ASSET_EXT:
        return "templates"
    if folder == "references" and _REF_TEMPLATE.match(name):
        return "templates"
    if folder == "references" and _REF_EXAMPLE.match(name):
        return "examples"
    return None


def plan_skill(skill_dir: Path) -> dict:
    """Pure: what would move, and what needs a person's judgment."""
    skill_dir = skill_dir.resolve()
    moves: list[tuple[str, str]] = []
    review: list[str] = []
    skipped: list[str] = []
    for f in sorted(p for p in skill_dir.rglob("*") if p.is_file()):
        rel = f.relative_to(skill_dir)
        if rel.parts[0] == "SKILL.md":
            continue
        dest = _rule_for(rel)
        if dest:
            new = Path(dest) / rel.name
            if (skill_dir / new).exists():
                skipped.append(f"{rel.as_posix()} -> {new.as_posix()} (destination exists)")
            else:
                moves.append((rel.as_posix(), new.as_posix()))
        elif rel.parts[0] in ("references", "assets") and _REVIEW_HINT.search(rel.name):
            review.append(rel.as_posix())
    return {"skill": skill_dir.name, "dir": skill_dir, "moves": moves,
            "review": review, "skipped": skipped}


def _is_text(p: Path) -> bool:
    return p.is_file() and p.suffix in TEXT_EXT


def _rewrite_inside(text: str, here_folder: str, moves: dict[str, str]) -> str:
    """Repoint pointers inside one skill file. `here_folder` is the file's
    folder AFTER the move ("" for SKILL.md at the root)."""
    for old, new in moves.items():
        # folder-rooted: references/x.md, ./references/x.md, $SKILL_DIR/assets/x.md
        # A following '.' only blocks the match when it continues a filename
        # (`x.md.bak`), not when it ends the sentence (`see x.md.`).
        text = re.sub(rf"(?<![A-Za-z0-9_-]){re.escape(old)}(?![A-Za-z0-9_-]|\.[A-Za-z0-9])", new, text)
        old_folder, name = old.split("/", 1)
        new_folder = new.split("/", 1)[0]
        if here_folder and here_folder != new_folder:
            # a bare sibling pointer that is now cross-folder
            target = f"../{new}"
            text = re.sub(rf"`{re.escape(name)}`", f"`{target}`", text)
            text = re.sub(rf"\]\({re.escape(name)}\)", f"]({target})", text)
    return text


def _sibling_fix_for_moved(text: str, moved_from: str, moved_to: str, remaining: set[str]) -> str:
    """A moved file's bare pointers to files that stayed in its old folder."""
    from_folder, to_folder = moved_from.split("/", 1)[0], moved_to.split("/", 1)[0]
    if from_folder == to_folder:
        return text
    for rel in remaining:
        if "/" not in rel:          # SKILL.md at the root is never a sibling
            continue
        folder, name = rel.split("/", 1)
        if folder != from_folder:
            continue
        text = re.sub(rf"(?<![./])`{re.escape(name)}`", f"`../{rel}`", text)
        text = re.sub(rf"\]\({re.escape(name)}\)", f"](../{rel})", text)
    return text


def apply_plan(plan: dict, repo_root: Path = REPO_ROOT) -> dict:
    """Perform the moves and every pointer rewrite. Returns what changed."""
    skill_dir: Path = plan["dir"]
    moves = dict(plan["moves"])
    if not moves:
        return {"moved": 0, "rewritten": []}
    pre_files = {p.relative_to(skill_dir).as_posix() for p in skill_dir.rglob("*") if p.is_file()}

    for old, new in moves.items():
        dst = skill_dir / new
        dst.parent.mkdir(parents=True, exist_ok=True)
        (skill_dir / old).rename(dst)
    remaining = (pre_files - set(moves)) | set()

    rewritten: list[str] = []
    for f in sorted(p for p in skill_dir.rglob("*") if _is_text(p)):
        rel = f.relative_to(skill_dir).as_posix()
        here = "" if "/" not in rel else rel.split("/", 1)[0]
        before = f.read_text(encoding="utf-8", errors="replace")
        after = _rewrite_inside(before, here, moves)
        moved_from = next((o for o, n in moves.items() if n == rel), None)
        if moved_from:
            after = _sibling_fix_for_moved(after, moved_from, rel, remaining)
        if after != before:
            f.write_text(after, encoding="utf-8")
            rewritten.append(f.relative_to(repo_root).as_posix() if f.is_relative_to(repo_root) else rel)

    # repo-rooted pointers elsewhere in the repo (never history files)
    name = plan["skill"]
    external = {f"skills/{name}/{o}": f"skills/{name}/{n}" for o, n in moves.items()}
    for root in EXTERNAL_ROOTS:
        base = repo_root / root
        files = [base] if base.is_file() else (sorted(p for p in base.rglob("*") if _is_text(p)) if base.is_dir() else [])
        for f in files:
            if f.is_relative_to(skill_dir):
                continue
            before = f.read_text(encoding="utf-8", errors="replace")
            after = before
            for o, n in external.items():
                after = after.replace(o, n)
            if after != before:
                f.write_text(after, encoding="utf-8")
                rewritten.append(f.relative_to(repo_root).as_posix())

    for d in sorted((p for p in skill_dir.rglob("*") if p.is_dir()), key=lambda p: -len(p.parts)):
        if not any(d.iterdir()):
            d.rmdir()
    return {"moved": len(moves), "rewritten": rewritten}


def _print_plan(plan: dict) -> None:
    print(f"== {plan['skill']}")
    for o, n in plan["moves"]:
        print(f"  MOVE    {o} -> {n}")
    for s in plan["skipped"]:
        print(f"  SKIP    {s}")
    for r in plan["review"]:
        print(f"  REVIEW  {r}  (mixed or ambiguous — decide its folder by hand)")
    if not (plan["moves"] or plan["skipped"] or plan["review"]):
        print("  nothing to move")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Move a skill's files into the folder spec.")
    ap.add_argument("skills", nargs="*", help="skill name(s)")
    ap.add_argument("--all", action="store_true", help="survey every skill (dry-run only)")
    ap.add_argument("--apply", action="store_true", help="perform the moves and rewrites")
    args = ap.parse_args(argv)
    if args.all and args.apply:
        print("refusing --all --apply: migrate skills one issue at a time", file=sys.stderr)
        return 2
    names = sorted(p.name for p in SKILLS_DIR.iterdir() if p.is_dir()) if args.all else args.skills
    if not names:
        ap.print_usage(sys.stderr)
        return 2
    total_moves = 0
    for name in names:
        d = SKILLS_DIR / name
        if not d.is_dir():
            print(f"no such skill: {name}", file=sys.stderr)
            return 2
        plan = plan_skill(d)
        total_moves += len(plan["moves"])
        if args.all and not (plan["moves"] or plan["review"] or plan["skipped"]):
            continue
        _print_plan(plan)
        if args.apply:
            res = apply_plan(plan)
            print(f"  applied: {res['moved']} moved, {len(res['rewritten'])} file(s) rewritten")
            for r in res["rewritten"]:
                print(f"    rewrote {r}")
    if not args.apply:
        print(f"\n(dry run — {total_moves} move(s) planned; re-run with --apply to execute)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
