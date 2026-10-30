#!/usr/bin/env python3
"""check-user-stories.py — mechanical checks on a user story backlog (ideate/user-stories.md).

Owned by the user-story-writing skill. Deterministic checks only; it makes no
judgement about whether a benefit is valuable or a split is right. The agent
applying the skill fixes what it reports.

Usage:
    check-user-stories.py <user-stories.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary and profile;
     name is "user-story-backlog"; phase is "ideate"; profile is lean,
     standard or enterprise.
  2. Each "### US-n" / "#### US-n" story has a card with "As a", "I want" and
     "so that" (or "so I can"); the actor is not "a user" or a system; the
     benefit does not merely repeat the want.
  3. Each story has a "Traces to" line citing a job story (JS-n.m); the epic
     (EPIC-n) when the file has epic headings; and at standard / enterprise a
     user or transition requirement (UR-n / TR-n).
  4. Each story has a "Priority (provisional)" line with no MoSCoW word, and a
     "Seed example" line. No Given/When/Then on the card, and no size, sprint,
     story-point or person-week field.
  5. A spike ("US-n: Spike: …") has a Question, an Output and an Unblocks line.
  6. Story IDs are unique.
  7. Lean: a "## Requirements Header" section, and the file closes with a
     "## Must / Won't-this-time" block holding "### Must" and "### Won't this
     time". Standard / enterprise: neither of those, and both a
     "## Backlog Summary" and a "## Coverage" section.
  8. Warnings: an implementation word in the want (endpoint, API, dropdown,
     modal, button, table, database, webhook).

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "profile"]
MOSCOW = re.compile(r"\b(must|should|could|won'?t)\b", re.I)
SIZEY = re.compile(r"\b(sprints?|story points?|person[- ]weeks?|person[- ]days?)\b", re.I)
GWT_LINE = re.compile(r"^\s*(?:[-*]\s*)?(?:\*\*)?(given|when|then)\b", re.I)
GWT_INLINE = re.compile(r"\bgiven\b.*\bwhen\b.*\bthen\b", re.I)
SYSTEM_ACTOR = re.compile(r"\bas (?:the|a|an) (?:system|api|service|backend|frontend|database|scheduler|server|platform|engine|app)\b", re.I)
IMPL = re.compile(r"\b(endpoint|api|dropdown|drop-down|modal|button|table|database|webhook|json|rest)\b", re.I)
STORY_HEAD = re.compile(r"^(#{3,4})\s+(US-\d+[a-z]?)\b:?\s*(.*)$", re.M)
FILLER = re.compile(r"^(?:i|we|they|you)\s+(?:can|could|will|am able to)\s+|^(?:to)\s+", re.I)


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


def stories(body):
    """Yield (id, title, text) for each story section, ending at the next heading."""
    heads = list(STORY_HEAD.finditer(body))
    for h in heads:
        rest = body[h.end():]
        nxt = re.search(r"^#{2,4}\s", rest, re.M)
        yield h.group(2), h.group(3).strip(), rest[: nxt.start()] if nxt else rest


def line(text, label):
    m = re.search(r"^\s*[-*]?\s*(?:\*\*)?" + label + r"[^:\n]*:(?:\*\*)?\s*(.*)$", text, re.M | re.I)
    return m.group(1).strip() if m else None


def words(s):
    return re.findall(r"[a-z0-9']+", s.lower())


def check(text):
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
        if fm.get("name") and fm["name"] != "user-story-backlog":
            errors.append(f"frontmatter: name is '{fm['name']}', expected 'user-story-backlog'")
        if fm.get("phase") and fm["phase"].lower() != "ideate":
            errors.append(f"frontmatter: phase is '{fm['phase']}', the backlog is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile and profile not in ("lean", "standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not lean, standard or enterprise")

    h2 = [(m.group(1).strip(), m.start()) for m in re.finditer(r"^##\s+(.*)$", body, re.M)]
    names = [h.lower() for h, _ in h2]
    has_header = any(n.startswith("requirements header") for n in names)
    block = [i for i, n in enumerate(names) if n.startswith("must / won't") or n.startswith("must / won’t")]
    has_epics = bool(re.search(r"^###\s+EPIC-[A-Za-z0-9]+", body, re.M))

    if profile == "lean":
        if not has_header:
            errors.append("lean: no '## Requirements Header' — at lean the backlog is the functional requirements")
        if not block:
            errors.append("lean: no closing '## Must / Won't-this-time' block — it finalises the provisional priorities")
        else:
            if block[-1] != len(names) - 1:
                errors.append("lean: the Must / Won't-this-time block must close the file (last '##' section)")
            tail = body[h2[block[-1]][1]:]
            if not re.search(r"^###\s+Must\b", tail, re.M):
                errors.append("lean: the closing block has no '### Must' table")
            if not re.search(r"^###\s+Won.t this time", tail, re.M):
                errors.append("lean: the closing block has no '### Won't this time' table")
    elif profile in ("standard", "enterprise"):
        if has_header:
            errors.append(f"{profile}: a Requirements Header belongs only at lean — the FRD holds requirements here")
        if block:
            errors.append(f"{profile}: no Must / Won't-this-time block here — moscow-prioritization finalises priority")
        for key, label in (("backlog summary", "Backlog Summary"), ("coverage", "Coverage")):
            if not any(n.startswith(key) for n in names):
                errors.append(f"{profile}: no '## {label}' section")

    found = list(stories(body))
    if not found:
        errors.append("no '### US-n' / '#### US-n' story sections")
    seen = set()
    for sid, title, t in found:
        if sid in seen:
            errors.append(f"{sid}: duplicate story ID")
        seen.add(sid)
        prio = line(t, r"Priority")
        if prio is None:
            errors.append(f"{sid}: no 'Priority (provisional)' line")
        else:
            if not re.search(r"^\s*[-*]?\s*(?:\*\*)?Priority \(provisional\)", t, re.M | re.I):
                errors.append(f"{sid}: label the priority 'Priority (provisional)'")
            if MOSCOW.search(prio):
                errors.append(f"{sid}: priority '{prio}' uses MoSCoW — stories carry a provisional priority (high / medium / low or value and penalty)")
        if re.match(r"spike\b", title, re.I):
            for lab in ("Question", "Output", "Unblocks"):
                if line(t, lab) is None:
                    errors.append(f"{sid}: spike has no '{lab}' line")
            continue

        card = re.search(r"\bAs (?:an?|the) (.+?),\s*I want(?: to)? (.+?),\s*(?:so that|so I can|so we can) (.+?)(?:\.\s*$|\.\s*\n|$)", t, re.I | re.M | re.S)
        if not card:
            errors.append(f"{sid}: no card in the form 'As a …, I want to …, so that …'")
        else:
            actor, want, benefit = (g.strip() for g in card.groups())
            if re.match(r"^(user|customer|person)\b", actor, re.I):
                errors.append(f"{sid}: actor 'a {actor.split()[0]}' — name a persona (P-n) or a user role")
            if SYSTEM_ACTOR.search(card.group(0)):
                errors.append(f"{sid}: a system is the actor — systems have no wants; this is a task")
            w, b = words(FILLER.sub("", want)), words(FILLER.sub("", benefit))
            if b and (b == w or (len(b) <= len(w) + 1 and b[: len(w)] == w)):
                errors.append(f"{sid}: the 'so that' repeats the want — name the change for the user")
            im = IMPL.search(want)
            if im:
                warnings.append(f"{sid}: the want names '{im.group(1)}' — an implementation word; state the need")

        traces = line(t, r"Traces to") or ""
        if not traces:
            errors.append(f"{sid}: no 'Traces to' line")
        else:
            if not re.search(r"\bJS-\d+\.\d+", traces):
                errors.append(f"{sid}: 'Traces to' cites no job story (JS-n.m)")
            if has_epics and not re.search(r"\bEPIC-[A-Za-z0-9]+", traces):
                errors.append(f"{sid}: 'Traces to' cites no epic (EPIC-n)")
            if profile in ("standard", "enterprise") and not re.search(r"\b(UR|TR)-\d+", traces):
                errors.append(f"{sid}: 'Traces to' cites no user or transition requirement (UR-n / TR-n)")
        if line(t, r"Seed example") is None:
            errors.append(f"{sid}: no 'Seed example' line — one concrete case is the story's readiness seed")
        for ln in t.splitlines():
            if GWT_LINE.match(ln) or GWT_INLINE.search(ln):
                errors.append(f"{sid}: Given/When/Then on the card — acceptance-criteria writes it from the example map")
                break
        if line(t, r"Size") is not None or SIZEY.search(t):
            errors.append(f"{sid}: size, sprint or point field — a story is one build-and-verify unit; split it if too big")
    return errors, warnings


def main(argv):
    if len(argv) != 2:
        print(__doc__.split("Checks:")[0].strip())
        return 2
    try:
        text = open(argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"ERROR: cannot read {argv[1]}: {e}")
        return 2
    errors, warnings = check(text)
    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
