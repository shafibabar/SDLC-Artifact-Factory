#!/usr/bin/env python3
"""check-story-map.py — mechanical checks on a user story map (ideate/story-map.md).

Owned by the story-mapping skill. Deterministic checks only; it makes no
judgement about whether the backbone narrates well or a slice is the right
cut. The agent applying the skill fixes what it reports.

Usage:
    check-story-map.py <story-map.md> [--backlog <user-stories.md>] [--musts <file>]

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary and
     profile; phase is "ideate"; profile is lean, standard or enterprise.
  2. Sections: Narrated Spine and Story Map always; standard and enterprise
     also Big Picture, Release Slices, Must Check and Gaps; enterprise also
     Re-cut Log.
  3. The Story Map table has a "Walking skeleton" row and every activity
     cell in it is filled (a story, "(existing: …)" or "(manual: …)"),
     never blank or "—".
  4. Standard and enterprise: at least one release row below the skeleton,
     and the Release Slices section calls the MVP a release-MVP; each
     "### Release" slice has Outcome, Signal and Re-cut trigger lines.
  5. No story ID appears in two cells of the map.
  6. --backlog: every US-n in the backlog is on the map (else an orphan,
     an error); a map story missing from the backlog is a warning (a
     proposed gap story awaiting the user).
  7. --musts: the US-n listed under the file's "Must" heading equal the
     skeleton row's stories, both ways (D045: Must = Minimum Usable SubseT
     = walking skeleton).
  8. Warning: an activity named after a system stage (ingest, process,
     store, serve, persist, parse, index, pipeline, etl).

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "profile"]
STORY = re.compile(r"\bUS-\d+[a-z]?\b")
SYSTEM = re.compile(r"\b(ingest\w*|process\w*|stor(e|age)|serv(e|ing)|persist\w*|pars(e|ing)|index\w*|pipeline|etl)\b", re.I)
EMPTY = {"", "—", "–", "-", "n/a"}


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    fm = {}
    for ln in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_-]+):\s*(.*)$", ln)
        if km:
            fm[km.group(1).lower()] = km.group(2).strip()
    return fm, text[m.end():]


def section(body, prefix):
    """Text of the first '## <prefix>…' section, or None."""
    m = re.search(r"^##\s+" + re.escape(prefix) + r"[^\n]*\n(.*?)(?=^##\s|\Z)", body, re.M | re.S | re.I)
    return m.group(1) if m else None


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def ids(cell):
    """Story IDs in a cell, ignoring parenthetical notes such as '(manual: … US-4 list)'."""
    return STORY.findall(re.sub(r"\([^)]*\)", "", cell))


def table(sec):
    rows = [ln for ln in sec.splitlines() if ln.strip().startswith("|")]
    rows = [r for r in rows if not re.match(r"^\s*\|[\s:|-]+\|\s*$", r)]
    return [cells(r) for r in rows]


def story_ids_in(path, heading=None):
    text = open(path, encoding="utf-8").read()
    if heading:
        m = re.search(r"^#{2,4}\s+" + heading + r"\b[^\n]*\n(.*?)(?=^#{2,4}\s|\Z)", text, re.M | re.S | re.I)
        text = m.group(1) if m else ""
    return set(STORY.findall(text))


def check(text, backlog=None, musts=None):
    errors, warnings = [], []
    fm, body = frontmatter(text)
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    if fm is None:
        errors.append("no frontmatter block")
        fm = {}
    else:
        for k in REQUIRED_FM:
            if not fm.get(k):
                errors.append(f"frontmatter: missing '{k}'")
        if fm.get("phase") and fm["phase"].lower() != "ideate":
            errors.append(f"frontmatter: phase is '{fm['phase']}', the story map is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile and profile not in ("lean", "standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not lean, standard or enterprise")
    full = profile in ("standard", "enterprise")

    needed = ["Narrated Spine", "Story Map"]
    if full:
        needed += ["Big Picture", "Release Slices", "Must Check", "Gaps"]
    if profile == "enterprise":
        needed.append("Re-cut Log")
    for name in needed:
        if section(body, name) is None:
            errors.append(f"no '## {name}' section")

    smap = section(body, "Story Map") or ""
    rows = table(smap)
    skeleton_ids = set()
    if rows:
        header = rows[0]
        activities = header[1:]
        for a in activities:
            if SYSTEM.search(a):
                warnings.append(f"activity '{a}' names a system stage — narrate what the persona does")
        skel = [r for r in rows[1:] if re.search(r"walking skeleton", r[0], re.I)]
        if not skel:
            errors.append("Story Map has no 'Walking skeleton' row")
        else:
            row = skel[0][1:]
            for i, a in enumerate(activities):
                c = row[i] if i < len(row) else ""
                if c.strip().lower() in EMPTY:
                    errors.append(f"walking skeleton is broken: no cell under '{a}' — add a story, '(existing: …)' or '(manual: …)'")
            for c in row:
                skeleton_ids.update(ids(c))
        releases = [r for r in rows[1:] if re.search(r"release\s*\d", r[0], re.I) and not re.search(r"walking skeleton", r[0], re.I)]
        if full and not releases:
            errors.append("no release slice below the walking skeleton (cut at least Release 2)")
        seen = {}
        for r in rows[1:]:
            for c in r[1:]:
                for sid in set(ids(c)):
                    seen[sid] = seen.get(sid, 0) + 1
        for sid, n in sorted(seen.items()):
            if n > 1:
                errors.append(f"{sid} is placed in {n} cells — a story sits in one place on the map")
        map_ids = set(seen)
    else:
        errors.append("Story Map has no table")
        map_ids = set()

    if full:
        rel = section(body, "Release Slices") or ""
        if rel and not re.search(r"release[- ]mvp", rel, re.I):
            errors.append("Release Slices does not state the MVP is a release-MVP (not a learning experiment)")
        for head, txt in re.findall(r"^###\s+(Release[^\n]*)\n(.*?)(?=^###\s|\Z)", rel, re.M | re.S):
            for label in ("Outcome", "Signal", "Re-cut trigger"):
                if not re.search(r"^\*\*" + label + r"[^*]*:\*\*\s*\S", txt, re.M | re.I):
                    errors.append(f"'{head.strip()}' has no {label} line")

    if backlog:
        bl = story_ids_in(backlog)
        for sid in sorted(bl - map_ids, key=lambda s: int(re.sub(r"\D", "", s))):
            errors.append(f"{sid} is in the backlog but not on the map (orphan — place it or challenge it)")
        for sid in sorted(map_ids - bl, key=lambda s: int(re.sub(r"\D", "", s))):
            warnings.append(f"{sid} is on the map but not in the backlog (a proposed gap story awaiting the user?)")
    if musts:
        ms = story_ids_in(musts, "Must")
        if not ms:
            errors.append(f"no story IDs under a 'Must' heading in {musts}")
        for sid in sorted(ms - skeleton_ids):
            errors.append(f"{sid} is a Must but not on the walking skeleton — demote it, or add it to the skeleton if legal, safety or regulatory")
        for sid in sorted(skeleton_ids - ms):
            errors.append(f"{sid} is on the walking skeleton but not a Must — Must = Minimum Usable SubseT = walking skeleton")
    return errors, warnings


def main(argv):
    args = argv[1:]
    opts = {}
    for flag in ("--backlog", "--musts"):
        if flag in args:
            i = args.index(flag)
            if i + 1 >= len(args):
                print(f"ERROR: {flag} needs a file")
                return 2
            opts[flag] = args[i + 1]
            del args[i:i + 2]
    if len(args) != 1:
        print(__doc__.split("Checks:")[0].strip())
        return 2
    try:
        text = open(args[0], encoding="utf-8").read()
        for f in opts.values():
            open(f, encoding="utf-8").close()
    except OSError as e:
        print(f"ERROR: cannot read input: {e}")
        return 2
    errors, warnings = check(text, opts.get("--backlog"), opts.get("--musts"))
    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
