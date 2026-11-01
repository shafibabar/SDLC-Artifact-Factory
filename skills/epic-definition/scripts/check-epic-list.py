#!/usr/bin/env python3
"""check-epic-list.py — mechanical checks on an epic list (ideate/epics.md).

Owned by the epic-definition skill. Deterministic checks only; it makes no
judgement about whether a hypothesis is good or a split is right. The agent
applying the skill fixes what it reports.

Usage:
    check-epic-list.py <epics.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary and profile;
     phase is "ideate"; profile is standard or enterprise (lean has no epic
     list: epic headings go in the user story backlog).
  2. Sections exist: Coverage and Not Epics; enterprise also Cross-Context Flags.
  3. Each "### EPIC-…" section has an outcome line ("As a result of this
     epic"), a Hypothesis, a Traces to line citing a job story (JS-n.m) and a
     user or transition requirement (UR-n / TR-n), a Bounded Context line, a
     Risks line naming value, usability, feasibility and viability each with a
     status (tested / assumed / low), and a Priority (provisional) line.
  4. Each epic has 3–5 epic acceptance criteria ("- [ ]"), each with an
     "Example", and none written as Given/When/Then.
  5. Each epic lists 3–10 story titles, and its Size (S 3–4, M 5–7, L 8–10)
     matches the count.
  6. No MoSCoW word (Must / Should / Could / Won't) on a priority line, and no
     sprint, week or story-point sizing.
  7. Warnings: a component or layer word in an epic title (service, API,
     layer, module, database, backend, frontend, adapter, engine).

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "profile"]
MOSCOW = re.compile(r"\b(must|should|could|won'?t)\b", re.I)
SPRINTY = re.compile(r"\b(sprints?|story points?|person[- ]weeks?|weeks?)\b", re.I)
COMPONENT = re.compile(r"\b(service|api|layer|module|database|backend|frontend|adapter|engine)\b", re.I)
GWT = re.compile(r"\bgiven\b.*\bwhen\b.*\bthen\b", re.I)
SIZES = {"S": (3, 4), "M": (5, 7), "L": (8, 10)}
RISKS = ["value", "usability", "feasibility", "viability"]


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


def epics(body):
    """Yield (id, title, text) for each '### EPIC-…' section."""
    parts = re.split(r"^(###\s+EPIC-[A-Za-z0-9]+:?.*)$", body, flags=re.M)
    for k in range(1, len(parts), 2):
        hm = re.match(r"###\s+(EPIC-[A-Za-z0-9]+):?\s*(.*)$", parts[k])
        text = re.split(r"^##\s", parts[k + 1], maxsplit=1, flags=re.M)[0]
        yield hm.group(1), hm.group(2).strip(), text


def field(text, label):
    m = re.search(r"^\*\*" + label + r"[^*]*:\*\*\s*(.*)$", text, re.M | re.I)
    return m.group(1).strip() if m else None


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
        if fm.get("phase") and fm["phase"].lower() != "ideate":
            errors.append(f"frontmatter: phase is '{fm['phase']}', the epic list is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile == "lean":
        errors.append("profile is lean: there is no epic list at lean — put epic headings with a KR trace line in ideate/user-stories.md")
    elif profile and profile not in ("standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not standard or enterprise")

    heads = [h.lower() for h in re.findall(r"^##\s+(.*)$", body, re.M)]
    for key, label in (("coverage", "Coverage"), ("not epics", "Not Epics")):
        if not any(h.startswith(key) for h in heads):
            errors.append(f"no '## {label}' section")
    if profile == "enterprise" and not any(h.startswith("cross-context") for h in heads):
        errors.append("enterprise profile needs a '## Cross-Context Flags' section (write 'none' if none)")

    found = list(epics(body))
    if not found:
        errors.append("no '### EPIC-…' sections")
    for eid, title, t in found:
        if COMPONENT.search(title):
            warnings.append(f"{eid}: title '{title}' names a component or layer — name the outcome")
        if not re.search(r"as a result of this epic", t, re.I):
            errors.append(f"{eid}: no outcome statement ('As a result of this epic, … will be able to …')")
        if not field(t, "Hypothesis"):
            errors.append(f"{eid}: no Hypothesis")
        traces = field(t, "Traces to") or ""
        if not traces:
            errors.append(f"{eid}: no 'Traces to' line")
        else:
            if not re.search(r"\bJS-\d+(\.\d+)?", traces):
                errors.append(f"{eid}: 'Traces to' cites no job story (JS-n.m)")
            if not re.search(r"\b(UR|TR)-\d+", traces):
                errors.append(f"{eid}: 'Traces to' cites no user or transition requirement (UR-n / TR-n)")
        if field(t, "Bounded Context") is None:
            errors.append(f"{eid}: no Bounded Context line")
        risks = (field(t, "Risks") or "").lower()
        if not risks:
            errors.append(f"{eid}: no four-risk line (value, usability, feasibility, viability)")
        else:
            for r in RISKS:
                m = re.search(r + r"\s*[—–-]+\s*(\w+)", risks)
                if not m:
                    errors.append(f"{eid}: risk line does not cover {r}")
                elif m.group(1) not in ("tested", "assumed", "low"):
                    errors.append(f"{eid}: {r} risk status '{m.group(1)}' is not tested, assumed or low")
        prio = field(t, "Priority")
        if prio is None:
            errors.append(f"{eid}: no 'Priority (provisional)' line")
        elif MOSCOW.search(prio):
            errors.append(f"{eid}: priority '{prio}' uses MoSCoW — epics carry a provisional priority; moscow-prioritization finalises it")

        crit = re.findall(r"^\s*- \[[ xX]\]\s*(.*)$", t, re.M)
        if not 3 <= len(crit) <= 5:
            errors.append(f"{eid}: {len(crit)} epic acceptance criteria — write 3–5")
        for c in crit:
            if GWT.search(c):
                errors.append(f"{eid}: criterion in Given/When/Then ('{c[:50]}…') — that is story-level detail")
            elif "example" not in c.lower():
                errors.append(f"{eid}: criterion without a concrete example ('{c[:50]}…')")

        sm = re.search(r"^\*\*Story titles[^\n]*\n(.*?)(?=^\*\*|\Z)", t, re.M | re.S)
        titles = re.findall(r"^\s*\d+\.\s+\S", sm.group(1), re.M) if sm else []
        n = len(titles)
        if not sm:
            errors.append(f"{eid}: no 'Story titles' list")
        elif not 3 <= n <= 10:
            errors.append(f"{eid}: {n} story title(s) — an epic has 3–10 (fewer: a story; more: split the epic)")
        size = field(t, "Size")
        if size is None:
            errors.append(f"{eid}: no Size line")
        else:
            if SPRINTY.search(size):
                errors.append(f"{eid}: size '{size}' is in sprints, weeks or points — size by story count (S/M/L)")
            m = re.match(r"\s*([SMLsml])\b", size)
            if not m:
                errors.append(f"{eid}: size '{size}' is not S, M or L")
            elif sm and 3 <= n <= 10:
                lo, hi = SIZES[m.group(1).upper()]
                if not lo <= n <= hi:
                    errors.append(f"{eid}: size {m.group(1).upper()} but {n} story titles (S 3–4, M 5–7, L 8–10)")
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
