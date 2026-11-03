#!/bin/bash
# scripts/validate-event-storming.sh — skill-owned script for skills/event-storming-facilitation.
# Purpose: mechanically check an Event Storming transcript (Big Picture, Process
#          Modelling or Software Design, told apart by its frontmatter `name`)
#          against the structural items of resources/session-checklist.md:
#          frontmatter and mode, a Source on every card, hotspots that are
#          questions and never marked resolved, boundary candidates with
#          evidence (Big Picture, every profile), no aggregates in a Big Picture,
#          policies in whenever/then form and stated stable ends (Process),
#          an invariant per aggregate and a language change per context
#          candidate (Software Design). Judgement calls (is this event a real
#          business fact, is the boundary right) stay with the domain-modeler.
# Usage:   validate-event-storming.sh <path-to-transcript.md>
# Output:  one PASS/FAIL/WARN line per check to stdout, then a count of
#          cards marked *assumed*.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-event-storming.sh <path-to-transcript.md>" >&2
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

fm = {}
m = re.match(r"---\n(.*?)\n---\n", text, re.S)
if m:
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
name = fm.get("name", "")
if name.startswith("event-storming-big-picture"):
    fmt = "big-picture"
elif name.startswith("event-storming-process"):
    fmt = "process"
elif name.startswith("event-storming-design-level"):
    fmt = "design"
else:
    fmt = ""
check("frontmatter name identifies the format (event-storming-big-picture | -process-<slug> | -design-level)", bool(fmt))
for key in ("version", "phase", "owner", "created", "summary", "mode"):
    check(f"frontmatter has a non-empty `{key}`", bool(fm.get(key)) and not fm.get(key, "").startswith("["))
mode = fm.get("mode", "")
if mode.startswith("agent-run"):
    tt = fm.get("traces-to", "")
    check("agent-run transcript lists its input artifacts in `traces-to`", bool(tt) and tt not in ("[]",) and not tt.startswith("[the"))

def sections(text):
    out, cur = {}, None
    for line in text.splitlines():
        h = re.match(r"^## (.+)$", line)
        if h:
            cur = h.group(1).strip().lower()
            out[cur] = []
        elif cur is not None:
            out[cur].append(line)
    return out

def table(lines):
    rows = [l for l in lines if l.strip().startswith("|")]
    rows = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    if not rows:
        return [], []
    return rows[0], rows[1:]

def col(header, *names):
    for i, h in enumerate(header):
        hl = h.lower()
        if any(n in hl for n in names):
            return i
    return None

def find(secs, *prefixes):
    for k, v in secs.items():
        if any(k.startswith(p) for p in prefixes):
            return v
    return None

secs = sections(text)

# A Source on every card, in every table that has a Source column.
assumed = 0
missing = 0
for title, lines in secs.items():
    header, rows = table(lines)
    i = col(header, "source")
    if i is None:
        continue
    for r in rows:
        cell = r[i] if i < len(r) else ""
        if not cell or cell.startswith("["):
            missing += 1
        if "assumed" in cell.lower():
            assumed += 1
check("every card in a table with a Source column has a source (artifact, session or *assumed*)", missing == 0)

# Technical events (heuristic, warning only).
tech = re.compile(r"\b\w*?(Row|Record|Table|Database|Db|Message|Api|Http|Request|Queue|Kafka)\w*(Inserted|Updated|Deleted|Published|Called|Sent|Received|Written)\b")
for title, lines in secs.items():
    header, rows = table(lines)
    i = col(header, "domain event")
    if i is None:
        continue
    for r in rows:
        if i < len(r) and tech.search(r[i]):
            warn(f"'{r[i]}' looks like a technical event, not a business fact")

# Hotspots: questions, an assumption meanwhile, never marked resolved.
hs_lines = find(secs, "hotspots", "breaks in the chain")
if hs_lines is not None:
    header, rows = table(hs_lines)
    q = col(header, "question")
    a = col(header, "assumed")
    check("hotspots table has a 'Question for the product owner' column", q is not None)
    if q is not None:
        check("every hotspot has a question for the product owner", all(q < len(r) and r[q] and not r[q].startswith("[") for r in rows))
    if a is not None:
        check("every hotspot states the assumption used meanwhile", all(a < len(r) and r[a] and not r[a].startswith("[") for r in rows))
    check("no hotspot is marked resolved", not any(re.search(r"\bresolved\b", " ".join(r), re.I) for r in rows))
    if not rows:
        warn("no hotspots recorded; a wall with none usually means disagreements were settled, not recorded")
else:
    check("has a Hotspots (or Breaks in the Chain) section", False)

if fmt == "big-picture":
    pe = find(secs, "pivotal events")
    check("Big Picture marks at least one pivotal event", pe is not None and len(table(pe)[1]) >= 1)
    bc = find(secs, "bounded context candidates")
    ok = False
    if bc is not None:
        header, rows = table(bc)
        e = col(header, "evidence")
        ok = bool(rows) and e is not None and all(e < len(r) and r[e] and not r[e].startswith("[") for r in rows)
    check("Big Picture records Bounded Context candidates with evidence (every profile, lean included)", ok)
    check("Big Picture names no aggregates (they belong to Software Design)", find(secs, "aggregates") is None)
    if re.search(r"\binvariants?\b|consistency units?", text, re.I):
        warn("a Big Picture mentions invariants or consistency units; aggregates under another name belong to Software Design")
    tl = find(secs, "timeline")
    check("Big Picture has a timeline table", tl is not None and len(table(tl)[1]) >= 1)

if fmt == "process":
    check("Process Modelling states its stable ends", bool(re.search(r"\*\*Stable ends:\*\*\s*\S", text)) and "[list each" not in text)
    pol = find(secs, "policies")
    if pol is not None:
        header, rows = table(pol)
        w = col(header, "whenever")
        t = col(header, "then")
        check("every policy reads whenever … then …", w is not None and t is not None and all(max(w, t) < len(r) and r[w] and r[t] for r in rows))
    paths = find(secs, "paths")
    check("Process Modelling has a paths table", paths is not None and len(table(paths)[1]) >= 1)

if fmt == "design":
    ag = find(secs, "aggregates")
    ok = False
    if ag is not None:
        header, rows = table(ag)
        inv = col(header, "invariant")
        ok = bool(rows) and inv is not None and all(inv < len(r) and r[inv] and not r[inv].startswith("[") for r in rows)
    check("every aggregate states the invariant that must hold at every instant", ok)
    bc = find(secs, "bounded context candidates")
    ok = False
    if bc is not None:
        header, rows = table(bc)
        lc = col(header, "language change")
        ok = bool(rows) and lc is not None and all(lc < len(r) and r[lc] and not r[lc].startswith("[") for r in rows)
    check("every Bounded Context candidate states the language change that justifies it", ok)

print(f"INFO: {assumed} card(s) marked *assumed*")
sys.exit(1 if fails else 0)
PYEOF
