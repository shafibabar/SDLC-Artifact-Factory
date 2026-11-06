#!/bin/bash
# scripts/validate-cqrs-decisions.sh — skill-owned script for skills/cqrs-pattern.
# Purpose: mechanically check a design/architecture/cqrs-decisions.md against
#          the structural items of resources/decision-checklist.md: frontmatter;
#          every context block names its read side (simple read model or
#          projections), pattern, event sourcing, trigger, staleness,
#          read-your-writes and revisit-when; a projected context names a
#          trigger that is not a wish and accepts some staleness; an
#          event-sourced context is projected; a query served by a projection
#          belongs to a projected context; a cross-service CQRS view names a
#          trigger and an owner; no code (D047-10). Whether the evidence is
#          real stays with the agent.
# Usage:   validate-cqrs-decisions.sh <path-to-cqrs-decisions.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-cqrs-decisions.sh <path-to-cqrs-decisions.md>" >&2
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
required = ["name", "product", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not filled(meta.get(f, ""))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is cqrs-design", meta.get("name") == "cqrs-design")

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

WISH = re.compile(r"(?i)\b(might|may need|could need|in case|future[- ]proof|best practice|industry standard|just to be safe|core subdomain|we (already )?have (a )?(broker|kafka|redpanda)|scal(e|ability) later|eventually need)\b")
NONE = re.compile(r"(?i)^\s*(none|n/a|no trigger)\b")

contexts = [b for b in blocks if b["title"].lower().startswith("context:")]
check("has at least one '## Context:' block", bool(contexts))
names = []
for b in contexts:
    name = b["title"].split(":", 1)[1].strip()
    names.append(name)
    subs = subsections(b["lines"])
    f = fields(subs[""])
    check(f"{name}: name is filled in", filled(name))
    for key in ("read side", "business-logic pattern", "event sourced", "trigger", "staleness accepted", "read-your-writes", "revisit when"):
        check(f"{name}: '{key}' is filled in", filled(f.get(key, "")))
    side = f.get("read side", "").lower().strip()
    rung = "projections" if side.startswith("projection") else "simple" if side.startswith("simple read model") else None
    check(f"{name}: read side is 'simple read model' or 'projections'", rung is not None)
    trig = f.get("trigger", "")
    stale = f.get("staleness accepted", "")
    es = f.get("event sourced", "").lower().strip()
    if rung == "projections":
        check(f"{name}: projections name a trigger", filled(trig) and not NONE.match(trig))
        check(f"{name}: the trigger is evidence, not a wish", not WISH.search(trig))
        check(f"{name}: projected views accept some staleness (they are eventually consistent)", filled(stale) and not re.match(r"(?i)\s*(immediate|none|zero|real[- ]time)\b", stale))
        if re.match(r"(?i)\s*immediate", f.get("read-your-writes", "")):
            warn(f"{name}: projected context says read-your-writes is immediate; say how the writer sees their own change")
    if rung == "simple" and filled(stale) and not re.match(r"(?i)\s*immediate", stale):
        warn(f"{name}: a Simple Read Model reads the write tables, so staleness is usually immediate")
    if es.startswith("yes"):
        check(f"{name}: an event-sourced context is on projections", rung == "projections")
    if rung == "simple" and re.search(r"(?i)event-sourced", f.get("business-logic pattern", "")):
        check(f"{name}: an event-sourced pattern needs projections", False)

    qh, qrows = table(subs.get("queries", []))
    qrows = [r for r in qrows if r and filled(r[0])]
    for r in qrows:
        served = (r[1] if len(r) > 1 else "").lower()
        if served.startswith("projection") and rung != "projections":
            check(f"{name}: query '{r[0]}' is served by a projection, but the context is not on projections", False)
    if not qrows:
        warn(f"{name}: no queries listed")

dupes = sorted({x for x in names if names.count(x) > 1})
check("no context appears twice" + (f" ({', '.join(dupes)})" if dupes else ""), not dupes)
summary = next((b for b in blocks if b["title"].lower() == "contexts"), None)
if summary:
    sh, srows = table(summary["lines"])
    listed = {r[0].strip() for r in srows if r and filled(r[0])}
    missing_blocks = sorted(listed - set(names))
    check("every context in the summary table has a '## Context:' block" + (f" (missing: {', '.join(missing_blocks)})" if missing_blocks else ""), not missing_blocks)
else:
    check("has a '## Contexts' summary table", False)

xs = next((b for b in blocks if b["title"].lower() == "cross-service queries"), None)
if xs:
    xh, xrows = table(xs["lines"])
    for r in [r for r in xrows if r and filled(r[0])]:
        g = lambda i: r[i] if i < len(r) else ""
        appr = g(2).lower()
        check(f"cross-service '{g(0)}': approach is API Composition or CQRS view", appr.startswith("api composition") or appr.startswith("cqrs view"))
        if appr.startswith("cqrs view"):
            check(f"cross-service '{g(0)}': a CQRS view names a trigger", filled(g(3)) and not NONE.match(g(3)))
            check(f"cross-service '{g(0)}': the trigger is evidence, not a wish", not WISH.search(g(3)))
            check(f"cross-service '{g(0)}': a CQRS view names its owner and feeding events", filled(g(4)))
        if re.search(r"(?i)\b(shared (database|tables?)|reads? (the )?\w+ tables? directly|direct (db|database) read)\b", " ".join(r)):
            check(f"cross-service '{g(0)}': no reads of another service's tables", False)
else:
    warn("no '## Cross-service queries' section (write 'none' in a row if no query spans services)")

body = text[fm.end():] if fm else text
check("no code or DDL (D047-10: code belongs to go-service-layer and go-event-consumer)", not re.search(r"```(go|golang|java|ts|typescript|python|csharp|kotlin|sql)\b|^\s*func \(|^\s*type \w+ struct|\bCREATE TABLE\b", body, re.M | re.I))

print(f"INFO: {len(contexts)} context(s), {sum(1 for b in contexts if fields(subsections(b['lines'])['']).get('read side','').lower().startswith('projection'))} projected")
sys.exit(1 if fails else 0)
PYEOF
