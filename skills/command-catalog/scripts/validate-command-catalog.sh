#!/bin/bash
# scripts/validate-command-catalog.sh — skill-owned script for skills/command-catalog.
# Purpose: mechanically check a design/<context>/command-catalog.md against the
#          structural items of resources/catalog-checklist.md: frontmatter;
#          every Command is a PascalCase imperative domain verb (no CRUD,
#          technical or query verb, no past tense, no suffix); intent, one
#          Aggregate, issuer, recorded event, idempotency key, duplicate
#          outcome, already-in-effect and concurrency are filled; a duplicate
#          returns the first outcome; a Policy issuer is written as a policy;
#          identity and tenant never come from the request; every rejection
#          has a known kind, and business rules are checked in the Aggregate;
#          no code, DDL or HTTP mapping (D047-10). Whether the name is the
#          right intent stays with the agent.
# Usage:   validate-command-catalog.sh <path-to-command-catalog.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-command-catalog.sh <path-to-command-catalog.md>" >&2
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
check("name is command-catalog", meta.get("name") == "command-catalog")

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

CRUD_FAIL = {"Update", "Set", "Edit", "Modify", "Change", "Save", "Patch", "Upsert", "Put"}
CRUD_WARN = {"Create", "Delete", "Add", "Remove", "Insert"}
TECH = {"Process", "Handle", "Do", "Manage"}
TECH_WARN = {"Execute", "Perform", "Run", "Trigger"}
QUERY = {"Get", "List", "Fetch", "Find", "Query", "Read", "Search", "Load", "Show", "View"}
NOT_PAST = {"Seed", "Need", "Feed", "Speed", "Breed", "Weed", "Embed", "Bleed", "Proceed", "Exceed", "Succeed", "Shed", "Wed"}
KINDS = ["invalid input", "not permitted", "not found", "reference invalid", "rule violated", "conflict"]
IDENTITY = {"tenantid", "tenant", "userid", "actorid", "issuedby", "issuerid", "callerid", "requestedby", "performedby"}

commands = [b for b in blocks if b["title"].lower().startswith("command:")]
check("has at least one '## Command:' block", bool(commands))
names = []
for b in commands:
    name = b["title"].split(":", 1)[1].strip().strip("`")
    names.append(name)
    words = re.findall(r"[A-Z][a-z0-9]*", name)
    first = words[0] if words else ""
    check(f"{name}: name is filled in (not a placeholder)", filled(name))
    check(f"{name}: PascalCase", bool(re.fullmatch(r"(?:[A-Z][a-z0-9]+)+", name)))
    check(f"{name}: no 'Command' suffix or version", not re.search(r"(Command|Cmd|V\d+)$", name))
    check(f"{name}: imperative, not a past-tense fact (that is an event)", not (first.endswith("ed") and first not in NOT_PAST))
    check(f"{name}: not a query verb ({first})" if first in QUERY else f"{name}: not a query verb", first not in QUERY)
    check(f"{name}: no CRUD verb as the intent" + (f" ({first})" if first in CRUD_FAIL else ""), first not in CRUD_FAIL)
    check(f"{name}: no technical verb as the intent" + (f" ({first})" if first in TECH else ""), first not in TECH)
    if first in TECH_WARN:
        warn(f"{name}: '{first}' says little about the intent; the language usually has a sharper verb")
    if first in CRUD_WARN:
        warn(f"{name}: '{first}' is usually a database verb; the language often has a better word for the intent")

    subs = subsections(b["lines"])
    f = fields(subs[""])
    for key in ("intent", "aggregate", "issued by", "records", "idempotency key", "on a duplicate", "already in effect", "concurrency"):
        check(f"{name}: '{key}' is filled in", filled(f.get(key, "")))
    agg = re.split(r"\s[—–-]\s|\(", f.get("aggregate", ""))[0]
    check(f"{name}: targets one Aggregate", filled(agg) and not re.search(r",|\+|&|\band\b|/", agg))
    rec = f.get("records", "")
    check(f"{name}: records an event (a Command that records nothing is a query or a gap)", filled(rec) and not re.match(r"(?i)\s*(none|nothing|n/a)", rec))
    dup = f.get("on a duplicate", "")
    check(f"{name}: a duplicate returns the first outcome", bool(re.search(r"(?i)\b(first|original|same)\b", dup)) and not re.search(r"(?i)\b(re-?runs?|re-?applies|applies again|processed again)\b", dup))
    iss = f.get("issued by", "")
    if re.search(r"(?i)\bpolicy\b", iss):
        check(f"{name}: a Policy issuer is written as 'Whenever …, then …'", bool(re.search(r"(?i)\bwhenever\b.*\bthen\b", iss)))
        key = f.get("idempotency key", "").lower()
        if "event" not in key:
            warn(f"{name}: issued by a Policy; the triggering event's ID is the usual idempotency key")
    if re.search(r"(?i)server.generated|generated (by the server|per request)|new (uuid|id) per request", f.get("idempotency key", "")):
        check(f"{name}: idempotency key is stable across retries (not generated per request)", False)

    ih, irows = table(subs.get("inputs", []))
    irows = [r for r in irows if r and filled(r[0])]
    for r in irows:
        n = re.sub(r"[`_\s-]", "", r[0]).lower()
        src = (r[2] if len(r) > 2 else "").lower()
        meaning = (r[1] if len(r) > 1 else "").lower()
        # "who inspected" is the issuer; "who will own it" is an ordinary input.
        issuer = re.match(r"\s*(who|the actor|the issuer)\b", meaning) and not re.search(r"\b(will|new|to be|goes|receives?|assigned to|instead)\b", meaning)
        if n in IDENTITY or "tenant" in n or issuer:
            check(f"{name}: input '{r[0]}' comes from the authenticated context, never the request", "context" in src and "request" not in src.replace("context", ""))

    rh, rrows = table(subs.get("rejections", []))
    rrows = [r for r in rrows if r and filled(r[0])]
    check(f"{name}: lists its rejections", bool(rrows))
    for r in rrows:
        kind = (r[1] if len(r) > 1 else "").lower().strip("* ")
        where = (r[2] if len(r) > 2 else "").lower()
        k = next((x for x in KINDS if kind.startswith(x)), None)
        check(f"{name}: rejection '{r[0]}' has a known kind" + ("" if k else f" ('{kind}' not in: {', '.join(KINDS)})"), bool(k))
        check(f"{name}: rejection '{r[0]}' says where it is checked", filled(where))
        if k == "rule violated":
            check(f"{name}: rule '{r[0]}' is checked in the Aggregate", "aggregate" in where)
        if k == "invalid input" and "aggregate" in where:
            warn(f"{name}: '{r[0]}' is marked invalid input but checked in the Aggregate; input checks need only the request")

dupes = sorted({x for x in names if names.count(x) > 1})
check("no Command appears twice" + (f" ({', '.join(dupes)})" if dupes else ""), not dupes)
summary = next((b for b in blocks if b["title"].lower() == "commands"), None)
if summary:
    sh, srows = table(summary["lines"])
    listed = {r[0].strip("` ") for r in srows if r and filled(r[0])}
    missing_blocks = sorted(listed - set(names))
    check("every Command in the summary table has a '## Command:' block" + (f" (missing: {', '.join(missing_blocks)})" if missing_blocks else ""), not missing_blocks)
else:
    check("has a '## Commands' summary table", False)

body = text[fm.end():] if fm else text
check("no code or DDL (D047-10: code belongs to go-service-layer and the go-* skills)", not re.search(r"```(go|golang|java|ts|typescript|python|csharp|kotlin|sql)\b|^\s*func \(|^\s*type \w+ struct|\bCREATE TABLE\b", body, re.M | re.I))
check("no HTTP mapping (methods, paths and status codes are api-contract-design's)", not re.search(r"\b(GET|POST|PUT|PATCH|DELETE)\s+/|\b[2-5]\d\d\s+(OK|Accepted|Created|No Content|Bad Request|Unauthori[sz]ed|Forbidden|Not Found|Conflict|Unprocessable)", body))

print(f"INFO: {len(commands)} Command(s)")
sys.exit(1 if fails else 0)
PYEOF
