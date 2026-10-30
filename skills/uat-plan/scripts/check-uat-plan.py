#!/usr/bin/env python3
"""check-uat-plan.py — mechanical checks on a UAT plan.

Owned by the uat-plan skill. Deterministic checks only: it makes no judgement
about whether an acceptance type truly applies, whether a scenario is a good
business scenario, or whether a charter is well aimed. The agent applying the
skill fixes what it reports. Rows marked with a gear in
resources/uat-plan-checklist.md are the ones checked here.

Usage:
    check-uat-plan.py <customer-validation/uat-plan.md>

Checks:
  A1  Frontmatter has name, version, phase, owner, created, summary, profile;
      phase is customer-validation; profile is lean, standard or enterprise.
      Sections present: Acceptance Types in Scope, Scope Traceability, Roles
      and Independence, Environment, Entry Criteria, Exit Criteria, Schedule,
      Exploratory Charters, Completion Summary.
  T1  The Acceptance Types table has a row for each of UAT, OAT, contractual,
      regulatory and alpha / beta, and each row's "In scope" cell starts with
      yes or no.
  S2  Every Scope Traceability row names at least one UAT-<n>[letter] ID, and
      (warning) each ID shares the story's number root (US-5 -> UAT-5a).
  R1  An "Independence level" line is present.
  R2  Independence level "none" requires an "Exception: solo operator"
      section with a reason, a freeze date, evidence and a borrowed-session
      line.
  E2  An Entry Criteria item says the threshold / defect bar is agreed before
      execution.
  E3  Exit Criteria name Pass, Fail, Blocked and Not run.
  E5  Exit Criteria point to acceptance-sign-off for defects and do not
      restate a High-defect bar of their own.
  E6  Residual risk appears in Exit Criteria and in the Completion Summary.
  X1  The Schedule has a re-test step.
  X3  At least one charter in the "Explore ... with ... to discover" form.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "profile"]
REQUIRED_SECTIONS = [
    "Acceptance Types in Scope",
    "Scope Traceability",
    "Roles and Independence",
    "Environment",
    "Entry Criteria",
    "Exit Criteria",
    "Schedule",
    "Exploratory Charters",
    "Completion Summary",
]
TYPES = {
    "UAT": re.compile(r"user acceptance|\bUAT\b", re.I),
    "OAT": re.compile(r"operational acceptance|\bOAT\b", re.I),
    "contractual": re.compile(r"contractual", re.I),
    "regulatory": re.compile(r"regulatory", re.I),
    "alpha / beta": re.compile(r"alpha|beta", re.I),
}
UAT_ID = re.compile(r"\bUAT-(\d+)([a-z]?)\b")
US_ID = re.compile(r"\bUS-(\d+)\b")
HIGH_BAR = re.compile(r"(zero|no)\s+open\s+(critical\s*(/|or|and)\s*)?high", re.I)


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


def sections(body):
    """Map '## Heading' -> text until the next '## '."""
    out, current = {}, None
    for line in body.splitlines():
        h = re.match(r"^##\s+(.+?)\s*$", line)
        if h:
            current = h.group(1)
            out[current] = []
        elif current is not None:
            out[current].append(line)
    return {k: "\n".join(v) for k, v in out.items()}


def find(secs, title):
    for k, v in secs.items():
        if k.lower().startswith(title.lower()):
            return v
    return None


def table_rows(text):
    rows = []
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|") or re.match(r"^\|[\s:|-]+\|$", s):
            continue
        rows.append([c.strip() for c in s.strip("|").split("|")])
    return rows[1:] if rows else []  # drop the header row


def main(argv):
    if len(argv) != 2:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    try:
        text = open(argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"ERROR: cannot read {argv[1]}: {e}", file=sys.stderr)
        return 2

    errors, warnings = [], []
    fm, body = frontmatter(text)
    if fm is None:
        errors.append("A1: no frontmatter block")
        fm = {}
    for f in REQUIRED_FM:
        if not fm.get(f):
            errors.append(f"A1: frontmatter field '{f}' missing or empty")
    if fm.get("phase") and fm["phase"] != "customer-validation":
        errors.append(f"A1: phase is '{fm['phase']}', expected customer-validation")
    if fm.get("profile") and fm["profile"] not in ("lean", "standard", "enterprise"):
        errors.append(f"A1: profile '{fm['profile']}' is not lean, standard or enterprise")

    secs = sections(body)
    for title in REQUIRED_SECTIONS:
        if find(secs, title) is None:
            errors.append(f"A1: section '## {title}' missing")

    # T1 acceptance types
    types = find(secs, "Acceptance Types in Scope")
    if types is not None:
        rows = table_rows(types)
        for name, pat in TYPES.items():
            row = next((r for r in rows if r and pat.search(r[0])), None)
            if row is None:
                errors.append(f"T1: no row for acceptance type '{name}'")
            elif len(row) < 2 or not re.match(r"^(yes|no)\b", row[1], re.I):
                errors.append(f"T1: '{name}' row's In scope cell must start with yes or no")

    # S2 traceability
    trace = find(secs, "Scope Traceability")
    if trace is not None:
        rows = [r for r in table_rows(trace) if r and US_ID.search(r[0])]
        if not rows:
            errors.append("S2: Scope Traceability has no Must story rows")
        for r in rows:
            story = US_ID.search(r[0]).group(1)
            ids = UAT_ID.findall(" ".join(r[1:]))
            if not ids:
                errors.append(f"S2: US-{story} has no UAT scenario ID")
            elif any(n != story for n, _ in ids):
                warnings.append(f"S2: US-{story}'s scenario IDs do not share its root (expected UAT-{story}a, …)")

    # R1 / R2 independence and the solo exception
    m = re.search(r"Independence level[^:\n]*:\**\s*([^\n]+)", body, re.I)
    if not m:
        errors.append("R1: no 'Independence level' line")
    elif re.match(r"\W*none\b", m.group(1), re.I):
        exc = find(secs, "Exception: solo operator")
        if exc is None:
            errors.append("R2: independence level is 'none' but there is no '## Exception: solo operator' section")
        else:
            for label, pat in (("reason", r"why no second party"), ("freeze date", r"frozen|freeze"),
                               ("evidence", r"evidence"), ("borrowed session", r"borrowed")):
                if not re.search(pat, exc, re.I):
                    errors.append(f"R2: solo-operator exception is missing its {label} line")
        if re.search(r"capped at conditional|conditional at (best|most)", text, re.I):
            errors.append("R2: a solo-operator plan must not cap the outcome at conditional (D045)")

    # E2 entry
    entry = find(secs, "Entry Criteria") or ""
    if entry and not re.search(r"agreed.*(before|on \d{4}-\d{2}-\d{2}|on \[)", entry, re.I):
        errors.append("E2: no entry item saying the threshold / defect bar is agreed before execution")

    # E3 / E5 / E6 exit
    exit_ = find(secs, "Exit Criteria") or ""
    if exit_:
        for state in ("Pass", "Fail", "Blocked", "Not run"):
            if not re.search(rf"\b{state}\b", exit_, re.I):
                errors.append(f"E3: Exit Criteria do not name the '{state}' result state")
        if "acceptance-sign-off" not in exit_:
            errors.append("E5: Exit Criteria do not point to acceptance-sign-off's defect rule")
        if HIGH_BAR.search(exit_):
            errors.append("E5: Exit Criteria restate a High-defect bar; point to acceptance-sign-off instead")
        if not re.search(r"residual risk", exit_, re.I):
            errors.append("E6: Exit Criteria do not mention residual risk")
    summ = find(secs, "Completion Summary") or ""
    if summ and not re.search(r"residual risk", summ, re.I):
        errors.append("E6: Completion Summary has no residual-risk line")

    # X1 / X3
    sched = find(secs, "Schedule") or ""
    if sched and not re.search(r"re-?test", sched, re.I):
        errors.append("X1: Schedule has no re-test step")
    charters = find(secs, "Exploratory Charters") or ""
    if charters and not re.search(r"Explore\b.+\bwith\b.+\bto discover\b", charters, re.I):
        errors.append("X3: no charter in the 'Explore … with … to discover …' form")

    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
