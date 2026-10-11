#!/usr/bin/env python3
"""
scripts/lint-skill-layout.py — the Fresh-Eyes folder-spec linter (closes #1227).

Checks every skills/<name>/ directory against the progressive-disclosure folder
spec (skill-authoring-standards): one entry file SKILL.md, plus only the
optional folders in manifest.SKILL_SUBDIRS, each holding content the agent is
actually pointed to.

RULES (each finding carries its code):
  L1 entry       the skill root holds exactly one file, named SKILL.md
                 (uppercase). Any other file at the root is a finding.
  L2 folder      every subfolder at the root is one of manifest.SKILL_SUBDIRS.
  L3 empty       no empty directories anywhere in the skill ("do not
                 proactively generate empty folders").
  L4 unreachable every file under a subfolder is reachable from SKILL.md by
                 following pointers transitively: a folder-rooted path
                 (`references/x.md`, `./templates/y.md`, `$SKILL_DIR/assets/z`)
                 resolved against the skill root, or a markdown link /
                 `./file` resolved against the pointing file's own directory.
                 A file nothing points to is dead weight the agent never loads.
  L5 path        no hard-coded pointer to skill content: `CLAUDE_PLUGIN_ROOT`
                 used to address skills/, an absolute path into a skills/ tree,
                 or a repo-rooted
                 `skills/<name>/<folder-or-SKILL.md>` (own or another skill's).
                 Pointers are relative to the skill's own root, so the skill
                 works wherever it is installed. Absolute-looking strings that
                 are example CONTENT (a `/home/ci-runner/` stack trace, a
                 Dockerfile `/app`) are deliberately not matched.

POLICY: REPORT-ONLY in scripts/lint-all.sh until the Fresh-Eyes waves have
migrated every skill, then flipped to BLOCKING. The script itself exits 1 when
it finds anything, so the flip is a one-word change in the gate.

Usage:
  python3 scripts/lint-skill-layout.py                 # all skills, summary + findings
  python3 scripts/lint-skill-layout.py --skill <name>  # one skill
  python3 scripts/lint-skill-layout.py --json          # machine-readable
  python3 scripts/lint-skill-layout.py --summary       # totals only

Importable API (used by tests/arch/lint-skill-layout.test.py):
  lint_skill(skill_dir: Path) -> list[dict]   pure: reads files, never writes
  lint(skills_dir: Path) -> dict              {"skills": {name: [...]}, "totals": {...}}
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

_ARCH = Path(__file__).resolve().parent / "arch"
sys.path.insert(0, str(_ARCH))
import manifest  # noqa: E402  (scripts/arch/manifest.py — the shared parser)

REPO_ROOT = manifest.REPO_ROOT
SKILLS_DIR = manifest.SKILLS_DIR
ALLOWED = manifest.SKILL_SUBDIRS
RULES = ("L1", "L2", "L3", "L4", "L5")

_FOLDERS = "|".join(re.escape(d) for d in ALLOWED)
# A folder-rooted pointer: `references/x.md`, `./templates/y.md`,
# `$SKILL_DIR/assets/z`. The lookbehind only refuses a word-ish character, so a
# preceding `/` (as in `$SKILL_DIR/` or `./`) still matches.
_ROOTED_RE = re.compile(rf"(?<![A-Za-z0-9_-])(?:{_FOLDERS})/[A-Za-z0-9_./-]*[A-Za-z0-9_-]")
# Pointers relative to the pointing file: markdown links and `./name.ext`.
_MDLINK_RE = re.compile(r"\]\(([^)\s#]+)(?:#[^)]*)?\)")
_DOTSLASH_RE = re.compile(r"(?<![A-Za-z0-9_./-])\./([A-Za-z0-9_][A-Za-z0-9_./-]*\.[A-Za-z0-9]+)")
# A sibling file named bare inside backticks, e.g. `timeout-standard.md`,
# resolved against the pointing file's own directory — the way reference files
# conventionally cite each other.
_BACKTICK_SIBLING_RE = re.compile(r"`([A-Za-z0-9_][A-Za-z0-9_.-]*\.(?:md|sh|py|yaml|yml|json|feature|txt))`")
# What the spec forbids is a HARD-CODED POINTER to skill files, not every
# absolute-looking string: a skill legitimately shows `/home/ci-runner/...` in
# a stack-trace example or `/app` in a Dockerfile. So L5 matches only paths
# that address skill content from outside the skill's own root.
#
# CLAUDE_PLUGIN_ROOT is matched only when it addresses skills/: it remains the
# correct (and only) way for a skill to invoke the plugin's own repo-root
# scripts (e.g. memory-recall -> scripts/memory/), which are not skill content.
_PATH_RES = (
    ("plugin-root path into skills/", re.compile(r"CLAUDE_PLUGIN_ROOT\}?/skills/")),
    ("absolute path into a skills/ tree", re.compile(
        rf"(?:/[A-Za-z0-9_.-]+)+/skills/[a-z0-9-]+/(?:SKILL\.md|{_FOLDERS})\b")),
    ("repo-rooted skill path", re.compile(
        rf"(?<![A-Za-z0-9_./-])skills/[a-z0-9-]+/(?:SKILL\.md|{_FOLDERS})\b")),
)
_MAX_TEXT_BYTES = 1_000_000


def _read_text(path: Path) -> str | None:
    """Text content of a file, or None for binary / oversized files."""
    try:
        if path.stat().st_size > _MAX_TEXT_BYTES:
            return None
        data = path.read_bytes()
    except OSError:
        return None
    if b"\x00" in data[:4096]:
        return None
    return data.decode("utf-8", errors="replace")


def _pointers(text: str, skill_root: Path, here: Path) -> set[Path]:
    """Every existing file a piece of text points at, as resolved paths."""
    found: set[Path] = set()
    for m in _ROOTED_RE.finditer(text):
        found.add((skill_root / m.group(0)).resolve())
    for m in _MDLINK_RE.finditer(text):
        target = m.group(1)
        if "://" in target or target.startswith("mailto:"):
            continue
        found.add((here / target).resolve())
        # A link written folder-rooted from inside a subfolder file resolves
        # against the skill root too (the convention SKILL.md bodies use).
        found.add((skill_root / target).resolve())
    for m in _DOTSLASH_RE.finditer(text):
        found.add((here / m.group(1)).resolve())
    for m in _BACKTICK_SIBLING_RE.finditer(text):
        found.add((here / m.group(1)).resolve())
    return {p for p in found if p.is_file()}


def _finding(rule: str, path: Path, skill_root: Path, message: str) -> dict:
    rel = path.relative_to(skill_root.parent.parent) if path.is_relative_to(skill_root.parent.parent) else path
    return {"rule": rule, "path": rel.as_posix(), "message": message}


def lint_skill(skill_root: Path) -> list[dict]:
    """All layout findings for one skill directory. Pure (read-only)."""
    findings: list[dict] = []
    skill_root = skill_root.resolve()
    entry = skill_root / "SKILL.md"

    # L1 / L2 — what sits at the root
    for child in sorted(skill_root.iterdir()):
        if child.is_file() and child.name != "SKILL.md":
            hint = " (the entry file must be exactly SKILL.md)" if child.name.lower() == "skill.md" else ""
            findings.append(_finding("L1", child, skill_root,
                                     f"file at skill root other than SKILL.md{hint}"))
        elif child.is_dir() and child.name not in ALLOWED:
            findings.append(_finding("L2", child, skill_root,
                                     f"folder '{child.name}' is not one of: {', '.join(ALLOWED)}"))
    if not entry.is_file():
        findings.append(_finding("L1", entry, skill_root, "missing SKILL.md entry file"))
        return findings

    # L3 — empty directories anywhere
    for d in sorted(p for p in skill_root.rglob("*") if p.is_dir()):
        if not any(d.iterdir()):
            findings.append(_finding("L3", d, skill_root, "empty directory"))

    # L4 — reachability from SKILL.md, following pointers transitively
    content_files = sorted(
        p.resolve() for p in skill_root.rglob("*")
        if p.is_file() and p.resolve() != entry.resolve()
        and p.relative_to(skill_root).parts[0] in ALLOWED
    )
    reached: set[Path] = set()
    frontier = [entry.resolve()]
    while frontier:
        cur = frontier.pop()
        text = _read_text(cur)
        if text is None:
            continue
        for target in _pointers(text, skill_root, cur.parent):
            if target not in reached and target.is_relative_to(skill_root):
                reached.add(target)
                frontier.append(target)
    for f in content_files:
        if f not in reached:
            findings.append(_finding("L4", f, skill_root,
                                     "not reachable from SKILL.md by any relative pointer"))

    # L5 — absolute / repo-rooted paths in any text file of the skill
    for f in [entry.resolve(), *content_files]:
        text = _read_text(f)
        if text is None:
            continue
        for label, rx in _PATH_RES:
            hits = sorted({m.group(0) for m in rx.finditer(text)})
            if hits:
                shown = ", ".join(hits[:3]) + (f" (+{len(hits) - 3} more)" if len(hits) > 3 else "")
                findings.append(_finding("L5", f, skill_root, f"{label}: {shown}"))
    return findings


def lint(skills_dir: Path = SKILLS_DIR) -> dict:
    """Lint every skill under skills_dir. Pure."""
    per_skill: dict[str, list[dict]] = {}
    for d in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
        per_skill[d.name] = lint_skill(d)
    totals = {r: sum(1 for fs in per_skill.values() for f in fs if f["rule"] == r) for r in RULES}
    totals["skills"] = len(per_skill)
    totals["skills_clean"] = sum(1 for fs in per_skill.values() if not fs)
    totals["findings"] = sum(len(fs) for fs in per_skill.values())
    return {"skills": per_skill, "totals": totals}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Lint skills against the folder spec.")
    ap.add_argument("--skill", help="lint one skill by name")
    ap.add_argument("--json", action="store_true", help="print the full result as JSON")
    ap.add_argument("--summary", action="store_true", help="print totals only")
    args = ap.parse_args(argv)

    if args.skill:
        d = SKILLS_DIR / args.skill
        if not d.is_dir():
            print(f"no such skill: {args.skill}", file=sys.stderr)
            return 2
        fs = lint_skill(d)
        result = {"skills": {args.skill: fs},
                  "totals": {**{r: sum(1 for f in fs if f["rule"] == r) for r in RULES},
                             "skills": 1, "skills_clean": int(not fs), "findings": len(fs)}}
    else:
        result = lint()

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
        return 1 if result["totals"]["findings"] else 0

    t = result["totals"]
    if not args.summary:
        for name, fs in result["skills"].items():
            for f in fs:
                print(f"{f['rule']}  {f['path']}: {f['message']}")
        if t["findings"]:
            print("")
    print("lint-skill-layout summary:")
    print(f"  skills clean   {t['skills_clean']}/{t['skills']}")
    labels = {"L1": "entry file", "L2": "folder names", "L3": "empty dirs",
              "L4": "unreachable", "L5": "non-relative paths"}
    for r in RULES:
        print(f"  {r} {labels[r]:<18} {t[r]}")
    print(f"  TOTAL          {t['findings']} finding(s)")
    return 1 if t["findings"] else 0


if __name__ == "__main__":
    sys.exit(main())
