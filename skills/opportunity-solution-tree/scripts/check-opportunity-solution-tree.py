#!/usr/bin/env python3
"""check-opportunity-solution-tree.py — mechanical checks on an
opportunity-solution-tree artifact (a full tree, or the lean ranked list).

Owned by the opportunity-solution-tree skill. Deterministic checks only; it
makes no judgement about whether an opportunity is real, a comparison wise or
a test well designed. The agent applying the skill fixes what it reports.

Usage:
    check-opportunity-solution-tree.py <opportunity-solution-tree.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary, profile,
     desired-outcome, outcome-type, evidence and target-opportunity; phase is
     "ideate"; profile is lean, standard or enterprise.
  2. outcome-type names a product outcome and not a business outcome or a
     traction metric.
  3. An opportunity table exists (a table with an ID column and an
     "Opportunity" column) with at least one OPP- row. Each row's
     Evidence cell cites a snapshot ("[yyyy-mm-dd-...]") or feedback item
     ("[FB-n]") or says "[assumption"; top-level branch rows (Parent "—")
     may leave it "—". Every citation is listed under "## Evidence"; with
     "evidence: none", nothing may be cited.
  4. Standard / enterprise: the table has a Parent column and every parent is
     "—" or an existing OPP- ID. Lean: the table has a Rank column; a warning
     outside three to seven rows.
  5. target-opportunity names an OPP- ID in the table, and a
     "**Target opportunity:**" line exists.
  6. Standard / enterprise: a "## Solutions" table with at least two rows
     marked carried forward ("yes"); a "## Assumptions" table whose Type
     cells are desirability, viability, feasibility, usability or ethical,
     with at least one ethical row; an "## Assumption Tests" table in which
     every success criterion contains a number.
  7. Warnings: an opportunity whose wording names a solution (dashboard,
     integration, button, export, widget, notification, "I wish there was",
     "add a"); enterprise without a Segment / tenant column.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary",
               "profile", "desired-outcome", "outcome-type", "evidence",
               "target-opportunity"]
CITE = re.compile(r"\[(\d{4}-\d{2}-\d{2}-[a-z0-9-]+|FB-\d+)\]", re.I)
TYPES = {"desirability", "viability", "feasibility", "usability", "ethical"}
SOLUTION_WORDS = re.compile(
    r"\b(dashboard|integration|button|export|widget|notifications?|plugin)\b"
    r"|i wish there (was|were)|\badd an? \b", re.I)


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


def check(text):
    errors, warnings = [], []
    fm, body = frontmatter(text)
    if fm is None:
        errors.append("no frontmatter block")
        fm = {}
    else:
        for k in REQUIRED_FM:
            if not fm.get(k):
                errors.append(f"frontmatter: missing '{k}'")
        if fm.get("phase") and fm["phase"].lower() != "ideate":
            errors.append(f"frontmatter: phase is '{fm['phase']}', the tree is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile and profile not in ("lean", "standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not lean, standard or enterprise")
    lean = profile == "lean"
    ot = (fm.get("outcome-type") or "").lower()
    if ot:
        if "business" in ot:
            errors.append("outcome-type is a business outcome — root the tree at the product outcome the team believes drives it")
        elif "traction" in ot:
            errors.append("outcome-type is a traction metric — a feature's usage decides the solution; root the tree at what the feature was for")
        elif "product outcome" not in ot:
            errors.append(f"outcome-type '{fm['outcome-type']}' — the root must be a product outcome")
    no_evidence = (fm.get("evidence") or "").lower().startswith("none")

    secs = sections(body)
    listed = {m.group(1).lower() for m in CITE.finditer(section(secs, "evidence") or "")}

    opp = None
    for header, rows in tables(body):
        if "id" in header and col(header, "opportunity") is not None:
            ii = header.index("id")
            if any(cell(r, ii).strip("* ").upper().startswith("OPP-") for r in rows):
                opp = (header, rows, ii)
                break
    ids = set()
    if opp is None:
        errors.append("no opportunity table (columns ID … Opportunity … with OPP- rows)")
    else:
        header, rows, ii = opp
        rows = [r for r in rows if cell(r, ii).strip("* ").upper().startswith("OPP-")]
        ids = {cell(r, ii).strip("* ").upper() for r in rows}
        oi, ei, pi = col(header, "opportunity"), col(header, "evidence"), col(header, "parent")
        if ei is None:
            errors.append("opportunity table has no Evidence column")
        if lean:
            if col(header, "rank") is None:
                errors.append("lean: the opportunity list has no Rank column — rank the opportunities")
            if not 3 <= len(rows) <= 7:
                warnings.append(f"lean: {len(rows)} opportunities — a lean list holds three to seven")
        else:
            if pi is None:
                errors.append("opportunity table has no Parent column — a tree nests opportunities under experience steps")
            if profile == "enterprise" and col(header, "segment", "tenant") is None:
                warnings.append("enterprise: no Segment / tenant role column — one segment's need must not be averaged into another's")
        for r in rows:
            rid = cell(r, ii).strip("* ").upper()
            parent = cell(r, pi).strip("* ")
            branch = pi is not None and parent in ("—", "-", "")
            if pi is not None and not branch and parent.upper() not in ids:
                errors.append(f"{rid}: parent '{parent}' is not an opportunity in the table")
            text_ = cell(r, oi)
            if SOLUTION_WORDS.search(text_) and not branch:
                warnings.append(f"{rid}: '{text_}' names a solution — rewrite as the need behind it (could more than one solution address it?)")
            if ei is None:
                continue
            ev = cell(r, ei)
            cites = [c.lower() for c in CITE.findall(ev)]
            if not cites and "[assumption" not in ev.lower() and not (branch and ev.strip() in ("—", "-", "")):
                errors.append(f"{rid}: Evidence cites no snapshot or feedback item and is not tagged [assumption]")
            for c in cites:
                if no_evidence:
                    errors.append(f"{rid}: cites [{c}] but frontmatter says 'evidence: none'")
                elif c not in listed:
                    errors.append(f"{rid}: cites [{c}] that is not listed under ## Evidence")

    target = (fm.get("target-opportunity") or "").strip().upper()
    if target and ids and target not in ids:
        errors.append(f"target-opportunity '{target}' is not an opportunity in the table")
    if not re.search(r"\*\*Target opportunity:\*\*", body):
        errors.append("no '**Target opportunity:**' line")

    if not lean:
        sol = section(secs, "solutions")
        carried = 0
        for header, rows in tables(sol or ""):
            ci = col(header, "carried")
            if ci is not None:
                carried += sum(1 for r in rows if cell(r, ci).lower().startswith("yes"))
        if sol is None:
            errors.append("no '## Solutions' section for the target opportunity")
        elif carried < 2:
            errors.append(f"{carried} solution(s) carried forward — carry about three forward together, so tests compare")

        asm = section(secs, "assumptions")
        types_seen = set()
        for header, rows in tables(asm or ""):
            ti = col(header, "type")
            if ti is None:
                continue
            for r in rows:
                t = cell(r, ti).strip("* ").lower()
                if t not in TYPES:
                    errors.append(f"{r[0]}: assumption type '{t}' — use desirability, viability, feasibility, usability or ethical")
                types_seen.add(t)
        if asm is None:
            errors.append("no '## Assumptions' section")
        elif "ethical" not in types_seen:
            errors.append("no ethical assumption — ask whether each solution could do harm and should be done")

        tst = section(secs, "assumption tests")
        if tst is None:
            errors.append("no '## Assumption Tests' section")
        for header, rows in tables(tst or ""):
            si = col(header, "success")
            if si is None:
                errors.append("assumption tests table has no Success criterion column")
                continue
            for r in rows:
                if not re.search(r"\d", cell(r, si)):
                    errors.append(f"{r[0]}: success criterion '{cell(r, si)}' has no number — set 'at least N of M …' before the test runs")
    return errors, warnings


def main():
    if len(sys.argv) != 2:
        print("usage: check-opportunity-solution-tree.py <opportunity-solution-tree.md>", file=sys.stderr)
        return 2
    try:
        text = open(sys.argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    errors, warnings = check(text)
    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
