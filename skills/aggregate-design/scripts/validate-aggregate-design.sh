#!/bin/bash
# scripts/validate-aggregate-design.sh — skill-owned script for skills/aggregate-design.
# Purpose: mechanically check an aggregates.md (per Bounded Context) or a lean
#          domain-model.md against the structural items of
#          resources/aggregate-checklist.md: frontmatter; every block names its
#          business-logic pattern with a reason; every Aggregate has a True
#          Invariant answered yes/no/no and states identity, concurrency, event
#          sourcing and contention; event sourcing names one of the three needs;
#          relationships answer has-a and must-be-atomic and reference by ID;
#          no code (D047-10). Lean documents also need Domain Events, Commands
#          and Read Models. Whether a rule really passes the test stays with the agent.
# Usage:   validate-aggregate-design.sh <path-to-aggregates.md | domain-model.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-aggregate-design.sh <path-to-aggregates.md | domain-model.md>" >&2
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

def reason(v):
    parts = re.split(r"\s+[—–-]\s+", v, maxsplit=1)
    return parts[1].strip() if len(parts) == 2 and filled(parts[1]) else ""

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
lean = meta.get("name") == "domain-model"
required = ["name", "product", "version", "phase", "owner", "created", "summary", "traces-to"]
if not lean:
    required.insert(2, "bounded-context")
missing = [f for f in required if not filled(meta.get(f, ""))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is aggregate-design or domain-model", meta.get("name") in ("aggregate-design", "domain-model"))

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
    out = {}
    for r in table(lines)[1]:
        if len(r) >= 2:
            out[r[0].strip("* ").lower()] = r[1]
    return out

aggs = [b for b in blocks if b["title"].lower().startswith("aggregate:")]
cases = [b for b in blocks if b["title"].lower().startswith("use case:")]
check("has at least one '## Aggregate:' or '## Use case:' block", bool(aggs or cases))
unfilled = [b["title"] for b in aggs + cases if "[" in b["title"]]
check("no block heading left as a placeholder" + (f" ({', '.join(unfilled)})" if unfilled else ""), not unfilled)

NEEDS = r"temporal|retroactive|audit-as-record|audit as record|authoritative record|state as of|as of"
for b in aggs:
    name = b["title"].split(":", 1)[1].strip()
    subs = subsections(b["lines"])
    f = fields(subs[""])
    for key in ("root", "pattern", "identity", "concurrency", "event sourcing", "contention"):
        check(f"{name}: '{key}' is filled in", filled(f.get(key, "")))
    if lean:
        check(f"{name}: names its Bounded Context (lean document)", filled(f.get("context", "")))
    pat = f.get("pattern", "").lower()
    es_pat = "event-sourced" in pat or "event sourced" in pat
    check(f"{name}: pattern is Domain Model or Event-Sourced Domain Model (a Transaction Script or Active Record is a '## Use case:' block)", "domain model" in pat)
    check(f"{name}: the pattern gives its reason", bool(reason(f.get("pattern", ""))))
    es = f.get("event sourcing", "").lower()
    if es_pat:
        check(f"{name}: event sourcing names the need it meets (temporal query, retroactive projection or audit-as-record)", es.startswith("used") and bool(re.search(NEEDS, es)))
    else:
        check(f"{name}: event-sourcing field agrees with the pattern (not 'used' on a current-state Aggregate)", not es.startswith("used"))
    if re.search(r"\bcore\b", es) and not re.search(NEEDS, es):
        check(f"{name}: event sourcing is not justified by Core classification alone", False)
    conc = f.get("concurrency", "").lower()
    if filled(conc) and not conc.startswith("optimistic"):
        check(f"{name}: non-default concurrency names its condition", bool(reason(f.get("concurrency", ""))))
    ident = f.get("identity", "").lower()
    if ident.startswith("storage"):
        check(f"{name}: storage-generated identity gives a reason", bool(reason(f.get("identity", ""))))

    ih, irows = table(subs.get("invariants", []))
    irows = [r for r in irows if r and filled(r[0])]
    true_inv = [r for r in irows if len(r) >= 5 and "true invariant" in r[4].lower()]
    check(f"{name}: at least one True Invariant", bool(true_inv))
    for r in true_inv:
        ans = [c.strip().lower().rstrip(".") for c in r[1:4]]
        check(f"{name}: '{r[0][:60]}' answers yes / no / no", [a.split()[0] if a else "" for a in ans] == ["yes", "no", "no"])
    rh, rrows = table(subs.get("rejected candidates", []))
    if not [r for r in rrows if r and filled(r[0])]:
        warn(f"{name}: no rejected candidates recorded (record the rules you tested and turned away)")

    hh, hrows = table(subs.get("relationships to other aggregates", []))
    for r in [r for r in hrows if r and filled(r[0])]:
        g = lambda i: r[i] if i < len(r) else ""
        check(f"{name} → {g(0)}: has-a and must-be-atomic both answered", filled(g(1)) and filled(g(2)))
        ref = g(4).lower()
        check(f"{name} → {g(0)}: referenced by ID, not by object", "id" in re.findall(r"[a-z]+", ref) and not re.search(r"object|pointer|embed|contains|nested", ref))
        if "copy" in ref and "exception 2" not in ref and "exception 2" not in g(3).lower():
            warn(f"{name} → {g(0)}: a copied field without 'Exception 2' (a read-only copy needs the measured bottleneck written down)")

for b in cases:
    name = b["title"].split(":", 1)[1].strip()
    f = fields(subsections(b["lines"])[""])
    pat = f.get("pattern", "").lower()
    check(f"{name}: pattern is Transaction Script or Active Record", pat.startswith("transaction script") or pat.startswith("active record"))
    check(f"{name}: says why no Domain Model", bool(reason(f.get("pattern", ""))))
    if lean:
        check(f"{name}: names its Bounded Context (lean document)", filled(f.get("context", "")))

if lean:
    titles = [b["title"].lower() for b in blocks]
    for sec in ("domain events", "commands", "read models"):
        check(f"lean document has a '## {sec.title()}' section", sec in titles)
    ev = next((b for b in blocks if b["title"].lower() == "domain events"), None)
    if ev:
        eh, erows = table(ev["lines"])
        irregular = {"Sent", "Paid", "Made", "Held", "Won", "Lost", "Built", "Taken", "Given", "Written", "Run", "Begun", "Sold", "Bought", "Left", "Met", "Set", "Put", "Cut", "Shut", "Split", "Read", "Kept", "Done", "Drawn", "Withdrawn", "Chosen", "Frozen", "Spent", "Lent", "Sought", "Brought"}
        for r in [r for r in erows if len(r) > 1 and filled(r[1])]:
            words = re.findall(r"[A-Z][a-z]*", r[1].strip("` "))
            if words and not any(w.endswith("ed") or w in irregular for w in words):
                warn(f"event '{r[1]}' may not be past tense")

body = text[fm.end():] if fm else text
check("no code in the design (D047-10: code is go-domain-model's)", not re.search(r"```(go|golang|java|ts|typescript|python|csharp|kotlin|sql)\b|^\s*func \(|^\s*type \w+ struct|^\s*(public|private) class ", body, re.M))

print(f"INFO: {len(aggs)} Aggregate(s), {len(cases)} use case(s)")
sys.exit(1 if fails else 0)
PYEOF
