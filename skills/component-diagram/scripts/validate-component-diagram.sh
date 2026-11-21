#!/bin/bash
# scripts/validate-component-diagram.sh — skill-owned script for skills/component-diagram.
# Purpose: mechanically check a Component diagram artifact
#          (artifacts/<product>/design/<service>/component-diagram.md) against
#          the structural items of resources/checklist.md: frontmatter tracing
#          to the container diagram; title, readers, question; container
#          context; at least one named departure from the default skeleton (a
#          default service gets a one-line skip, not a diagram); an ASCII
#          picture with exactly one container boundary, no step numbers and no
#          two-way arrows; a key; every component with role, package, interface
#          and responsibility, named on the picture; relationships labelled,
#          no protocol between two components, no cycle between a pair; a
#          Dependency Rule statement; a named fitness function; variability
#          that doesn't assume a per-tenant stamp; rationale; open questions.
#          Whether the departures justify the diagram stays with the agent.
# Usage:   validate-component-diagram.sh <component-diagram.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-component-diagram.sh <component-diagram.md>" >&2
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

def norm(x):
    return re.sub(r"\s+", " ", x.strip().strip("`").strip()).lower()

# Frontmatter
fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "service", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not (re.search(r"\.md|/", meta.get(f, "")) if f == "traces-to" else filled(meta.get(f, "")))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is component-diagram", meta.get("name") == "component-diagram")
check("owner is enterprise-architect", meta.get("owner") == "enterprise-architect")
check("traces-to includes the container diagram", "container-diagram" in meta.get("traces-to", ""))

body = re.sub(r"<!--.*?-->", "", text[fm.end():] if fm else text, flags=re.S)
title = re.search(r"^# (.+)$", body, re.M)
check("title states type and scope ('# Component diagram for <Service>')",
      bool(title) and bool(re.match(r"(?i)component diagram for \S", title.group(1).strip())))
check("names its readers", bool(re.search(r"(?im)^\*\*readers:?\*\*:?\s*[^\s\[]", body)))
check("states the question it answers", bool(re.search(r"(?im)^\*\*question it answers:?\*\*:?\s*\S", body)))

sections, cur = {}, None
for line in body.splitlines():
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

def bullets(name):
    out = {}
    for l in sections.get(name, []):
        m = re.match(r"^\s*-\s*\*\*(.+?):?\*\*:?\s*(.*)$", l)
        if m:
            out[m.group(1).strip(": ").lower()] = m.group(2).strip()
    return out

def filled_bullets(name):
    return [l for l in sections.get(name, []) if re.match(r"^\s*-\s+\S", l) and filled(re.sub(r"^\s*-\s+", "", l))]

check("Container Context filled", any(filled(l) for l in sections.get("container context", []) if l.strip()))
deps = filled_bullets("departures from the default")
check("names at least one departure from the default skeleton (a default service gets a one-line skip, not a diagram)", bool(deps))

# Diagram
blocks = re.findall(r"```([a-zA-Z]*)\n(.*?)```", sec("diagram"), re.S)
ascii_blocks = [b for lang, b in blocks if lang.lower() != "mermaid"]
check("Diagram section has an ASCII picture in a fenced block (primary presentation)", bool(ascii_blocks))
diagram = ascii_blocks[0] if ascii_blocks else ""
dl = diagram.lower()
if diagram:
    frames = re.findall(r"(?m)^\s*[+┌][-─=]+.*\[container:", dl)
    check(f"exactly one container boundary on the picture (found {len(frames)})", len(frames) == 1)
    check("no step numbers on the picture (a module view has no time dimension)",
          not re.search(r"(?i)\bstep\s*\d|\(\s*\d+\s*\)|[①②③④⑤⑥⑦⑧⑨]|(?:^|\s)#\d+\b|^\s*\d+[.)]\s", diagram, re.M))
    check("no two-way arrows", not re.search(r"◀[─—-]+[^\n◀▶]*?[─—-]*▶|<[-=─]+[^<>\n]*?[-=─]*>|↔|⇄", diagram))
    check("components are tagged ([Component: ...])", "[component:" in dl)

key = sec("key")
check("Key says what an arrow means", bool(re.search(r"(?i)arrow|depends on|─▶|-->|->", key)))
check("Key distinguishes implements (a port) from calls", bool(re.search(r"(?i)implement", key)))

# Components
_, comps = table(sections.get("components", []))
check("at least two components", len(comps) >= 2)
cnames = set()
for r in comps:
    g = lambda i: r[i] if i < len(r) else ""
    name, role, pkg, iface, resp = g(0), g(1), g(2), g(3), g(4)
    cnames.add(norm(name))
    check(f"component '{name}': has a role", filled(role))
    check(f"component '{name}': has a package or module", filled(pkg))
    check(f"component '{name}': names the interface it presents", filled(iface))
    check(f"component '{name}': has a responsibility", filled(resp))
    if re.search(r"(?i)\b(struct|class|function|method|query)\b", role):
        check(f"component '{name}' is a grouping behind an interface, not a {role}", False)
    if diagram:
        check(f"component '{name}' appears on the picture", name.lower() in dl)

# Relationships
_, rels = table(sections.get("relationships", []))
check("Relationships table lists at least one relationship", bool(rels))
PROTO = re.compile(r"(?i)\b(https?|grpc|sql|kafka|amqp|rest|websocket|topic|tcp)\b")
pairs = set()
for r in rels:
    g = lambda i: r[i] if i < len(r) else ""
    a, b, nature = norm(g(0)), norm(g(1)), g(2)
    check(f"relationship '{g(0)}' → '{g(1)}': nature stated", filled(nature))
    if a in cnames and b in cnames:
        check(f"relationship '{g(0)}' → '{g(1)}': no protocol between two components (in-process)", not PROTO.search(nature))
    pairs.add((a, b))
cycles = sorted({tuple(sorted(p)) for p in pairs if (p[1], p[0]) in pairs and p[0] != p[1]})
check("no two components depend on each other (cycle)" + (f" (found: {cycles[0][0]} ↔ {cycles[0][1]})" if cycles else ""), not cycles)

# Dependency rule, fitness function
dr = sec("dependency rule").lower()
check("Dependency Rule section says where ports are declared (the domain)", "domain" in dr and bool(re.search(r"port|interface", dr)))
check("Dependency Rule section says the domain imports only the standard library", "standard library" in dr or "stdlib" in dr)
ff = bullets("fitness function")
check("names a fitness function (the automated check)", filled(ff.get("check", "")))

# Variability
var = sec("variability")
check("Variability filled", any(filled(l) for l in sections.get("variability", []) if l.strip()))
if re.search(r"(?i)stamp|per[- ]tenant (instance|copy|deployment)|physical isolation", var):
    check("Variability doesn't assume a per-tenant stamp (cites multi-tenancy-design if it uses one)", "multi-tenancy" in var.lower())

check("Rationale has at least one entry", bool(filled_bullets("rationale")) or any(filled(l) for l in sections.get("rationale", []) if l.strip()))
check("Open Questions section present", "open questions" in sections)

for m in re.findall(r"```mermaid\n(.*?)```", body, re.S):
    if not ascii_blocks:
        check("Mermaid is an optional copy, not the only picture", False)

print(f"INFO: {len(comps)} component(s), {len(rels)} relationship(s), {len(deps)} departure(s)")
sys.exit(1 if fails else 0)
PYEOF
