#!/bin/bash
# scripts/validate-container-diagram.sh — skill-owned script for skills/container-diagram.
# Purpose: mechanically check a Container diagram artifact
#          (artifacts/<product>/design/architecture/container-diagram.md) against
#          the structural items of resources/checklist.md: frontmatter tracing
#          to the system context; title, readers, question; a profile and a
#          deployables table where every split names its forces; an ASCII
#          container view with no deployment detail on it; a key; every
#          container typed, with technology, a deployable and a responsibility,
#          named on the diagram and in the communication matrix; no database
#          reached from another deployable; arrows say what flows, protocol,
#          sync or async; a topics table when there is a broker; the gateway
#          section (identity, planes); rationale and fitness functions; a
#          deployment view with a tenancy line, an environment, every
#          container mapped, and a variability line (or pending tenancy as an
#          open question; the environment is still drawn). With a second argument (the system context
#          artifact), persons and external systems must carry its names.
#          Whether the decomposition is right stays with the agent.
# Usage:   validate-container-diagram.sh <container-diagram.md> [system-context.md]
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-container-diagram.sh <container-diagram.md> [system-context.md]" >&2
  exit 2
fi
for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "error: file not found: $f" >&2
    exit 2
  fi
done

python3 - "$@" <<'PYEOF'
import re, sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
context = open(sys.argv[2], encoding="utf-8", errors="replace").read() if len(sys.argv) > 2 else None
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
required = ["name", "product", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not (re.search(r"\.md|/", meta.get(f, "")) if f == "traces-to" else filled(meta.get(f, "")))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is container-diagram", meta.get("name") == "container-diagram")
check("owner is enterprise-architect", meta.get("owner") == "enterprise-architect")
check("traces-to includes the system context diagram", "system-context" in meta.get("traces-to", ""))

body = re.sub(r"<!--.*?-->", "", text[fm.end():] if fm else text, flags=re.S)
title = re.search(r"^# (.+)$", body, re.M)
check("title states type and scope ('# Container diagram for <System>')",
      bool(title) and bool(re.match(r"(?i)container diagram for \S", title.group(1).strip())))
check("names its readers", bool(re.search(r"(?im)^\*\*readers:?\*\*:?\s*[^\s\[]", body)))
check("states the question it answers", bool(re.search(r"(?im)^\*\*question it answers:?\*\*:?\s*\S", body)))

# Sections (## and ###), keeping order for environments
sections, cur, order = {}, None, []
for line in body.splitlines():
    h = re.match(r"^(#{2,3}) (.+)$", line)
    if h:
        cur = h.group(2).strip().lower(); sections[cur] = []; order.append(cur)
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

# Decomposition
db_ = bullets("decomposition")
profile = db_.get("profile", "").lower().strip()
check("Decomposition states the profile (lean, standard or enterprise)", profile in ("lean", "standard", "enterprise"))
_, deps = table(sections.get("decomposition", []))
check("Decomposition lists at least one deployable", bool(deps))
FORCE = re.compile(r"(?i)scope|volatil|change rate|chang(es|ing) (far )?more|scal|throughput|burst|fault|isolat|security|regulat|extensib|transaction|chatt|workflow|shared code|data relationship|join|modular monolith")
deployables = {}
for r in deps:
    deployables[norm(r[0])] = r
    if len(deps) > 1 or profile != "lean":
        check(f"deployable '{r[0]}': names its forces (a disintegrator for a split, an integrator kept together)",
              len(r) > 3 and filled(r[3]) and bool(FORCE.search(r[3])))
if profile == "lean" and len(deps) > 1:
    warn(f"lean profile with {len(deps)} deployables: lean is one modular monolith unless a disintegrator is overwhelming")

# Diagram
blocks = re.findall(r"```([a-zA-Z]*)\n(.*?)```", sec("diagram"), re.S)
ascii_blocks = [b for lang, b in blocks if lang.lower() != "mermaid"]
check("Diagram section has an ASCII container view in a fenced block (primary presentation)", bool(ascii_blocks))
diagram = ascii_blocks[0] if ascii_blocks else ""
dl = diagram.lower()
PLACEMENT = re.compile(r"(?i)\breplicas?\b|[×✕]\s*\d|\bx\s?\d+\b|\b\d+\s?x\b|\bpods?\b|\bnode pool|\bnamespace|\bregion\b|\bavailability zone|\bport\s*:?\s*\d|:\d{4}\b|per[- ]tenant|\bstamps?\b|docker image|helm release")
found = sorted(set(m.group(0) for m in PLACEMENT.finditer(diagram)))
check("container view carries no deployment detail (pods, replicas, ports, regions, tenant copies)" + (f" (found: {', '.join(found)})" if found else ""), not found)
if diagram:
    check("diagram has no two-headed arrow", not re.search(r"◀[─—-]+▶|<-+>|<=+>|↔|⇄", diagram))
    check("diagram states container types in text ([Container: <type>])", "[container:" in dl)

key = sec("key")
check("Key says what an arrow means", bool(re.search(r"(?i)arrow", key)) and bool(re.search(r"(?i)start|initiat|caller|publisher", key)))
check("Key distinguishes synchronous and asynchronous", bool(re.search(r"(?i)\bsync", key)) and bool(re.search(r"(?i)async", key)))

# Containers
_, conts = table(sections.get("containers", []))
check("at least one container", bool(conts))
TYPES = ("web app", "mobile app", "api", "worker", "application", "database", "broker", "file store", "gateway", "job", "backend-for-frontend", "bff", "cache", "search index")
cmap = {}
for r in conts:
    g = lambda i: r[i] if i < len(r) else ""
    name, typ, tech, dep, resp = g(0), g(1), g(2), g(3), g(4)
    cmap[norm(name)] = (typ.lower(), norm(dep))
    check(f"container '{name}': has a known type", any(t in typ.lower() for t in TYPES))
    check(f"container '{name}': has a technology label", filled(tech))
    check(f"container '{name}': belongs to a deployable in the Decomposition table", norm(dep) in deployables)
    check(f"container '{name}': has a responsibility", filled(resp))
    if diagram:
        check(f"container '{name}' appears on the diagram (name on one line)", name.lower() in dl)
    if re.search(r"(?i)docker|image", name + " " + typ):
        check(f"container '{name}' is a runnable unit, not a Docker image", False)

# Persons and external systems
_, ext = table(sections.get("persons and external systems", []))
enames = {norm(r[0]): (r[1].lower() if len(r) > 1 else "") for r in ext}
for r in ext:
    if diagram:
        check(f"'{r[0]}' appears on the diagram", r[0].lower() in dl)
if context is not None:
    ctx_names = set()
    for sec_name in ("persons", "external systems"):
        m = re.search(r"(?ims)^### " + sec_name + r"\s*\n(.*?)(?=^##|\Z)", context)
        if m:
            _, rows = table(m.group(1).splitlines())
            ctx_names |= {norm(x[0]) for x in rows}
    for r in ext:
        check(f"'{r[0]}' carries its name from the system context diagram", norm(r[0]) in ctx_names)

# Communication matrix
_, rels = table(sections.get("communication matrix", []))
check("communication matrix has at least one row", bool(rels))
VAGUE = re.compile(r"(?i)^(uses?|calls?|talks? to|integrates?( with)?|interacts?( with)?|connects?( to)?|data|requests?)$")
known = set(cmap) | set(enames)
touched = set()
for r in rels:
    g = lambda i: r[i] if i < len(r) else ""
    frm, to, what, proto, mode = g(0), g(1), g(2), g(3), g(4).lower()
    lab = f"connector {frm} → {to}"
    check(f"{lab}: both ends are containers, persons or external systems in the catalog", norm(frm) in known and norm(to) in known)
    check(f"{lab}: says what flows", filled(what) and not VAGUE.match(what.strip()))
    check(f"{lab}: names a protocol", filled(proto))
    check(f"{lab}: says sync or async", mode.strip() in ("sync", "async", "synchronous", "asynchronous"))
    touched |= {norm(frm), norm(to)}
    for a, b in ((frm, to), (to, frm)):
        ca, cb = cmap.get(norm(a)), cmap.get(norm(b))
        if ca and cb and "database" in cb[0] and "database" not in ca[0] and ca[1] != cb[1]:
            check(f"{lab}: '{b}' is reached only from its own deployable (no shared database)", False)
for n in cmap:
    check(f"container '{n}' has at least one connector", n in touched)

# Broker and topics
if any("broker" in t for t, _ in cmap.values()):
    _, topics = table(sections.get("topics", []))
    check("a broker is present: the Topics table lists publisher and consumers per topic",
          bool(topics) and all(len(t) > 2 and filled(t[1]) and filled(t[2]) for t in topics))

# Gateway
gb = bullets("gateway")
check("Gateway section states gateway or none", filled(gb.get("gateway", "")))
check("Gateway section: services verify identity themselves", bool(re.search(r"(?i)verif", gb.get("identity", ""))))
check("Gateway section marks the north-south and east-west planes",
      bool(re.search(r"(?i)north", gb.get("planes", ""))) and bool(re.search(r"(?i)east", gb.get("planes", ""))))

# Rationale, fitness functions
check("Rationale filled", any(filled(l) for l in sections.get("rationale", []) if l.strip()))
_, ff = table(sections.get("fitness functions", []))
check("at least one fitness function (rule and automated check)", bool(ff) and all(len(x) > 1 and filled(x[1]) for x in ff))

# Deployment view
dv = bullets("deployment view")
ten = dv.get("tenancy", "")
check("Deployment View states the tenancy model (or pending multi-tenancy-design)", filled(ten))
oq = sec("open questions").lower()
if re.search(r"(?i)pending", ten):
    check("pending tenancy is listed as an open question", "multi-tenancy" in oq or "tenancy" in oq)
if True:  # what the NFRs fix is drawn even while tenancy is pending
    envs = [s for s in order if s.startswith("environment:")]
    check("Deployment View has at least one environment", bool(envs))
    if envs:
        _, maprows = table(sections.get(envs[0], []))
        mapped = {norm(r[0]) for r in maprows}
        for n in cmap:
            check(f"container '{n}' is mapped in the deployment view ({envs[0]})", n in mapped)
        allv = "\n".join("\n".join(sections.get(e, [])) for e in envs)
        check("Deployment View states what varies (variability)", bool(re.search(r"(?im)^\s*-\s*\*\*variability:?\*\*:?\s*\S", allv)) or filled(dv.get("variability", "")))

# Mermaid, if present
for m in re.findall(r"```mermaid\n(.*?)```", body, re.S):
    check("Mermaid copy uses C4Container or C4Deployment, not flowchart", re.match(r"(?i)\s*c4(container|deployment)", m) is not None)

print(f"INFO: profile '{profile or '?'}', {len(deps)} deployable(s), {len(conts)} container(s), {len(rels)} connector(s)")
sys.exit(1 if fails else 0)
PYEOF
