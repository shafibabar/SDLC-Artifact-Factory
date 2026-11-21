#!/bin/bash
# scripts/validate-pattern-rationale.sh — skill-owned script for skills/context-map-patterns.
# Purpose: mechanically check the Relationships table of design/context-map.md
#          against the structural items of resources/pattern-checklist.md:
#          one known pattern per line, a reason that names a rejected
#          alternative, a Contract column filled to match the pattern
#          (consumer-driven contract tests for Customer/Supplier; versioning
#          for Open Host Service; shared tests for Shared Kernel), no
#          Partnership where both sides have the same owner, and no code.
#          Warns on an Anticorruption Layer whose reason gives none of the
#          conditions that justify one. Judgement calls (is the upstream model
#          really good enough) stay with the agent.
# Usage:   validate-pattern-rationale.sh <path-to-context-map.md>
# Output:  one PASS/FAIL/WARN line per check, then counts per pattern.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-pattern-rationale.sh <path-to-context-map.md>" >&2
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
    c = c.strip()
    return bool(c) and not c.startswith("[") and c not in ("—", "-", "?")

PATTERNS = {
    "partnership": "Partnership",
    "shared kernel": "Shared Kernel",
    "customer/supplier": "Customer/Supplier",
    "conformist": "Conformist",
    "anticorruption layer": "Anticorruption Layer",
    "anti-corruption layer": "Anticorruption Layer",
    "acl": "Anticorruption Layer",
    "open host service": "Open Host Service",
    "ohs": "Open Host Service",
    "published language": "Published Language",
    "separate ways": "Separate Ways",
    "big ball of mud": "Big Ball of Mud",
}

def patterns_in(cell):
    found = set()
    low = cell.lower()
    for key, name in PATTERNS.items():
        if re.search(r"(?<![\w-])" + re.escape(key) + r"(?![\w-])", low):
            found.add(name)
    return found

secs, cur = {}, None
for line in text.splitlines():
    h = re.match(r"^## (.+)$", line)
    if h:
        cur = h.group(1).strip().lower(); secs[cur] = []
    elif cur is not None:
        secs[cur].append(line)

def find(prefix):
    for k, v in secs.items():
        if k.startswith(prefix):
            return v
    return None

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in (lines or []) if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], rows[1:]) if rows else ([], [])

# Owners per context, from bounded-context-mapping's ### sections.
owners, cur_ctx = {}, None
for line in find("contexts") or []:
    h = re.match(r"^### (.+)$", line)
    if h:
        cur_ctx = h.group(1).strip()
    elif cur_ctx and re.match(r"^\|\s*\*\*Owner\*\*", line):
        owners[cur_ctx.lower()] = line.strip().strip("|").split("|")[1].strip().lower()

rh, rows = table(find("relationships"))
def ci(name):
    for i, h in enumerate(rh):
        if name in h.lower():
            return i
    return None
u, d, p, why, con = (ci(n) for n in ("upstream", "downstream", "pattern", "reason", "contract"))
check("has a Relationships table with upstream, downstream, pattern, reason and contract columns", None not in (u, d, p, why, con))
if None in (u, d, p, why, con):
    sys.exit(1)
check("has at least one relationship line", bool(rows))

counts = {}
for r in rows:
    g = lambda i: r[i] if i < len(r) else ""
    line = f"{g(u)} → {g(d)}"
    pats = patterns_in(g(p))
    main = pats - {"Published Language"} if pats != {"Published Language"} else pats
    check(f"line {line}: one pattern from the catalogue", len(main) == 1)
    name = next(iter(main)) if len(main) == 1 else g(p)
    counts[name] = counts.get(name, 0) + 1
    reason = g(why)
    check(f"line {line}: the reason is filled in", filled(reason))
    rejected = patterns_in(reason) - {name}
    check(f"line {line}: the reason names a pattern considered and rejected", bool(rejected) or bool(re.search(r"\brejected\b|\binstead of\b", reason, re.I)))
    contract = g(con)
    check(f"line {line}: the contract is filled in", filled(contract))
    cl = contract.lower()
    if name == "Customer/Supplier":
        check(f"line {line}: Customer/Supplier carries consumer-driven contract tests", "contract test" in cl or "consumer-driven" in cl)
    if name == "Open Host Service":
        check(f"line {line}: Open Host Service carries versioned protocol discipline", "version" in cl)
    if name == "Shared Kernel":
        check(f"line {line}: Shared Kernel carries shared tests", "shared test" in cl or "tests" in cl)
    if name == "Partnership":
        ou, od = owners.get(g(u).strip("* ").lower()), owners.get(g(d).strip("* ").lower())
        check(f"line {line}: Partnership has two different owners (it needs two teams)", not (ou and od and ou == od))
    if name == "Anticorruption Layer" and not re.search(r"\bcore\b|messy|legacy|churn|changes often|unstable|differ|meaning|collision", reason, re.I):
        warn(f"line {line}: an Anticorruption Layer whose reason gives no justifying condition (Core downstream, messy or legacy upstream, churning contract, meanings that differ)")

check("no code in the rationale (D047-10)", not re.search(r"```(go|golang|java|ts|typescript|python)\b|^\s*func \(|^\s*type \w+ struct|^\s*import ", "\n".join(find("relationships") or []), re.M))

print("INFO: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
sys.exit(1 if fails else 0)
PYEOF
