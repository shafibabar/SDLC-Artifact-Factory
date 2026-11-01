#!/usr/bin/env python3
"""check-uat-scenarios.py — mechanical checks on one UAT scenarios file.

Owned by the uat-scenario skill. Deterministic checks only: it makes no
judgement about whether an outcome is truly observable, whether the rule was
kept, or whether a scenario is a real piece of business work. The agent
applying the skill fixes what it reports. Rows marked with a gear in
resources/uat-scenario-checklist.md are the ones checked here.

Usage:
    check-uat-scenarios.py <customer-validation/uat-scenarios/US-<n>.md>

Checks:
  F1  Frontmatter has name, version, phase, owner, created, summary, story,
      traces-to; phase is customer-validation; no 'artifact:' key.
  I1  Every '### UAT-' heading is UAT-<n><letter>, <n> = the story's number.
  I2  Every scenario has a 'Traces to:' line naming an AC-US-<n> criterion of
      this story.
  T2  Steps and Expected Outcome contain no HTTP verbs, endpoints, field
      assignments, SQL or backticked identifiers.
  D1  A 'Preconditions' block with at least one item and a 'confirm by'.
  D2  An 'Environment:' line.
  R1  Each filled run row's result is Pass, Fail, Blocked (with a reason) or
      Not run.
  R2  A Fail run names a feedback ID and a workaround (or 'none').
  R5  The file does not restate a defect bar (open Critical / High rules).

Output: one line per finding, "ERROR: ...", then a summary.
Exit codes: 0 no errors, 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "story", "traces-to"]
HEADING = re.compile(r"^###\s+(UAT-\S+?):?\s+(.*)$", re.M)
GOOD_ID = re.compile(r"^UAT-(\d+)([a-z])$")
TECH = [
    (re.compile(r"\b(GET|POST|PUT|PATCH|DELETE)\s+/"), "an HTTP call"),
    (re.compile(r"\bSELECT\b.+\bFROM\b|\bUPDATE\s+\w+\s+SET\b", re.I), "SQL"),
    (re.compile(r"\b[a-z]+(_[a-z]+)+\s*(=|==)\s*\S"), "a field assignment"),
    (re.compile(r"\b[a-z_]+\.[a-z_]+\s*(=|==)\s*\S"), "a field assignment"),
    (re.compile(r"`[^`]*[_./=(][^`]*`"), "a backticked identifier"),
]
DEFECT_BAR = re.compile(r"(zero|no)\s+open\s+(critical|high)|open\s+high\s+(blocks|allows|means)", re.I)
RESULT = re.compile(r"^(Pass|Fail|Blocked|Not run)\b(.*)$", re.I)


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
    return fm, text[m.end():]


def scenarios(body):
    """Split the body into (id, text) per '### UAT-' heading."""
    heads = list(HEADING.finditer(body))
    out = []
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(body)
        out.append((h.group(1), body[h.end():end]))
    return out


def block(text, label):
    """Text after a '**<label>…**' line, up to the next bold label line."""
    m = re.search(rf"^\*\*{label}[^\n]*\n(.*?)(?=^\*\*[A-Z]|\Z)", text, re.M | re.S)
    return m.group(1) if m else None


def run_rows(text):
    rows = []
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|") or re.match(r"^\|[\s:|-]+\|$", s):
            continue
        rows.append([c.strip() for c in s.strip("|").split("|")])
    return rows[1:] if rows else []


def main(argv):
    if len(argv) != 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    try:
        text = open(argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"ERROR: cannot read {argv[1]}: {e}", file=sys.stderr)
        return 2

    errors = []
    fm, body = frontmatter(text)
    if fm is None:
        errors.append("F1: no frontmatter block")
        fm = {}
    for f in REQUIRED_FM:
        if not fm.get(f):
            errors.append(f"F1: frontmatter field '{f}' missing or empty")
    if "artifact" in fm:
        errors.append("F1: use 'name:', not 'artifact:'")
    if fm.get("phase") and fm["phase"] != "customer-validation":
        errors.append(f"F1: phase is '{fm['phase']}', expected customer-validation")
    sm = re.search(r"US-(\d+)", fm.get("story", ""))
    story = sm.group(1) if sm else None

    scs = scenarios(body)
    if not scs:
        errors.append("I1: no '### UAT-' scenario headings")
    for sid, s in scs:
        m = GOOD_ID.match(sid)
        if not m:
            errors.append(f"I1: {sid} is not UAT-<n><letter> (e.g. UAT-{story or 'n'}a)")
        elif story and m.group(1) != story:
            errors.append(f"I1: {sid} does not share the story's number root (US-{story})")

        tr = re.search(r"\*\*Traces to:\*\*\s*([^\n]+)", s)
        if not tr or not re.search(r"AC-US-\d+", tr.group(1)):
            errors.append(f"I2: {sid} has no 'Traces to:' naming an AC-US-<n> criterion")
        elif story and any(n != story for n in re.findall(r"AC-US-(\d+)", tr.group(1))):
            errors.append(f"I2: {sid} traces to another story's criterion")

        for label in ("Steps", "Expected Outcome"):
            part = block(s, label) or ""
            for pat, what in TECH:
                if pat.search(part):
                    errors.append(f"T2: {sid} {label} contains {what}; use the user's words")
                    break

        pre = block(s, "Preconditions")
        if pre is None or not re.search(r"^\s*-\s+\S", pre, re.M):
            errors.append(f"D1: {sid} has no Preconditions items")
        elif not re.search(r"confirm by", pre, re.I):
            errors.append(f"D1: {sid} Preconditions say nothing about how the tester confirms them ('confirm by')")
        if not re.search(r"^\*\*Environment:\*\*\s*\S", s, re.M):
            errors.append(f"D2: {sid} has no 'Environment:' line")

        runs = block(s, "Runs") or ""
        for row in run_rows(runs):
            if len(row) < 5 or not row[0] or row[0] in ("[ ]", "—", "-"):
                continue  # not yet run
            r = RESULT.match(row[2])
            if not r:
                errors.append(f"R1: {sid} run {row[0]} result '{row[2]}' is not Pass, Fail, Blocked or Not run")
                continue
            state, rest = r.group(1).lower(), r.group(2)
            if state == "blocked" and not re.search(r"\w", rest):
                errors.append(f"R1: {sid} run {row[0]} is Blocked with no reason")
            if state == "fail":
                if not re.search(r"\b[A-Z]{2,}-\d+", row[4]):
                    errors.append(f"R2: {sid} run {row[0]} is a Fail with no feedback ID")
                if not re.search(r"workaround", row[4], re.I):
                    errors.append(f"R2: {sid} run {row[0]} is a Fail with no workaround (write 'workaround: none' if there is none)")

    if DEFECT_BAR.search(body):
        errors.append("R5: the file restates a defect bar; that rule lives in acceptance-sign-off")

    for e in errors:
        print(f"ERROR: {e}")
    print(f"{len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
