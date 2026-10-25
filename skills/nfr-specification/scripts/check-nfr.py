#!/usr/bin/env python3
"""check-nfr.py — mechanical checks on a non-functional requirements specification.

Owned by the nfr-specification skill. Deterministic checks only; it makes no
judgement about whether a target is justified or a rating is right. The agent
applying the skill fixes what it reports.

Usage:
    check-nfr.py <nfr-specification.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary and profile;
     phase is "ideate"; profile is lean, standard or enterprise.
  2. Sections exist: Inputs Consumed, Characteristics Considered, Ranking (or
     Utility Tree), Quality-Attribute Scenarios, Candidate Trade-off Points,
     Process Targets, Architecture Handoff. Enterprise needs a Utility Tree.
  3. The scenarios table has Stimulus, Environment, Response measure, Traces
     and Verification columns (standard and enterprise also Source, Affected
     part and Response); every NFR row fills them. Each response measure
     carries Must; standard and enterprise also Plan; enterprise also Stretch.
  4. At least one deployability scenario (NFR-DEPLOY-…).
  5. No DORA delivery rate (deployment frequency, lead time for changes,
     change failure rate) in a scenario row: those are process targets.
  6. Every obligation row (NFR-OBL-…) cites a business rule (BR-n).
  7. Every scenario rated H on architectural impact (ranking table, or a
     utility-tree leaf "(value, impact)") appears in the Architecture Handoff.
  8. Warnings: an average or mean as a latency measure; more than 8 scenarios
     at lean; a bare "scenario" heading.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary", "profile"]
SECTIONS = [("inputs consumed", "Inputs Consumed"),
            ("characteristics considered", "Characteristics Considered"),
            ("quality-attribute scenarios", "Quality-Attribute Scenarios"),
            ("candidate trade-off points", "Candidate Trade-off Points"),
            ("process targets", "Process Targets"),
            ("architecture handoff", "Architecture Handoff")]
NFR_ID = re.compile(r"\bNFR-[A-Z]+-\d+\b")
DORA = re.compile(r"deployment frequency|lead time for changes|change failure rate", re.I)
AVERAGE = re.compile(r"\b(average|mean)\b", re.I)


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


def section(body, prefix):
    """Return the text of the first '## <prefix>…' section, or None."""
    parts = re.split(r"^(##\s+.*)$", body, flags=re.M)
    for k in range(1, len(parts), 2):
        if parts[k].lstrip("# ").strip().lower().startswith(prefix):
            return parts[k + 1]
    return None


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


def empty(v):
    return not v or v.strip() in ("-", "—", "<…>", "…")


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
            errors.append(f"frontmatter: phase is '{fm['phase']}', the NFR specification is written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    if profile and profile not in ("lean", "standard", "enterprise"):
        errors.append(f"frontmatter: profile '{profile}' is not lean, standard or enterprise")
        profile = ""

    heads = [h.lower() for h in re.findall(r"^##\s+(.*)$", body, re.M)]
    for key, label in SECTIONS:
        if not any(h.startswith(key) for h in heads):
            errors.append(f"no '## {label}' section")
    has_tree = any(h.startswith("utility tree") for h in heads)
    if not has_tree and not any(h.startswith("ranking") for h in heads):
        errors.append("no '## Ranking' (or '## Utility Tree') section")
    if profile == "enterprise" and not has_tree:
        errors.append("enterprise profile needs a '## Utility Tree' (utility → characteristic → refinement → rated scenarios)")
    if any(re.fullmatch(r"scenarios?", h.strip()) for h in heads):
        warnings.append("a bare 'Scenarios' heading — say 'Quality-Attribute Scenarios' (a bare scenario is a Gherkin Scenario)")

    # 3–6. Scenario table.
    scen = section(body, "quality-attribute scenarios") or ""
    need = [("stimulus", "Stimulus"), ("environment", "Environment"),
            ("response measure", "Response measure"), ("traces", "Traces to"),
            ("verification", "Verification")]
    if profile in ("standard", "enterprise"):
        need += [("source", "Source"), ("affected part", "Affected part"), ("response", "Response")]
    scenario_ids, n_rows = [], 0
    for header, rows in tables(scen):
        ii = col(header, "id")
        if ii is None:
            continue
        idx = {}
        for key, label in need:
            if key == "response":
                i = next((k for k, h in enumerate(header) if h == "response" or h.startswith("response (")), None)
            else:
                i = col(header, key)
            if i is None:
                errors.append(f"scenarios table has no '{label}' column")
            idx[key] = i
        for r in rows:
            rid = cell(r, ii).strip("* ")
            if not NFR_ID.match(rid):
                continue
            n_rows += 1
            scenario_ids.append(rid)
            for key, label in need:
                if idx[key] is not None and empty(cell(r, idx[key])):
                    errors.append(f"{rid}: '{label}' is empty")
            rm = cell(r, idx.get("response measure"))
            if rm:
                if "must" not in rm.lower():
                    errors.append(f"{rid}: response measure has no Must (the minimum acceptable)")
                if profile in ("standard", "enterprise") and "plan" not in rm.lower():
                    errors.append(f"{rid}: response measure has no Plan (the target) — required at {profile}")
                if profile == "enterprise" and "stretch" not in rm.lower():
                    errors.append(f"{rid}: response measure has no Stretch — required at enterprise")
                if AVERAGE.search(rm):
                    warnings.append(f"{rid}: average or mean in the response measure — use percentiles for latency")
            if DORA.search(" ".join(r)):
                errors.append(f"{rid}: a DORA delivery rate is a process target, not a product quality attribute — move it to Process Targets (values from dora-metrics)")
    if n_rows == 0:
        errors.append("no NFR-<PREFIX>-<nn> rows in the Quality-Attribute Scenarios table")
    if not any(s.startswith("NFR-DEPLOY-") for s in scenario_ids):
        errors.append("no deployability scenario (NFR-DEPLOY-…) — the product property the architecture must support")
    if profile == "lean" and n_rows > 8:
        warnings.append(f"{n_rows} scenarios at lean — keep 3–8, only those that change a design decision")

    obl = section(body, "obligations") or ""
    for header, rows in tables(obl):
        for r in rows:
            rid = r[0].strip("* ") if r else ""
            if rid.startswith("NFR-OBL-") and not re.search(r"\bBR-\d+", " ".join(r)):
                errors.append(f"{rid}: obligation cites no business rule (BR-n) — the rule lives in the FRD")

    # 7. ASRs reach the handoff.
    rank = (section(body, "utility tree") or "") + (section(body, "ranking") or "")
    asr = set()
    for header, rows in tables(rank):
        ni, ai = col(header, "nfr", "scenario", "id"), col(header, "architectural impact", "impact")
        for r in rows:
            m = NFR_ID.search(cell(r, ni))
            if m and cell(r, ai).strip().upper().startswith("H"):
                asr.add(m.group(0))
    for m in re.finditer(r"(NFR-[A-Z]+-\d+)\b[^\n]*\(\s*[HML]\s*,\s*H\s*\)", rank):
        asr.add(m.group(1))
    handoff = section(body, "architecture handoff") or ""
    for a in sorted(asr):
        if a not in handoff:
            errors.append(f"{a}: rated H on architectural impact but missing from the Architecture Handoff")
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
