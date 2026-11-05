#!/bin/bash
# scripts/validate-context-map.sh — skill-owned script for skills/bounded-context-mapping.
# Purpose: mechanically check design/context-map.md against the structural items
#          of resources/context-map-checklist.md: frontmatter and mode, the
#          subdomain classification among its inputs, each context with a
#          responsibility, subdomain, language pointer and cited boundary
#          evidence, no technical or team names, no deployable-service decision,
#          a target map, every relationship line with both ends known and its
#          pattern and reason filled (by context-map-patterns), and open
#          questions when evidence is *assumed*. Warns when every context owns
#          exactly one Aggregate. Judgement calls (is this really a language
#          change) stay with the domain-modeler.
# Usage:   validate-context-map.sh <path-to-context-map.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-context-map.sh <path-to-context-map.md>" >&2
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

fm = {}
m = re.match(r"---\n(.*?)\n---\n", text, re.S)
if m:
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
for key in ("name", "version", "phase", "owner", "created", "summary", "mode"):
    check(f"frontmatter has a non-empty `{key}`", filled(fm.get(key, "")))
check("drawn from the subdomain classification (named in `traces-to`)", "subdomain-classification" in fm.get("traces-to", ""))

# Split into ## sections and ### context subsections.
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

ctx_lines = find("contexts") or []
contexts, cur_ctx = {}, None
for line in ctx_lines:
    h = re.match(r"^### (.+)$", line)
    if h:
        cur_ctx = h.group(1).strip(); contexts[cur_ctx] = []
    elif cur_ctx:
        contexts[cur_ctx].append(line)
check("has at least one context defined under ## Contexts", bool(contexts))

technical = re.compile(r"\b(service|svc|api|db|database|worker|frontend|backend|mobile|web|team|module)\b", re.I)
assumed, single_agg = 0, 0
for name, lines in contexts.items():
    fields = {}
    for r in table(lines)[1] + ([table(lines)[0]] if table(lines)[0] else []):
        if len(r) >= 2:
            fields[r[0].strip("* ").lower()] = r[1]
    check(f"context '{name}' is named with a domain noun, not a technical or team name", not technical.search(name))
    for f in ("responsibility", "subdomain(s)", "boundary evidence", "language"):
        check(f"context '{name}': {f} is filled in", filled(fields.get(f, "")))
    if "assumed" in fields.get("boundary evidence", "").lower():
        assumed += 1
    if any("service" in k or "deploy" in k for k in fields):
        check(f"context '{name}': no deployable-service field (that's container-diagram's decision)", False)
    owns = fields.get("owns (aggregates)", "")
    if filled(owns) and len([x for x in re.split(r"[,;]", owns) if x.strip()]) == 1:
        single_agg += 1
if len(contexts) > 2 and single_agg == len(contexts):
    warn("every context owns exactly one Aggregate; contexts are language boundaries, not one per Aggregate")

tm = "\n".join(find("target map") or [])
check("has a target map", bool(re.search(r"```.*\S.*```", tm, re.S)) and "[plain-text" not in tm)

ext = [r[0].strip("* ") for r in table(find("external systems"))[1] if r and filled(r[0])]
known = {n.lower() for n in contexts} | {e.lower() for e in ext}
rh, rrows = table(find("relationships"))
def ci(name):
    for i, h in enumerate(rh):
        if name in h.lower():
            return i
    return None
u, d, p, why = ci("upstream"), ci("downstream"), ci("pattern"), ci("reason")
check("has a Relationships table with upstream, downstream, pattern and reason columns", None not in (u, d, p, why))
if None not in (u, d, p, why):
    for r in rrows:
        g = lambda i: r[i] if i < len(r) else ""
        line = f"{g(u)} → {g(d)}"
        check(f"line {line}: both ends are defined contexts or external systems", g(u).strip("* ").lower() in known and g(d).strip("* ").lower() in known)
        check(f"line {line}: pattern filled (from context-map-patterns)", filled(g(p)))
        check(f"line {line}: reason filled (from context-map-patterns)", filled(g(why)))

if assumed:
    oq = find("open questions")
    check(f"{assumed} context(s) rest on *assumed* evidence, so open questions for the product owner are listed", oq is not None and bool(table(oq)[1]))

print(f"INFO: {len(contexts)} context(s), {len(ext)} external system(s), {len(rrows)} line(s), {assumed} with *assumed* evidence")
sys.exit(1 if fails else 0)
PYEOF
