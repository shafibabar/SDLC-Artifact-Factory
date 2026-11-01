#!/usr/bin/env python3
"""check-frd.py — mechanical checks on a functional requirements document.

Owned by the requirements-analysis skill. Deterministic checks only; it makes
no judgement about whether a requirement is necessary, atomic or well traced.
The agent applying the skill fixes what it reports.

Usage:
    check-frd.py <requirements.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary, profile,
     linked-kr, linked-impact-map and linked-jtbd; phase is "ideate"; profile
     is standard or enterprise (lean has no FRD: the backlog is the
     functional requirements).
  2. At least one "### UR-n" heading. Each UR has a "Traces to:" line that
     names a job statement (J-n) and a job story (JS-n.m), and a deliverable
     (SOL-n or "deliverable <name>") — or, when linked-impact-map is "none",
     a Key Result (KR-…).
  3. Every requirements table (a table with an ID column holding FR-… rows)
     has Fit criterion and Priority columns; no Priority cell holds Must /
     Should / Could / Won't; every Fit criterion cell is filled and is more
     than a bare test type ("integration test", "TBD").
  4. Sections exist: Transition Requirements, Quality-Attribute Hand-off,
     Business Rules, Assumption Log, TBD List, Waiting Room; and the line
     saying priorities are provisional.
  5. Warnings: ambiguous words in an FR statement or fit criterion; a time or
     uptime target ("within 30 minutes", "99.9%", "< 2 s") in an FR (hand it
     to nfr-specification); "simulated" interviews or workshops anywhere.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary",
               "profile", "linked-kr", "linked-impact-map", "linked-jtbd"]
SECTIONS = [("transition requirements", "Transition Requirements"),
            ("quality-attribute hand-off", "Quality-Attribute Hand-off"),
            ("business rules", "Business Rules"),
            ("assumption log", "Assumption Log"),
            ("tbd list", "TBD List"),
            ("waiting room", "Waiting Room")]
MOSCOW = re.compile(r"\b(must|should|could|won'?t)(\s+have)?\b", re.I)
BARE_TEST = re.compile(r"^\s*((pending|tbd|see)\b.*|n/?a|-|—|(integration|unit|acceptance|usability|"
                       r"performance|manual|e2e|end-to-end)\s+test(s|ing)?\.?)\s*$", re.I)
AMBIGUOUS = re.compile(r"\b(fast|quick(ly)?|user-friendly|easy|intuitive|flexible|"
                       r"robust|seamless(ly)?|supports?|efficient(ly)?|etc\.?|and/or|"
                       r"as appropriate|as needed|should)\b", re.I)
NFR_NUMBER = re.compile(r"(\bwithin\s+\d+(\.\d+)?\s*(ms|milliseconds?|s|sec|seconds?|"
                        r"min|minutes?|h|hours?)\b|\b\d{2}(\.\d+)?\s*%\s*(uptime|"
                        r"availability)|\b99(\.\d+)?\s*%|[<≤]\s*\d+(\.\d+)?\s*(ms|s)\b)", re.I)


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


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


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


def ur_blocks(body):
    """Return [(heading, block)] for each '### UR-n' heading."""
    out = []
    parts = re.split(r"^(###\s+UR-\d+.*)$", body, flags=re.M)
    for k in range(1, len(parts), 2):
        block = re.split(r"^##\s", parts[k + 1], maxsplit=1, flags=re.M)[0]
        out.append((parts[k].lstrip("# ").strip(), block))
    return out


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
            errors.append(f"frontmatter: phase is '{fm['phase']}', the FRD is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile == "lean":
        errors.append("profile is lean — the lean profile has no FRD; the user story backlog is the functional requirements")
    elif profile and profile not in ("standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not standard or enterprise")
    no_map = (fm.get("linked-impact-map") or "").lower().startswith("none")

    urs = ur_blocks(body)
    if not urs:
        errors.append("no '### UR-n' user requirement headings")
    for head, block in urs:
        uid = head.split(":")[0].split()[0]
        m = re.search(r"Traces to:\**\s*(.*)", block)
        if not m:
            errors.append(f"{uid}: no 'Traces to:' line")
            continue
        tr = m.group(1)
        if not re.search(r"\bJ-\d+\b", tr):
            errors.append(f"{uid}: traces to no job statement (J-n)")
        if not re.search(r"\bJS-\d+\.\d+\b", tr):
            errors.append(f"{uid}: traces to no job story (JS-n.m) beneath the job statement")
        if no_map:
            if not re.search(r"\bKR-[\w.]+", tr):
                errors.append(f"{uid}: no impact map, so it must trace to a Key Result (KR-…)")
        elif not re.search(r"\bSOL-\d+|\bdeliverable\b", tr, re.I):
            errors.append(f"{uid}: traces to no selected-path deliverable (SOL-n or 'deliverable …')")

    fr_rows = 0
    for header, rows in tables(body):
        ii = col(header, "id")
        if ii is None or not any(re.match(r"^\**FR-\d", cell(r, ii)) for r in rows):
            continue
        fi = col(header, "fit criterion", "fit")
        pi = col(header, "priority")
        si = col(header, "functional requirement", "requirement", "statement")
        if fi is None:
            errors.append("requirements table has no Fit criterion column")
        if pi is None:
            errors.append("requirements table has no Priority (provisional) column")
        for r in rows:
            rid = cell(r, ii).strip("* ")
            if not rid.startswith("FR-"):
                continue
            fr_rows += 1
            fit = cell(r, fi)
            if fi is not None and BARE_TEST.match(fit or "-"):
                errors.append(f"{rid}: fit criterion '{fit}' is empty, pending or a bare test type — write a measurable pass/fail condition, or keep the requirement on the TBD list")
            pr = cell(r, pi)
            if pi is not None and MOSCOW.search(pr):
                errors.append(f"{rid}: priority '{pr}' is a MoSCoW label — use high / medium / low (provisional); moscow-prioritization finalises it")
            text_ = f"{cell(r, si)} {fit}"
            amb = AMBIGUOUS.search(text_)
            if amb:
                warnings.append(f"{rid}: ambiguous word '{amb.group(0)}' — replace with a number and a condition, or add a TBD")
            if NFR_NUMBER.search(text_):
                warnings.append(f"{rid}: time or uptime target in a functional requirement — hand it to nfr-specification")
    if urs and fr_rows == 0:
        errors.append("no FR-n.m rows in a requirements table")

    heads = [h.lower() for h in re.findall(r"^##\s+(.*)$", body, re.M)]
    for key, label in SECTIONS:
        if not any(h.startswith(key) for h in heads):
            errors.append(f"no '## {label}' section")
    if not re.search(r"provisional", body, re.I):
        errors.append("no statement that priorities are provisional (finalised by moscow-prioritization)")
    if re.search(r"\bsimulated\b", body, re.I):
        warnings.append("'simulated' found — never attribute requirements to an interview or workshop that did not happen; log an assumption")
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
