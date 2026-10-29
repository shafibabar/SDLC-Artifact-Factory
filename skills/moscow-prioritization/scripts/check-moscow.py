#!/usr/bin/env python3
"""check-moscow.py — mechanical checks on a MoSCoW prioritisation.

Owned by the moscow-prioritization skill. Deterministic checks only; it makes
no judgement about whether a story truly has a workaround or which story hurts
more. The agent applying the skill fixes what it reports.

Usage:
    check-moscow.py <file> [--story-map <story-map.md>] [--backlog <user-stories.md>]

<file> is either ideate/moscow.md (standard, enterprise) or, at lean, the
backlog ideate/user-stories.md whose closing Must / Won't-this-time block is
the prioritisation. The mode follows the frontmatter name.

Checks, ideate/moscow.md (name: moscow-prioritized-backlog):
  1. Frontmatter has name, version, phase, owner, created, summary and
     profile; phase is "ideate"; profile is standard or enterprise (at lean
     there is no moscow.md).
  2. Sections: Prioritisation Agreement, Must Have, Should Have, Could Have,
     Won't Have this time, Contingency and Skeleton Check; enterprise also
     Priority Levels and Priority Change Log.
  3. Every Must row has a "Why Must" reason and a Workaround cell starting
     with "none" (DSDM's workaround clause).
  4. Every Won't row has a reason and a look-again point.
  5. No story is in two bins.
  6. The Contingency is a numbered list holding exactly the Should and Could
     stories (a droppable tier exists); warning if a Could comes after a Should.
  7. No estimates: no "<n> person-weeks", "<n> story points", capacity
     percentage or must-capacity field.
Checks, lean backlog (name: user-story-backlog):
  8. Profile is lean; the last "##" section is the "Must / Won't-this-time"
     block with a Must table of at least one row, a "Won't this time" table
     whose rows have a reason and a look-again point, a Contingency line and
     a Learning checkpoint line.
Both:
  9. --story-map: the Must stories equal the story map's walking-skeleton
     stories, both ways (D045: Must = Minimum Usable SubseT = walking skeleton).
 10. --backlog (moscow.md) or the file itself (lean): every story in the
     backlog is placed exactly once (a bin, or at lean Must / Won't /
     contingency).

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "profile"]
STORY = re.compile(r"\bUS-\d+[a-z]?\b")
ESTIMATE = re.compile(
    r"\d+(\.\d+)?\s*(person[- ]?weeks?|person[- ]?days?|story[- ]?points?|pts)\b"
    r"|must[-_ ]capacity|%\s*of\s*(the\s*)?(release'?s?\s*)?capacity",
    re.I,
)
EMPTY = {"", "—", "–", "-", "n/a", "tbd"}


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


def section(body, prefix, level=2):
    hashes = "#" * level
    m = re.search(r"^" + hashes + r"\s+" + prefix + r"[^\n]*\n(.*?)(?=^#{1," + str(level) + r"}\s|\Z)",
                  body, re.M | re.S | re.I)
    return m.group(1) if m else None


def table(sec):
    rows = [ln for ln in (sec or "").splitlines() if ln.strip().startswith("|")]
    rows = [r for r in rows if not re.match(r"^\s*\|[\s:|-]+\|\s*$", r)]
    return [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows][1:]  # drop header


def ids(cell):
    """Story IDs in a cell, ignoring parenthetical notes such as '(manual: … US-4 list)'."""
    return STORY.findall(re.sub(r"\([^)]*\)", "", cell))


def num(sid):
    return int(re.sub(r"\D", "", sid))


def skeleton_ids(path):
    text = open(path, encoding="utf-8").read()
    sec = section(text, "Story Map") or ""
    for r in table(sec):
        if r and re.search(r"walking skeleton", r[0], re.I):
            out = set()
            for c in r[1:]:
                out.update(ids(c))
            return out
    return None


def backlog_ids(path):
    text = open(path, encoding="utf-8").read()
    return set(re.findall(r"^#{3,4}\s+(US-\d+[a-z]?)\b", text, re.M))


def two_way(musts, story_map, errors):
    skel = skeleton_ids(story_map)
    if skel is None:
        errors.append(f"no 'Walking skeleton' row in the Story Map table of {story_map}")
        return
    for sid in sorted(musts - skel, key=num):
        errors.append(f"{sid} is a Must but not on the walking skeleton — demote it, or add it to the skeleton if legal, safety or regulatory")
    for sid in sorted(skel - musts, key=num):
        errors.append(f"{sid} is on the walking skeleton but not a Must — Must = Minimum Usable SubseT = walking skeleton (or move it off and name the manual cell)")


def check_moscow(fm, body, story_map, backlog):
    errors, warnings = [], []
    profile = (fm.get("profile") or "").lower()
    if fm.get("name") and fm["name"] != "moscow-prioritized-backlog":
        errors.append(f"frontmatter: name is '{fm['name']}', expected 'moscow-prioritized-backlog'")
    if profile == "lean":
        errors.append("lean: there is no moscow.md — close ideate/user-stories.md with the Must / Won't-this-time block instead")
        return errors, warnings
    if profile and profile not in ("standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not standard or enterprise")

    needed = [("Prioriti[sz]ation Agreement", "Prioritisation Agreement"), ("Must Have", "Must Have"),
              ("Should Have", "Should Have"), ("Could Have", "Could Have"),
              ("Won.t Have this time", "Won't Have this time"), ("Contingency", "Contingency"),
              ("Skeleton Check", "Skeleton Check")]
    if profile == "enterprise":
        needed += [("Priority Levels", "Priority Levels"), ("Priority Change Log", "Priority Change Log")]
    secs = {}
    for rx, label in needed:
        secs[label] = section(body, rx)
        if secs[label] is None:
            errors.append(f"no '## {label}' section")

    bins = {}
    for label in ("Must Have", "Should Have", "Could Have", "Won't Have this time"):
        bins[label] = []
        for r in table(secs.get(label)):
            bins[label].append((set(ids(r[0])) if r else set(), r))

    musts = set()
    for sids, r in bins["Must Have"]:
        if not sids:
            continue
        musts |= sids
        name = ", ".join(sorted(sids, key=num))
        why = r[2] if len(r) > 2 else ""
        work = r[3] if len(r) > 3 else ""
        if why.lower() in EMPTY:
            errors.append(f"Must {name}: no 'Why Must' reason (a DSDM signal: no point delivering, illegal, unsafe, not viable)")
        if not work.lower().startswith("none"):
            errors.append(f"Must {name}: Workaround is '{work or 'blank'}' — any workaround, even manual, means not a Must (write 'none', or demote it)")
    for sids, r in bins["Won't Have this time"]:
        if not sids:
            continue
        name = ", ".join(sorted(sids, key=num))
        if len(r) < 2 or r[1].lower() in EMPTY:
            errors.append(f"Won't {name}: no reason (often the workaround)")
        if len(r) < 3 or r[2].lower() in EMPTY:
            errors.append(f"Won't {name}: no look-again point (a release or a trigger)")

    placed = {}
    for label, rows in bins.items():
        for sids, _ in rows:
            for sid in sids:
                placed.setdefault(sid, []).append(label)
    for sid in sorted(placed, key=num):
        if len(placed[sid]) > 1:
            errors.append(f"{sid} is in more than one bin: {', '.join(placed[sid])}")

    should = {s for sids, _ in bins["Should Have"] for s in sids}
    could = {s for sids, _ in bins["Could Have"] for s in sids}
    cont = secs.get("Contingency")
    if cont is not None:
        items = re.findall(r"^\s*\d+\.\s+(.*)$", cont, re.M)
        if not items:
            errors.append("Contingency has no numbered cut order — there must be a droppable Should / Could tier, listed in the order it would be cut")
        listed, order = set(), []
        for it in items:
            for sid in STORY.findall(re.sub(r"\([^)]*\)", "", it.split("—")[0])):
                listed.add(sid)
                order.append(sid)
        if items and not (should | could):
            errors.append("no Should or Could stories — the release has no contingency; put the scope decision to the product owner")
        for sid in sorted((should | could) - listed, key=num):
            errors.append(f"{sid} is a Should or Could but not in the Contingency cut order")
        for sid in sorted(listed - (should | could), key=num):
            errors.append(f"{sid} is in the Contingency but is not a Should or Could")
        seen_should = False
        for sid in order:
            if sid in should:
                seen_should = True
            elif sid in could and seen_should:
                warnings.append(f"{sid} (Could) is cut after a Should — Coulds normally go first")
                break

    if story_map:
        two_way(musts, story_map, errors)
    if backlog:
        bl = backlog_ids(backlog)
        for sid in sorted(bl - set(placed), key=num):
            errors.append(f"{sid} is in the backlog but in no bin")
        for sid in sorted(set(placed) - bl, key=num):
            warnings.append(f"{sid} is binned but not in the backlog")
    return errors, warnings


def check_lean(fm, body, story_map):
    errors, warnings = [], []
    profile = (fm.get("profile") or "").lower()
    if profile != "lean":
        errors.append(f"{profile or 'unknown profile'}: the backlog carries no Must / Won't block — moscow-prioritization writes ideate/moscow.md")
        return errors, warnings
    heads = list(re.finditer(r"^##\s+([^\n]*)$", body, re.M))
    if not heads or not re.match(r"Must / Won.t-this-time", heads[-1].group(1), re.I):
        if any(re.match(r"Must / Won.t-this-time", h.group(1), re.I) for h in heads):
            errors.append("lean: the Must / Won't-this-time block must close the backlog (last '##' section)")
        else:
            errors.append("lean: no closing '## Must / Won't-this-time' block — it finalises the provisional priorities")
        return errors, warnings
    block = body[heads[-1].end():]
    must_sec = section(block, r"Must\b", level=3)
    wont_sec = section(block, r"Won.t this time", level=3)
    musts = set()
    if must_sec is None:
        errors.append("lean: the block has no '### Must' table")
    else:
        rows = table(must_sec)
        if not rows:
            errors.append("lean: the Must table is empty — the walking skeleton needs a story or named manual step per journey step")
        for r in rows:
            cell = r[1] if len(r) > 1 else ""
            if cell.lower() in EMPTY:
                errors.append(f"lean: Must step '{r[0]}' has no story or named manual step — the skeleton does not walk")
            musts.update(ids(cell))
    wonts = set()
    if wont_sec is None:
        errors.append("lean: the block has no '### Won't this time' table")
    else:
        for r in table(wont_sec):
            sids = set(ids(r[0])) if r else set()
            wonts |= sids
            name = ", ".join(sorted(sids, key=num)) or r[0]
            if len(r) < 2 or r[1].lower() in EMPTY:
                errors.append(f"lean: Won't {name}: no reason (often the workaround)")
            if len(r) < 3 or r[2].lower() in EMPTY:
                errors.append(f"lean: Won't {name}: no look-again point")
    cm = re.search(r"^Contingency.*?(?=\n\s*\n|\Z)", block, re.M | re.S)
    if not cm:
        errors.append("lean: no 'Contingency' line after the tables")
    if not re.search(r"^Learning checkpoint", block, re.M):
        errors.append("lean: no 'Learning checkpoint' line")
    if re.search(r"\b(Should Have|Could Have)\b|^###\s+(Should|Could)\b", block, re.M):
        errors.append("lean: no Should / Could labels — the contingency keeps its provisional priorities")
    cont = set(STORY.findall(cm.group(0))) if cm else set()
    if story_map:
        two_way(musts, story_map, errors)
    all_ids = set(re.findall(r"^#{3,4}\s+(US-\d+[a-z]?)\b", body, re.M))
    for sid in sorted(all_ids - (musts | wonts | cont), key=num):
        errors.append(f"{sid} is in the backlog but not in the closing block (Must, Won't this time or contingency)")
    for sid in sorted(musts & wonts, key=num):
        errors.append(f"{sid} is both a Must and a Won't")
    return errors, warnings


def check(text, story_map=None, backlog=None):
    fm, body = frontmatter(text)
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    errors = []
    if fm is None:
        return ["no frontmatter block"], []
    for k in REQUIRED_FM:
        if not fm.get(k):
            errors.append(f"frontmatter: missing '{k}'")
    if fm.get("phase") and fm["phase"].lower() != "ideate":
        errors.append(f"frontmatter: phase is '{fm['phase']}', MoSCoW runs in Ideate (phase: ideate)")
    for ln in body.splitlines():
        if ESTIMATE.search(ln):
            errors.append(f"estimate found ('{ln.strip()[:60]}') — the plugin has no person-week or point estimates; use the structural checks")
            break
    if fm.get("name") == "user-story-backlog":
        e, w = check_lean(fm, body, story_map)
    else:
        e, w = check_moscow(fm, body, story_map, backlog)
    return errors + e, w


def main(argv):
    args = argv[1:]
    opts = {}
    for flag in ("--story-map", "--backlog"):
        if flag in args:
            i = args.index(flag)
            if i + 1 >= len(args):
                print(f"ERROR: {flag} needs a file")
                return 2
            opts[flag] = args[i + 1]
            del args[i:i + 2]
    if len(args) != 1:
        print(__doc__.split("Checks,")[0].strip())
        return 2
    try:
        text = open(args[0], encoding="utf-8").read()
        for f in opts.values():
            open(f, encoding="utf-8").close()
    except OSError as e:
        print(f"ERROR: cannot read input: {e}")
        return 2
    errors, warnings = check(text, opts.get("--story-map"), opts.get("--backlog"))
    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
