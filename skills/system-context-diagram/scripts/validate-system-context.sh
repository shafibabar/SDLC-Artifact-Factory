#!/bin/bash
# scripts/validate-system-context.sh — skill-owned script for skills/system-context-diagram.
# Purpose: mechanically check a System Context diagram artifact
#          (artifacts/<product>/design/architecture/system-context.md) against
#          the structural items of resources/checklist.md: frontmatter; a title
#          stating type and scope; the question it answers; an ASCII diagram in
#          a fenced block; its readers named; a key that says what an arrow means; exactly one
#          system with a description; persons named as roles (no generic
#          "User"); no containers, technology or infrastructure as elements;
#          every catalog element named on the diagram and in a relationship;
#          every relationship touches the system, says what flows (no "uses"),
#          and is one-directional; rationale and boundary notes (with what is
#          out of scope) filled; Mermaid, if present, is a C4Context copy.
#          Whether the boundary is right stays with the agent.
# Usage:   validate-system-context.sh <path-to-system-context.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-system-context.sh <path-to-system-context.md>" >&2
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
    return bool(c) and c not in ("—", "-", "?") and not c.startswith("[")

# Frontmatter
fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "version", "phase", "owner", "created", "summary", "traces-to"]
def fm_ok(f):
    v = meta.get(f, "").strip()
    if f == "traces-to":  # a list: [a.md, b.md]
        return bool(re.search(r"\.md|/", v))
    return filled(v)
missing = [f for f in required if not fm_ok(f)]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is system-context-diagram", meta.get("name") == "system-context-diagram")
check("phase is design", meta.get("phase") == "design")
check("owner is enterprise-architect", meta.get("owner") == "enterprise-architect")

body = text[fm.end():] if fm else text
# Strip HTML comments (the optional Mermaid block lives in one in the template)
body_nc = re.sub(r"<!--.*?-->", "", body, flags=re.S)

title = re.search(r"^# (.+)$", body_nc, re.M)
check("title states type and scope ('# System Context diagram for <System>')",
      bool(title) and bool(re.match(r"(?i)system context diagram for \S", title.group(1).strip())))
check("names its readers", bool(re.search(r"(?im)^\*\*readers:?\*\*:?\s*[^\s\[]", body_nc)))
check("states the question the diagram answers", bool(re.search(r"(?im)^\*\*question it answers:?\*\*:?\s*\S", body_nc)))

sections, cur = {}, None
for line in body_nc.splitlines():
    h = re.match(r"^(#{2,3}) (.+)$", line)
    if h:
        cur = h.group(2).strip().lower(); sections[cur] = []
    elif cur is not None:
        sections[cur].append(line)

def sec(name):
    return "\n".join(sections.get(name, []))

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], [r for r in rows[1:] if r and filled(r[0])]) if rows else ([], [])

# Diagram
blocks = re.findall(r"```([a-zA-Z]*)\n(.*?)```", sec("diagram"), re.S)
ascii_blocks = [b for lang, b in blocks if lang.lower() not in ("mermaid",)]
check("Diagram section has an ASCII diagram in a fenced block (primary presentation)", bool(ascii_blocks))
diagram = ascii_blocks[0] if ascii_blocks else ""
diag_l = diagram.lower()
if diagram:
    check("diagram has no two-headed arrow (draw two arrows)",
          not re.search(r"◀[─—-]+▶|<-+>|<=+>|↔|⇄|◀-+▶|<[─]+>", diagram))
    check("diagram states element types in text ([Person], [Software System], [External System])",
          "[person]" in diag_l and ("[software system]" in diag_l or "[system]" in diag_l))

# Key
key = sec("key")
check("has a Key section", "key" in sections and bool(key.strip()))
check("Key says what an arrow means", bool(re.search(r"(?i)arrow", key)) and bool(re.search(r"(?i)start|initiat|depend|flow", key)))

# System
sysm = re.search(r"\*\*(.+?):\*\*\s*(.+)", sec("system"))
check("one system named with a description of what it does", bool(sysm) and filled(sysm.group(2)) if sysm else False)
system = sysm.group(1).strip() if sysm else ""
if system and diagram:
    check(f"the system '{system}' is named on the diagram", system.lower() in diag_l)

# Containers and infrastructure we would run. "Database" alone is not listed: an
# externally owned register or store is a legitimate external software system.
CONTAINER = re.compile(r"(?i)\b(postgres(ql)?|mysql|sqlite|mongo(db)?|redis|redpanda|kafka|rabbitmq|message broker|broker|kubernetes|k8s|docker|helm|linkerd|cdn|load balancer|api gateway|frontend|front end|backend|back end|react|spa|web app|mobile app|ios app|android app|microservices?|background worker|cron job|go application|our database)\b")
GENERIC = re.compile(r"(?i)^(the )?(users?|end users?|customers?|people|everyone|actors?)$")

_, persons = table(sections.get("persons", []))
check("at least one person", bool(persons))
for r in persons:
    name = r[0]
    check(f"person '{name}' is a role, not a generic 'User'", not GENERIC.match(name.strip()))
    check(f"person '{name}' says how they use the system", len(r) > 2 and filled(r[2]))

_, externals = table(sections.get("external systems", []))
if not externals:
    warn("no external systems: check identity, email, payments, regulators and downstream consumers")
for r in externals:
    name = r[0]
    check(f"external system '{name}' is a software system, not a container or infrastructure", not CONTAINER.search(name))
    check(f"external system '{name}' names its owner", len(r) > 1 and filled(r[1]))
    check(f"external system '{name}' says what it provides or receives", len(r) > 3 and filled(r[3]))

names = [r[0] for r in persons] + [r[0] for r in externals]
for n in names:
    if diagram:
        check(f"'{n}' appears on the diagram (name on one line)", n.lower() in diag_l)

# Containers drawn as boxes on the diagram: a box line with a container word that isn't a catalog name
if diagram:
    stray = set()
    for line in diagram.splitlines():
        for m in CONTAINER.finditer(line):
            if not any(m.group(0).lower() in n.lower() for n in names + [system]):
                stray.add(m.group(0))
    check("no containers, technology or infrastructure on the diagram" + (f" (found: {', '.join(sorted(stray))})" if stray else ""), not stray)

# Relationships
_, rels = table(sections.get("relationships", []))
check("at least one relationship", bool(rels))
VAGUE = re.compile(r"(?i)^(uses?|integrates?( with)?|interacts?( with)?|talks? to|calls?|connects?( to)?|communicates?( with)?|data|sync(s|hroni[sz]es)?)$")
touched = set()
def is_sys(x):
    return system and x.strip().lower() == system.lower()
for r in rels:
    frm, to = r[0], (r[1] if len(r) > 1 else "")
    what = r[2] if len(r) > 2 else ""
    label = f"relationship {frm} → {to}"
    check(f"{label}: touches the system", is_sys(frm) or is_sys(to))
    check(f"{label}: says what flows (not 'uses' / 'integrates with')", filled(what) and not VAGUE.match(what.strip()))
    check(f"{label}: one direction (no 'both ways' / two-headed)", not re.search(r"(?i)↔|<->|both ways|bidirectional|two-way", " ".join(r)))
    other = to if is_sys(frm) else frm
    if not (is_sys(frm) or is_sys(to)):
        continue
    if other.strip().lower() not in [n.lower() for n in names]:
        check(f"{label}: '{other}' is in the element catalog", False)
    touched.add(other.strip().lower())
for n in names:
    check(f"'{n}' has at least one relationship", n.lower() in touched)

# Rationale and boundary notes
check("Rationale filled", any(filled(l) for l in sections.get("rationale", []) if l.strip()))
bn = {}
for l in sections.get("boundary notes", []):
    m = re.match(r"^\s*-\s*\*\*(.+?):?\*\*:?\s*(.*)$", l)
    if m:
        bn[m.group(1).strip(": ").lower()] = m.group(2).strip()
check("Boundary Notes state the constraints", filled(bn.get("constraints", "")))
check("Boundary Notes state what is out of scope", filled(bn.get("out of scope", "")))

# Mermaid, if present
mer = re.findall(r"```mermaid\n(.*?)```", body_nc, re.S)
for m in mer:
    check("Mermaid copy uses C4Context, not flowchart", m.strip().lower().startswith("c4context"))
if mer and diagram == "":
    check("Mermaid is a copy; the ASCII diagram is primary", False)

print(f"INFO: system '{system or '?'}', {len(persons)} person(s), {len(externals)} external system(s), {len(rels)} relationship(s)")
sys.exit(1 if fails else 0)
PYEOF
