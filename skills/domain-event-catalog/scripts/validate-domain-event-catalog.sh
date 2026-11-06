#!/bin/bash
# scripts/validate-domain-event-catalog.sh — skill-owned script for skills/domain-event-catalog.
# Purpose: mechanically check a design/<context>/domain-event-catalog.md against
#          the structural items of resources/catalog-checklist.md: frontmatter;
#          every event is a PascalCase past-tense fact with no CRUD verb, no
#          version suffix and no command shape; meaning, Aggregate, raised-by,
#          visibility and retention need are filled; published events point to
#          the wire contract and name consumers with an idempotent reaction;
#          internal events say how they are (or aren't) published; payloads hold
#          no envelope fields; no code or DDL (D047-10). Whether the name is the
#          right business fact stays with the agent.
# Usage:   validate-domain-event-catalog.sh <path-to-domain-event-catalog.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-domain-event-catalog.sh <path-to-domain-event-catalog.md>" >&2
  exit 2
fi
if [ ! -f "$1" ]; then
  echo "error: file not found: $1" >&2
  exit 2
fi

python3 - "$1" <<'PYEOF'
import re, sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
fails = 0

def check(label, ok):
    global fails
    print(("PASS: " if ok else "FAIL: ") + label)
    if not ok:
        fails += 1

def warn(label):
    print("WARN: " + label)

def filled(c):
    c = (c or "").strip()
    if not c or c in ("—", "-", "?"):
        return False
    # "[product slug]" is an unfilled placeholder; "[a.md, b.md]" is a filled YAML list.
    return not (c.startswith("[") and not re.search(r"\.md|/", c.split("]")[0]))

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "bounded-context", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not filled(meta.get(f, ""))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is domain-event-catalog", meta.get("name") == "domain-event-catalog")

blocks, cur = [], None
for line in text.splitlines():
    h = re.match(r"^## (.+)$", line)
    if h:
        cur = {"title": h.group(1).strip(), "lines": []}
        blocks.append(cur)
    elif cur is not None:
        cur["lines"].append(line)

def subsections(lines):
    out, name = {"": []}, ""
    for l in lines:
        h = re.match(r"^### (.+)$", l)
        if h:
            name = h.group(1).strip().lower(); out[name] = []
        else:
            out[name].append(l)
    return out

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], rows[1:]) if rows else ([], [])

def fields(lines):
    return {r[0].strip("* ").lower(): r[1] for r in table(lines)[1] if len(r) >= 2}

IRREGULAR = {"Sent", "Paid", "Made", "Held", "Won", "Lost", "Built", "Taken", "Given", "Written", "Run", "Begun", "Sold", "Bought", "Left", "Met", "Set", "Put", "Cut", "Shut", "Split", "Read", "Kept", "Done", "Drawn", "Withdrawn", "Chosen", "Frozen", "Spent", "Lent", "Sought", "Brought", "Overdue", "Due"}
NOT_VERBS = {"Seed", "Need", "Feed", "Speed", "Bed", "Red", "Shed", "Breed", "Weed", "Deed", "Reed", "Greed", "Embed", "Steed", "Bleed"}
CRUD_FAIL = {"Updated", "Changed", "Modified", "Saved", "Edited", "Processed", "Handled", "Inserted"}
CRUD_WARN = {"Created", "Deleted", "Removed", "Added"}
ENVELOPE = {"eventid", "eventtype", "occurredat", "version", "schemaversion", "eventversion", "tenantid", "correlationid", "causationid", "source", "specversion"}

events = [b for b in blocks if b["title"].lower().startswith("event:")]
check("has at least one '## Event:' block", bool(events))
names = []
for b in events:
    name = b["title"].split(":", 1)[1].strip().strip("`")
    names.append(name)
    words = re.findall(r"[A-Z][a-z]*", name)
    check(f"{name}: name is filled in (not a placeholder)", filled(name))
    check(f"{name}: PascalCase", bool(re.fullmatch(r"(?:[A-Z][a-z0-9]+)+", name)))
    check(f"{name}: no version suffix", not re.search(r"V\d+$|_v\d+$|\.v\d+$", name))
    check(f"{name}: past tense (a fact that happened, not a command)", any((w.endswith("ed") and w not in NOT_VERBS) or w in IRREGULAR for w in words))
    crud = [w for w in words if w in CRUD_FAIL]
    check(f"{name}: no CRUD or technical verb as the fact" + (f" ({', '.join(crud)})" if crud else ""), not crud)
    if words and words[-1] in CRUD_WARN:
        warn(f"{name}: '{words[-1]}' is usually a database verb; the language often has a better word for the fact")

    subs = subsections(b["lines"])
    f = fields(subs[""])
    for key in ("means", "aggregate", "raised by", "visibility", "published as", "retention need"):
        check(f"{name}: '{key}' is filled in", filled(f.get(key, "")))
    vis = f.get("visibility", "").lower()
    check(f"{name}: visibility is published, internal or stored", bool(re.match(r"\s*(published|internal|stored)", vis)))
    pub = f.get("published as", "").lower()
    if vis.startswith("published"):
        check(f"{name}: published event points to its wire contract (event-schemas.md or a type)", "event-schemas" in pub or bool(re.search(r"\b[a-z0-9-]+\.[a-z0-9-]+\.[a-z0-9-]+\.[a-z0-9-]+", pub)))
        ch, crows = table(subs.get("consumers", []))
        crows = [r for r in crows if r and filled(r[0])]
        if not crows:
            warn(f"{name}: published with no consumers listed (write 'none yet' and why in the table)")
        for r in crows:
            if r[0].lower().startswith("none"):
                continue
            g = lambda i: r[i] if i < len(r) else ""
            check(f"{name} → {g(0)}: reaction written as a policy ('Whenever …, then …')", bool(re.search(r"(?i)\bwhenever\b.*\bthen\b", g(1))))
            check(f"{name} → {g(0)}: says what the reaction is idempotent on", filled(g(2)))
    elif vis.startswith("internal") or vis.startswith("stored"):
        check(f"{name}: internal or stored event says how it is published (translated to …) or why it isn't", bool(re.search(r"translated|not published|never published|internal only", pub)))

    ph, prows = table(subs.get("payload meaning", []))
    prows = [r for r in prows if r and filled(r[0])]
    for r in prows:
        n = re.sub(r"[`_-]", "", r[0]).lower()
        check(f"{name}: payload field '{r[0]}' is not an envelope attribute", n not in ENVELOPE)
    if len(prows) == 0:
        check(f"{name}: payload meaning lists its fields", False)
    elif len(prows) == 1:
        warn(f"{name}: one payload field; an ID-only event makes every consumer call back (state the choice if deliberate)")

dupes = sorted({x for x in names if names.count(x) > 1})
check("no event appears twice" + (f" ({', '.join(dupes)})" if dupes else ""), not dupes)
summary = next((b for b in blocks if b["title"].lower() == "events"), None)
if summary:
    sh, srows = table(summary["lines"])
    listed = {r[0].strip("` ") for r in srows if r and filled(r[0])}
    missing_blocks = sorted(listed - set(names))
    check("every event in the summary table has an '## Event:' block" + (f" (missing: {', '.join(missing_blocks)})" if missing_blocks else ""), not missing_blocks)
else:
    check("has an '## Events' summary table", False)

body = text[fm.end():] if fm else text
check("no code or DDL (D047-10: delivery and code belong to event-driven-patterns and the go-* skills)", not re.search(r"```(go|golang|java|ts|typescript|python|csharp|kotlin|sql)\b|^\s*func \(|^\s*type \w+ struct|\bCREATE TABLE\b", body, re.M | re.I))

print(f"INFO: {len(events)} event(s), {sum(1 for b in events if fields(subsections(b['lines'])['']).get('visibility','').lower().startswith('published'))} published")
sys.exit(1 if fails else 0)
PYEOF
