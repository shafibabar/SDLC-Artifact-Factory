#!/usr/bin/env python3
"""check-impact-map.py — mechanical checks on an impact-map artifact.

Owned by the impact-mapping skill. Deterministic checks only; it makes no
judgement about whether an impact is a real behaviour change, a path wise or
an assumption well chosen. The agent applying the skill fixes what it reports.

Usage:
    check-impact-map.py <impact-map.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary, profile,
     goal, linked-kr, linked-tree and selected-path; phase is "ideate";
     profile is standard or enterprise (lean skips the impact map).
  2. A "## Goal" section whose table has Metric, Meter, Baseline, Target and
     Deadline rows.
  3. Map tables (a table with Impact and Deliverable columns) have
     Opportunity, Path, Assumption and Signal columns and no Priority or
     MoSCoW column; every Path cell is "selected" or "option"; no cell holds
     a Must / Should / Could / Won't priority; at least one selected row; every
     selected row has an Assumption and a Signal.
  4. When target-opportunity is set, at least one selected row cites it in
     its Opportunity cell.
  5. An actor heading or Actors-table row of type Blocker, or a "No blocker:"
     line.
  6. A "## Selected Path" section with an assumptions table whose Type cells
     are desirability, viability, feasibility, usability or ethical; a
     non-empty "## Re-plan Trigger" section.
  7. Warnings: no ethical assumption on the selected path; an impact phrased
     as feature usage ("uses the", "uses our"); an "MVP" heading.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary",
               "profile", "goal", "linked-kr", "linked-tree", "selected-path"]
GOAL_FIELDS = ["metric", "meter", "baseline", "target", "deadline"]
TYPES = {"desirability", "viability", "feasibility", "usability", "ethical"}
MOSCOW = re.compile(r"^\s*\**\s*(must|should|could|won'?t)(\s+have)?\s*\**\s*$", re.I)
USAGE = re.compile(r"\buses (the|our|a)\b", re.I)


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


def sections(body):
    """Return {lowercased level-2 heading: block}."""
    out, head, buf = {}, None, []
    for ln in body.splitlines():
        if ln.startswith("## "):
            if head is not None:
                out[head] = "\n".join(buf)
            head, buf = ln[3:].strip().lower(), []
        elif head is not None:
            buf.append(ln)
    if head is not None:
        out[head] = "\n".join(buf)
    return out


def section(secs, prefix):
    return next((b for h, b in secs.items() if h.startswith(prefix)), None)


def tables(text):
    """Yield (lowercased header cells, [row cells]) for each Markdown table."""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if (lines[i].lstrip().startswith("|") and i + 1 < len(lines)
                and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1])):
            header = [c.strip().lower() for c in lines[i].strip().strip("|").split("|")]
            rows, j = [], i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                rows.append([c.strip() for c in lines[j].strip().strip("|").split("|")])
                j += 1
            yield header, rows
            i = j
        else:
            i += 1


def col(header, *prefixes):
    return next((i for i, h in enumerate(header)
                 if any(h.startswith(p) for p in prefixes)), None)


def cell(row, i):
    return row[i] if i is not None and i < len(row) else ""


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def check(text):
    errors, warnings = [], []
    fm, body = frontmatter(text)
    body = strip_comments(body)
    if fm is None:
        errors.append("no frontmatter block")
        fm = {}
    else:
        for k in REQUIRED_FM:
            if not fm.get(k):
                errors.append(f"frontmatter: missing '{k}'")
        if fm.get("phase") and fm["phase"].lower() != "ideate":
            errors.append(f"frontmatter: phase is '{fm['phase']}', the impact map is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile == "lean":
        errors.append("profile is lean — the lean profile skips the impact map; trace epics to the Key Result instead")
    elif profile and profile not in ("standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not standard or enterprise")

    secs = sections(body)

    goal = section(secs, "goal")
    if goal is None:
        errors.append("no '## Goal' section")
    else:
        fields = set()
        for header, rows in tables(goal):
            for r in rows:
                fields.add(cell(r, 0).strip("* ").lower())
        for f in GOAL_FIELDS:
            if not any(x.startswith(f) for x in fields):
                errors.append(f"Goal: no '{f.capitalize()}' row — copy it from the tree's root and the KR, or write 'not set in KR'")

    target = (fm.get("target-opportunity") or "").strip().upper()
    selected, cites_target, map_tables = 0, False, 0
    for header, rows in tables(body):
        ii, di = col(header, "impact"), col(header, "deliverable")
        if ii is None or di is None:
            continue
        map_tables += 1
        if col(header, "priority", "moscow") is not None:
            errors.append("map table has a Priority / MoSCoW column — use Path / Assumption / Signal; MoSCoW finalises priority later")
        oi, pi, ai, si = (col(header, "opportunity"), col(header, "path"),
                          col(header, "assumption"), col(header, "signal"))
        for name, i in (("Opportunity", oi), ("Path", pi), ("Assumption", ai), ("Signal", si)):
            if i is None:
                errors.append(f"map table has no {name} column")
        last_impact = ""
        for r in rows:
            imp = cell(r, ii)
            if imp:
                last_impact = imp
                if USAGE.search(imp):
                    warnings.append(f"impact '{imp[:60]}' reads as feature usage — rewrite as the behaviour it enables")
            for c in r:
                if MOSCOW.match(c):
                    errors.append(f"'{c.strip()}' in the map — a MoSCoW priority; mark the row selected or option")
            path = cell(r, pi).strip("* ").lower()
            if pi is not None and path not in ("selected", "option"):
                errors.append(f"Path '{cell(r, pi)}' (impact '{last_impact[:40]}') — must be 'selected' or 'option'")
            if path == "selected":
                selected += 1
                if not cell(r, ai).strip(" —-"):
                    errors.append(f"selected row under '{last_impact[:40]}' has no Assumption")
                if not cell(r, si).strip(" —-"):
                    errors.append(f"selected row under '{last_impact[:40]}' has no Signal")
                if target and target in cell(r, oi).upper():
                    cites_target = True
    if map_tables == 0:
        errors.append("no map table (columns Impact … Opportunity … Deliverable … Path … Assumption … Signal)")
    elif selected == 0:
        errors.append("no row marked 'selected' — choose one path through the map")
    if target and selected and not cites_target:
        errors.append(f"no selected row cites the target opportunity {target} — the path's impact is the one the tree's target explains")

    blocker = re.search(r"^###\s+Actor:.*\bBlocker\b", body, re.M | re.I) \
        or re.search(r"\|\s*Blocker\s*\|", body, re.I) \
        or re.search(r"No blocker:", body)
    if not blocker:
        errors.append("no Blocker actor and no 'No blocker:' line — ask who can obstruct the goal")

    sp = section(secs, "selected path")
    if sp is None:
        errors.append("no '## Selected Path' section")
    else:
        typed, ethical = 0, False
        for header, rows in tables(sp):
            ti = col(header, "type")
            if ti is None:
                continue
            for r in rows:
                t = cell(r, ti).strip("* ").lower()
                if t not in TYPES:
                    errors.append(f"Selected Path: assumption type '{cell(r, ti)}' is not desirability, viability, feasibility, usability or ethical")
                else:
                    typed += 1
                    ethical = ethical or t == "ethical"
        if typed == 0:
            errors.append("Selected Path: no assumptions table with a Type column")
        elif not ethical:
            warnings.append("Selected Path: no ethical assumption — ask who is affected and whether it could do harm")

    rp = section(secs, "re-plan")
    if rp is None or not rp.strip():
        errors.append("no '## Re-plan Trigger' section — say what sends the team back to the map")
    if re.search(r"^##+\s.*\bMVP\b", body, re.M):
        warnings.append("an 'MVP' heading — the map's cut is the selected path; the walking skeleton belongs to the story map")
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
