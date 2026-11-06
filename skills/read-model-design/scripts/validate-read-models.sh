#!/bin/bash
# scripts/validate-read-models.sh — skill-owned script for skills/read-model-design.
# Purpose: mechanically check a design/<context>/read-models.md against the
#          structural items of resources/checklist.md: frontmatter, tracing to
#          cqrs-decisions.md (the rung is decided there first, D047-4); every
#          Read Model in the summary has a block and the same rung; a rung-1
#          entry names what it is built from and never loads the Aggregate; a
#          projected one names its mechanic, store, key, staleness, freshness,
#          read-your-writes, idempotency, rebuild source and a rebuild that is
#          not a hand patch or a live truncate; a topic used as rebuild source
#          states its retention; a cache states its time-to-live; every copied
#          value names its change event; no projector side effects; no code
#          (D047-10). Whether the shapes are right stays with the agent.
# Usage:   validate-read-models.sh <path-to-read-models.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-read-models.sh <path-to-read-models.md>" >&2
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

def affirmed(text, pattern):
    """True if a clause of text matches pattern without a negation in that clause."""
    for clause in re.split(r"[;,.:()]", text or ""):
        if re.search(pattern, clause, re.I) and not re.search(r"(?i)\b(never|not|no|without|instead of)\b", clause):
            return True
    return False

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "bounded-context", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not filled(meta.get(f, ""))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is read-model-design", meta.get("name") == "read-model-design")
check("traces-to names cqrs-decisions.md (the read side is decided before Read Models, D047-4)", "cqrs-decisions" in meta.get("traces-to", ""))

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

def rung_of(s):
    s = (s or "").lower().strip()
    return "projection" if s.startswith("projection") else "simple" if s.startswith("simple read model") else None

CAMEL = re.compile(r"\b[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]*)+\b")
rms = [b for b in blocks if b["title"].lower().startswith("read model:")]
check("has at least one '## Read Model:' block", bool(rms))
names, rungs, projected = [], {}, 0
for b in rms:
    name = b["title"].split(":", 1)[1].strip()
    names.append(name)
    subs = subsections(b["lines"])
    f = fields(subs[""])
    check(f"{name}: name is filled in", filled(name))
    for key in ("answers", "rung", "tenant scope"):
        check(f"{name}: '{key}' is filled in", filled(f.get(key, "")))
    rung = rung_of(f.get("rung", ""))
    rungs[name] = rung
    check(f"{name}: rung is 'simple read model' or 'projection'", rung is not None)
    fh, frows = table(subs.get("fields", []))
    check(f"{name}: has a Fields table with at least one field", any(r and filled(r[0]) for r in frows))
    eh, erows = table(subs.get("events", []))
    erows = [r for r in erows if r and filled(r[0])]

    if rung == "simple":
        built = f.get("built from", "")
        check(f"{name}: 'built from' names the write tables or joins it reads", filled(built))
        check(f"{name}: a rung-1 Read Model reads tables through a query type, never by loading the Aggregate",
              not affirmed(built, r"\b(load(s|ing|ed)?|rehydrat\w*|reconstitut\w*)\b[^|]*\baggregate"))
        if erows:
            warn(f"{name}: a rung-1 Read Model lists events; it reads the write tables, so it has no projector")

    if rung == "projection":
        projected += 1
        for key in ("mechanic", "store", "keyed on", "staleness accepted", "freshness shown",
                    "read-your-writes", "idempotency", "rebuild source", "rebuild"):
            check(f"{name}: '{key}' is filled in", filled(f.get(key, "")))
        mech = f.get("mechanic", "").lower()
        check(f"{name}: mechanic is from published events, in the write transaction, or change data capture",
              any(mech.startswith(m) for m in ("from published events", "in the write transaction", "change data capture")))
        stale = f.get("staleness accepted", "")
        if not mech.startswith("in the write transaction"):
            check(f"{name}: a projection fed asynchronously accepts some staleness",
                  filled(stale) and not re.match(r"(?i)\s*(immediate|none|zero|real[- ]time)\b", stale))
        check(f"{name}: staleness is stated as a figure (a number of seconds, minutes, ...), not 'per the decision'",
              bool(re.search(r"(?i)\d|\b(immediate|seconds?|minutes?|hours?|days?)\b", stale)))
        rebuild = f.get("rebuild", "")
        check(f"{name}: the rebuild is from events, not a hand patch or a live truncate",
              not affirmed(rebuild, r"\b(by hand|manual(ly)?|patch(ed|ing)?|hand[- ]edit\w*|truncat\w*)\b"))
        if filled(rebuild) and not re.search(r"(?i)\b(copy|shadow|swap|switch|alias|beside|alongside)\b", rebuild):
            warn(f"{name}: the rebuild does not say it builds a copy and switches readers over (no downtime)")
        src = f.get("rebuild source", "")
        if re.search(r"(?i)\b(topic|broker|stream retention|kafka|redpanda|queue)\b", src):
            check(f"{name}: a topic as rebuild source states its retention or what it cannot recover",
                  bool(re.search(r"(?i)\b(retention|retained|retains|compacted|forever|infinite|unlimited|full history|cannot recover|can't recover)\b", src)))
        store = f.get("store", "")
        if affirmed(store, r"\bcach(e|ed|ing)\b"):
            check(f"{name}: a cache states its time-to-live or invalidation",
                  bool(re.search(r"(?i)(time-to-live|\bttl\b|invalidat\w*|expir\w*)", store)))
        check(f"{name}: has an Events table with at least one event", bool(erows))
        for r in erows:
            effect = r[1] if len(r) > 1 else ""
            check(f"{name}: event '{r[0]}' has its effect on the view", filled(effect))
            if affirmed(effect, r"\b(send(s)?|email(s)?|notif(y|ies)|publish(es)?|issue(s)? (a )?command|charge(s)?|call(s)? the)\b"):
                check(f"{name}: event '{r[0]}': a projector only writes its view (no Commands, messages or published events)", False)
        for r in [r for r in frows if r and filled(r[0])]:
            copied = r[3] if len(r) > 3 else ""
            if filled(copied):
                check(f"{name}: copied field '{r[0]}' names the event that changes it",
                      bool(CAMEL.search(copied)) or "change event" in copied.lower())
        if not filled(f.get("lag alert", "")):
            warn(f"{name}: no lag alert")
        if not filled(f.get("old event types", "")):
            warn(f"{name}: 'old event types' not stated (replaced types must still be handled on replay)")

dupes = sorted({x for x in names if names.count(x) > 1})
check("no Read Model appears twice" + (f" ({', '.join(dupes)})" if dupes else ""), not dupes)
summary = next((b for b in blocks if b["title"].lower() == "read models"), None)
if summary:
    sh, srows = table(summary["lines"])
    srows = [r for r in srows if r and filled(r[0])]
    listed = {r[0].strip() for r in srows}
    missing_blocks = sorted(listed - set(names))
    check("every Read Model in the summary table has a '## Read Model:' block" + (f" (missing: {', '.join(missing_blocks)})" if missing_blocks else ""), not missing_blocks)
    unlisted = sorted(set(names) - listed)
    check("every '## Read Model:' block is in the summary table" + (f" (unlisted: {', '.join(unlisted)})" if unlisted else ""), not unlisted)
    for r in srows:
        n = r[0].strip()
        if n in rungs and len(r) > 2 and rungs[n] is not None:
            check(f"{n}: the summary rung matches its block", rung_of(r[2]) == rungs[n])
else:
    check("has a '## Read Models' summary table", False)

body = text[fm.end():] if fm else text
check("no code or DDL (D047-10: code belongs to go-repository-pattern and go-event-consumer)",
      not re.search(r"```(go|golang|java|ts|typescript|python|csharp|kotlin|sql)\b|^\s*func \(|^\s*type \w+ struct|\bCREATE TABLE\b", body, re.M | re.I))

print(f"INFO: {len(rms)} Read Model(s), {projected} projected")
sys.exit(1 if fails else 0)
PYEOF
