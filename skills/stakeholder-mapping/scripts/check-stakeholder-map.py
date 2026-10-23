#!/usr/bin/env python3
"""check-stakeholder-map.py — mechanical checks on a stakeholder-map artifact.

Owned by the stakeholder-mapping skill. Deterministic checks only; it makes
no stakeholder judgement. The agent applying the skill fixes what it reports.

Usage:
    check-stakeholder-map.py <stakeholder-map.md>

Checks:
  1. The artifact has a Delivery Stakeholders section and a separate
     Buying Committee section (headings containing "Delivery" and
     "Buying Committee").
  2. Register quadrants match power and interest. A cell starting with
     High/H or Low/L is read directly; an integer 1-5 is High when >= 3.
     A 1-3 score is rejected (the 2x2 midpoint is undefined).
  3. Decision rights: every decision row has exactly one Accountable, and
     the Accountable is not an AI agent or a hook. Two layouts are read:
     an "Accountable" column, or a letter matrix (one column per party,
     cells holding R / A / C / I).
  4. The buying-committee section has no cadence: no Cadence / Frequency /
     Channel column, and no "newsletter" or cadence word in its tables.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

QUADRANTS = {
    (True, True): "manage closely",
    (True, False): "keep satisfied",
    (False, True): "keep informed",
    (False, False): "monitor",
}
CADENCE_WORDS = re.compile(
    r"\b(weekly|bi-weekly|biweekly|fortnightly|monthly|quarterly|newsletter)\b", re.I)
NOT_A_PERSON = re.compile(r"\b(agent|hook|hooks|bot)\b", re.I)
MULTI = re.compile(r",|/|&|\+|\band\b", re.I)


def sections(lines):
    """Split into (heading, [lines]) by level-2 headings."""
    out, head, buf = [], "", []
    for ln in lines:
        if ln.startswith("## "):
            out.append((head, buf))
            head, buf = ln[3:].strip(), []
        else:
            buf.append(ln)
    out.append((head, buf))
    return out


def tables(lines):
    """Yield (header_cells, [row_cells]) for each Markdown table."""
    i = 0
    while i < len(lines):
        if lines[i].strip().startswith("|") and i + 1 < len(lines) \
                and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            header = cells(lines[i])
            rows, i = [], i + 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            yield header, rows
        else:
            i += 1


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def level(cell):
    """Return (is_high, error) for a power/interest cell."""
    c = re.sub(r"[*_`]", "", cell).strip()
    m = re.match(r"^(high|low|h|l)\b", c, re.I)
    if m:
        return m.group(1).lower().startswith("h"), None
    m = re.match(r"^(\d+)", c)
    if m:
        n = int(m.group(1))
        if not 1 <= n <= 5:
            return None, f"score {n} outside 1-5"
        return n >= 3, None
    return None, f"unreadable level '{cell}'"


def col(header, *names):
    for idx, h in enumerate(header):
        hl = h.lower()
        if any(n in hl for n in names):
            return idx
    return None


def check(text):
    errors, warnings = [], []
    lines = text.splitlines()
    secs = sections(lines)
    delivery = [s for s in secs if "delivery" in s[0].lower()]
    committee = [s for s in secs if "buying committee" in s[0].lower()]
    if not delivery:
        errors.append("no 'Delivery Stakeholders' section")
    if not committee:
        errors.append("no 'Buying Committee' section (write 'none: <reason>' under it if there is none)")

    # Scale: a 1-3 numeric scale anywhere in a register is an error.
    for head, body in delivery:
        for header, rows in tables(body):
            p, i, q = col(header, "power"), col(header, "interest"), col(header, "quadrant")
            if p is None or i is None or q is None:
                continue
            nums = [r[x] for r in rows for x in (p, i) if x < len(r) and re.match(r"^\d", r[x].strip())]
            if nums and max(int(re.match(r"\d+", n).group()) for n in nums) <= 3 \
                    and not re.search(r"1\s*[-–]\s*5", "\n".join(body)):
                errors.append("register uses a 1-3 score: the 2x2 midpoint is undefined; use High/Low or 1-5 with 3+ High")
            for r in rows:
                if max(p, i, q) >= len(r):
                    continue
                hp, e1 = level(r[p])
                hi, e2 = level(r[i])
                if e1 or e2:
                    errors.append(f"register row '{r[0]}': {e1 or e2}")
                    continue
                want = QUADRANTS[(hp, hi)]
                if not re.sub(r"[*_`]", "", r[q]).strip().lower().startswith(want):
                    errors.append(f"register row '{r[0]}': quadrant '{r[q]}' but power/interest give '{want.title()}'")

    # Decision rights.
    for head, body in secs:
        for header, rows in tables(body):
            a = col(header, "accountable")
            if a is None and "A" in [h.strip() for h in header]:
                a = [h.strip() for h in header].index("A")
            if a is not None:
                for r in rows:
                    if a >= len(r):
                        continue
                    who = re.sub(r"[*_`]", "", r[a]).strip()
                    if not who or who in {"-", "—"}:
                        errors.append(f"decision '{r[0]}': no Accountable")
                    elif MULTI.search(who):
                        errors.append(f"decision '{r[0]}': more than one Accountable ('{who}')")
                    elif NOT_A_PERSON.search(who):
                        errors.append(f"decision '{r[0]}': Accountable '{who}' is not a person (agents and hooks may only be Responsible)")
                continue
            letter_rows = [r for r in rows if any(re.fullmatch(r"[RACI](\s*/\s*[RACI])*", c.strip()) for c in r[1:])]
            if not letter_rows:
                continue
            for r in letter_rows:
                holders = [header[k] for k, c in enumerate(r) if k > 0 and k < len(header)
                           and "A" in re.split(r"\s*/\s*", c.strip())]
                if len(holders) != 1:
                    errors.append(f"decision '{r[0]}': {len(holders)} Accountable entries ({', '.join(holders) or 'none'})")
                for h in holders:
                    if NOT_A_PERSON.search(h):
                        errors.append(f"decision '{r[0]}': Accountable '{h}' is not a person (agents and hooks may only be Responsible)")

    # No cadence for committee roles.
    for head, body in committee:
        for header, rows in tables(body):
            if col(header, "cadence", "frequency", "channel") is not None:
                errors.append("buying-committee table has a cadence / frequency / channel column; roles are hypotheses, not people to update")
            for r in rows:
                for word in sorted({w.lower() for w in CADENCE_WORDS.findall(" ".join(r))}):
                    msg = f"buying-committee row '{r[0]}' mentions '{word}'"
                    if word == "newsletter":
                        errors.append(msg)
                    else:
                        warnings.append(msg + " — check it is not an engagement cadence")
    return errors, warnings


def main():
    if len(sys.argv) != 2:
        print("usage: check-stakeholder-map.py <stakeholder-map.md>", file=sys.stderr)
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
