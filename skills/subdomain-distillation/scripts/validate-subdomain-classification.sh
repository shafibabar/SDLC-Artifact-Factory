#!/bin/bash
# scripts/validate-subdomain-classification.sh — skill-owned script for skills/subdomain-distillation.
# Purpose: mechanically check design/subdomain-classification.md against the
#          structural items of resources/classification-checklist.md: the
#          frontmatter and a classified-on date, a Big Picture in traces-to,
#          a valid type and all three tests answered on every row, sourcing
#          and modelling consistent with the type, a security result and a
#          revisit trigger on every row, few Core subdomains, and (standard /
#          enterprise) a Domain Vision Statement and Highlighted Core.
#          Judgement calls (is this really Core) stay with the domain-modeler.
# Usage:   validate-subdomain-classification.sh <path-to-subdomain-classification.md>
# Output:  one PASS/FAIL/WARN line per check, then counts per type.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-subdomain-classification.sh <path-to-subdomain-classification.md>" >&2
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
    return bool(c) and not c.startswith("[") and c not in ("—", "-")

fm = {}
m = re.match(r"---\n(.*?)\n---\n", text, re.S)
if m:
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
for key in ("name", "version", "phase", "owner", "created", "summary"):
    check(f"frontmatter has a non-empty `{key}`", filled(fm.get(key, "")))
check("frontmatter has a `classified-on` date", bool(re.match(r"\d{4}-\d{2}-\d{2}$", fm.get("classified-on", ""))))
tt = fm.get("traces-to", "")
if "event-storming" not in tt:
    check("drawn from the Event Storming Big Picture (named in `traces-to`), or marked provisional", "provisional" in text.lower())

secs, cur = {}, None
for line in text.splitlines():
    h = re.match(r"^## (.+)$", line)
    if h:
        cur = h.group(1).strip().lower(); secs[cur] = []
    elif cur is not None:
        secs[cur].append(line)

rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in secs.get("classification", []) if l.strip().startswith("|")]
rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
check("has a Classification table", len(rows) >= 2)
header, rows = (rows[0], rows[1:]) if rows else ([], [])

def col(*names):
    for i, h in enumerate(header):
        if any(n in h.lower() for n in names):
            return i
    return None

c_type, c_adv, c_cx, c_sol, c_src, c_mod, c_sec, c_rev = (col(n) for n in ("type", "advantage", "complex", "solved", "sourcing", "modelling", "security", "revisit"))
counts = {"core": 0, "supporting": 0, "generic": 0}
for r in rows:
    g = lambda i: r[i].strip("* ") if i is not None and i < len(r) else ""
    name = g(0)
    typ = g(c_type).lower().split()[0] if g(c_type) else ""
    check(f"'{name}': type is Core, Supporting or Generic", typ in counts)
    if typ in counts:
        counts[typ] += 1
    for label, i in (("advantage", c_adv), ("complexity", c_cx), ("solved elsewhere", c_sol)):
        check(f"'{name}': the {label} test is answered", filled(g(i)))
    src, mod = g(c_src).lower(), g(c_mod).lower()
    if typ == "core":
        check(f"'{name}': Core is built in-house, not bought or outsourced", "in-house" in src and "outsource" not in src and "buy" not in src)
        if c_mod is not None:
            check(f"'{name}': Core gets a Domain Model", "domain model" in mod)
    if typ == "generic":
        check(f"'{name}': Generic is bought or adopted", any(w in src for w in ("buy", "adopt", "bought")))
    if typ == "supporting":
        check(f"'{name}': Supporting is a cheap or careful build, or an outsourced build", any(w in src for w in ("build", "outsource")))
    check(f"'{name}': the security checklist result is recorded", filled(g(c_sec)))
    if typ != "generic":
        check(f"'{name}': has a revisit trigger", filled(g(c_rev)))

if counts["core"] == 0:
    warn("no Core subdomain: the product's advantage may lie outside software; say so explicitly")
if counts["core"] > 2:
    warn(f"{counts['core']} Core subdomains: expect one or two; rerun the three tests sceptically")

if fm.get("profile", "") in ("standard", "enterprise"):
    dvs = "\n".join(secs.get("domain vision statement", []))
    check("standard/enterprise: a Domain Vision Statement is written", len(dvs.strip()) > 80 and "[About a page" not in dvs)
    hc = "\n".join(secs.get("highlighted core", []))
    check("standard/enterprise: a Highlighted Core is written", len(hc.strip()) > 10 and "[The Bounded Contexts" not in hc)

print(f"INFO: {counts['core']} Core, {counts['supporting']} Supporting, {counts['generic']} Generic")
sys.exit(1 if fails else 0)
PYEOF
