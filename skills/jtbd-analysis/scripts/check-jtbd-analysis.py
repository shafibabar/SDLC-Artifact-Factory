#!/usr/bin/env python3
"""check-jtbd-analysis.py — mechanical checks on a jtbd-analysis artifact.

Owned by the jtbd-analysis skill. Deterministic checks only; it makes no
judgement about whether a job is real, a motivation solution-free or a
ranking wise. The agent applying the skill fixes what it reports.

Usage:
    check-jtbd-analysis.py <jtbd-analysis.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary, profile
     and evidence; phase is "ideate"; profile is not "lean" (the artifact is
     skipped at lean: JTBD folds into the persona).
  2. At least one job section ("## J-<n>: ..."). Each has a
     "**Job statement" line whose text is not in job-story form (does not
     start with "When" or contain "I want").
  3. Each job section has a "What gets fired" heading, a Big Hire line, a
     Little Hire line, and a forces table with Push, Pull, Anxiety and Habit
     rows.
  4. Each job section has at least one job story ("#### JS-..."); each story
     contains "When", "I want to" and "so I can", and an Evidence line that
     cites a snapshot ("[yyyy-mm-dd-...]") or says "[assumption".
  5. Every cited snapshot appears in the "## Evidence" section; with
     "evidence: none", no snapshot may be cited.
  6. In any table with an "Opportunity" column, no row's ID is a job
     ("J-<n>"): opportunity is scored on desired outcomes. Where Importance,
     Satisfaction and Opportunity are all numeric, Opportunity must equal
     I + max(I - S, 0) (to 0.1).
  7. If "ranking:" says compare-and-contrast and numeric opportunity scores
     appear, the word "directional" must appear in the document.
  8. Warning if there is no "## Onboarding Requirements" section.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary",
               "profile", "evidence"]
SNAPSHOT_REF = re.compile(r"\[(\d{4}-\d{2}-\d{2}-[a-z0-9-]+)\]", re.I)
FORCES = ["push", "pull", "anxiety", "habit"]


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


def split(body, level):
    """Split body into (heading, block) at headings of exactly `level` #s."""
    prefix = "#" * level + " "
    out, head, buf = [], None, []
    for ln in body.splitlines():
        if ln.startswith(prefix):
            if head is not None:
                out.append((head, "\n".join(buf)))
            head, buf = ln[len(prefix):].strip(), []
        elif head is not None:
            buf.append(ln)
    if head is not None:
        out.append((head, "\n".join(buf)))
    return out


def tables(text):
    """Yield (header_cells, [row_cells]) for each Markdown table."""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            header = [c.strip() for c in lines[i].strip().strip("|").split("|")]
            rows, j = [], i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                rows.append([c.strip() for c in lines[j].strip().strip("|").split("|")])
                j += 1
            yield header, rows
            i = j
        else:
            i += 1


def num(cell):
    m = re.match(r"^\**\s*(\d+(?:\.\d+)?)\s*\**", cell or "")
    return float(m.group(1)) if m else None


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
            errors.append(f"frontmatter: phase is '{fm['phase']}', JTBD analysis is written in Ideate (phase: ideate)")
        if (fm.get("profile") or "").lower() == "lean":
            errors.append("frontmatter: profile 'lean' — the jtbd-analysis artifact is skipped at lean; fold JTBD into the persona")
    no_evidence = (fm.get("evidence") or "").lower().startswith("none")

    evidence_sec = next((b for h, b in split(body, 2) if h.lower().startswith("evidence")), "")
    listed = {m.group(1).lower() for m in SNAPSHOT_REF.finditer(evidence_sec)}

    jobs = [(h, b) for h, b in split(body, 2) if re.match(r"^J-\d+\b", h)]
    if not jobs:
        errors.append("no job sections ('## J-<n>: <name>')")
    for head, block in jobs:
        jid = head.split(":")[0].strip()
        m = re.search(r"\*\*Job statement[^*]*:\*\*\s*(.*)", block, re.I)
        if not m or not m.group(1).strip():
            errors.append(f"{jid}: no '**Job statement (Ulwick):**' line")
        else:
            js = m.group(1).strip()
            if re.match(r"^when\b", js, re.I) or re.search(r"\bi want\b", js, re.I):
                errors.append(f"{jid}: the job statement is in job-story form — write [verb] [object] [clarifier]; job stories go under it")
        if not re.search(r"^#+\s*What gets fired", block, re.I | re.M):
            errors.append(f"{jid}: no 'What gets fired' section (include non-consumption)")
        if not re.search(r"Big Hire:", block):
            errors.append(f"{jid}: no Big Hire line")
        if not re.search(r"Little Hire:", block):
            errors.append(f"{jid}: no Little Hire line")
        force_rows = set()
        for header, rows in tables(block):
            if header and header[0].lower() == "force":
                force_rows |= {r[0].strip("* ").lower() for r in rows if r}
        missing = [f for f in FORCES if f not in force_rows]
        if missing:
            errors.append(f"{jid}: forces table lacks {', '.join(missing)}")

        stories = split(block, 4)
        stories = [(h, b) for h, b in stories if h.startswith("JS-")]
        if not stories:
            errors.append(f"{jid}: no job stories ('#### JS-<n>.<m>: ...')")
        for sh, sb in stories:
            sid = sh.split(":")[0].strip()
            flat = " ".join(sb.split())
            if not (re.search(r"\bWhen\b", flat) and re.search(r"\bI want to\b", flat, re.I) and re.search(r"\bso I can\b", flat, re.I)):
                errors.append(f"{sid}: not in 'When…, I want to…, so I can…' form")
            ev = re.search(r"\*\*Evidence:\*\*\s*(.*)", sb)
            if not ev:
                errors.append(f"{sid}: no Evidence line — cite a snapshot or tag [assumption]")
                continue
            cites = [c.lower() for c in SNAPSHOT_REF.findall(ev.group(1))]
            if not cites and "[assumption" not in ev.group(1).lower():
                errors.append(f"{sid}: Evidence cites no snapshot and is not tagged [assumption]")
            for c in cites:
                if no_evidence:
                    errors.append(f"{sid}: cites snapshot [{c}] but frontmatter says 'evidence: none'")
                elif c not in listed:
                    errors.append(f"{sid}: cites snapshot [{c}] that is not listed under ## Evidence")

    numeric_scores = False
    for header, rows in tables(body):
        low = [h.lower() for h in header]
        oi = next((i for i, h in enumerate(low) if h.startswith("opportunity")), None)
        if oi is None:
            continue
        ii = next((i for i, h in enumerate(low) if h.startswith("importance") and "event" not in h), None)
        si = next((i for i, h in enumerate(low) if h.startswith("satisfaction")), None)
        for r in rows:
            if not r:
                continue
            rid = r[0].strip("* ")
            if re.match(r"^J-\d+\b", rid):
                errors.append(f"row '{rid}': opportunity scored on a whole job — score desired outcomes within the job")
            if oi < len(r) and num(r[oi]) is not None:
                numeric_scores = True
                if ii is not None and si is not None and max(ii, si) < len(r):
                    i_, s_, o_ = num(r[ii]), num(r[si]), num(r[oi])
                    if None not in (i_, s_) and abs(i_ + max(i_ - s_, 0) - o_) > 0.1:
                        errors.append(f"row '{rid}': Opportunity {o_} ≠ {i_} + max({i_} − {s_}, 0) = {i_ + max(i_ - s_, 0):.1f}")
    if numeric_scores and "compare" in (fm.get("ranking") or "").lower() and "directional" not in body.lower():
        errors.append("numeric opportunity scores with compare-and-contrast ranking — label small-sample ratings 'directional'")

    if not re.search(r"^##\s+Onboarding Requirements", body, re.M):
        warnings.append("no '## Onboarding Requirements' section — derive them from consumption jobs, obstacles, experiences and the Little Hire")
    return errors, warnings


def main():
    if len(sys.argv) != 2:
        print("usage: check-jtbd-analysis.py <jtbd-analysis.md>", file=sys.stderr)
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
