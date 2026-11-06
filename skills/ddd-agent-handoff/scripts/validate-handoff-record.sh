#!/bin/bash
# scripts/validate-handoff-record.sh — skill-owned script for skills/ddd-agent-handoff.
# Purpose: mechanically check a hand-over record (artifacts/<product>/<phase>/
#          handoffs/<from>-to-<to>.md) against the structural items of
#          resources/checklist.md: frontmatter; from/to are real agents and
#          differ; owner is the producer; mode and status are known values;
#          every concern names an artifact and whether its Definition of Done
#          is met; the mode states why; every flag names an owner that is a
#          real agent and a known status, and is not owned by the agent that
#          raised it; an accepted record has every Definition of Done met and
#          no open flag; a paused or model-revision record has a matching
#          resumption kind and a next step naming who acts. Whether the
#          ownership is right stays with the agent.
# Usage:   validate-handoff-record.sh <path-to-handoff-record.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-handoff-record.sh <path-to-handoff-record.md>" >&2
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
AGENTS = {"product-strategist", "requirements-analyst", "domain-modeler", "enterprise-architect",
          "data-architect", "data-engineer", "backend-engineer", "frontend-engineer",
          "platform-engineer", "security-architect", "security-engineer", "test-strategist",
          "ux-architect"}

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
    return not (c.startswith("[") and not re.search(r"\.md|/", c.split("]")[0]))

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "version", "phase", "owner", "created", "summary", "from", "to", "mode", "status", "traces-to"]
missing = [f for f in required if not filled(meta.get(f, ""))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is handoff-record", meta.get("name") == "handoff-record")
frm, to = meta.get("from", ""), meta.get("to", "")
check(f"from is an agent of this plugin ({frm or 'empty'})", frm in AGENTS)
check(f"to is an agent of this plugin ({to or 'empty'})", to in AGENTS)
check("from and to differ", frm != to)
check("owner is the producing agent (from)", meta.get("owner") == frm)
mode = meta.get("mode", "").lower()
check("mode is 'hand-over' or 'joint review'", mode in ("hand-over", "joint review"))
status = meta.get("status", "").lower()
check("status is open, accepted, blocked, paused or model-revision", status in ("open", "accepted", "blocked", "paused", "model-revision"))

sections, cur = {}, None
for line in text[fm.end():].splitlines() if fm else text.splitlines():
    h = re.match(r"^## (.+)$", line)
    if h:
        cur = h.group(1).strip().lower(); sections[cur] = []
    elif cur is not None:
        sections[cur].append(line)

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], rows[1:]) if rows else ([], [])

def bullets(lines):
    out = {}
    for l in lines:
        m = re.match(r"^\s*-\s*\*\*(.+?):?\*\*:?\s*(.*)$", l)
        if m:
            out[m.group(1).strip(": ").lower()] = m.group(2).strip()
    return out

# Concerns
_, crow = table(sections.get("concerns handed over", []))
crow = [r for r in crow if r and filled(r[0])]
check("has at least one concern handed over", bool(crow))
dod_unmet = False
for r in crow:
    g = lambda i: r[i] if i < len(r) else ""
    check(f"concern '{g(0)}': names its artifact", filled(g(1)) and bool(re.search(r"\.md|/", g(1))))
    dod = g(2).lower().strip()
    check(f"concern '{g(0)}': says whether its Definition of Done is met (yes / no)", dod.startswith("yes") or dod.startswith("no"))
    if dod.startswith("no"):
        dod_unmet = True
        check(f"concern '{g(0)}': an unmet Definition of Done says what is missing", len(dod) > 3)

# Mode
mb = bullets(sections.get("mode", []))
check("Mode section states why", filled(mb.get("why", "")))
if mode == "joint review" and re.search(r"(?i)^\s*(hand-over: )?the default\b", mb.get("why", "")):
    check("joint review names its reason (Core subdomain, regulated data, disputed boundary, first hand-over)", False)

# Flags
_, frows = table(sections.get("flags back", []))
frows = [r for r in frows if len(r) >= 6 and filled(r[0]) and filled(r[1])]
open_flags = 0
for r in frows:
    raised, art, what, owner, st = r[1], r[2], r[3], r[4], r[5].lower()
    check(f"flag {r[0]}: names the artifact and what is wrong", filled(art) and filled(what))
    check(f"flag {r[0]}: owner is an agent of this plugin", owner in AGENTS)
    check(f"flag {r[0]}: raised by someone other than the owner (the owner fixes; others flag)", raised != owner)
    check(f"flag {r[0]}: status is open, fixed or declined", st.startswith(("open", "fixed", "declined")))
    if st.startswith("declined"):
        check(f"flag {r[0]}: a declined flag gives the reason", bool(re.match(r"declined\s*[:—-]\s*\S", st)))
    if st.startswith("open"):
        open_flags += 1

# Status rules
oq = [l for l in sections.get("open questions", []) if re.match(r"^\s*-\s*\S", l) and not re.match(r"^\s*-\s*(none|\[)", l, re.I)]
if status == "accepted":
    check("an accepted record has every Definition of Done met", not dod_unmet)
    check("an accepted record has no open flag", open_flags == 0)
    if oq:
        warn("accepted with open questions: make sure none blocks the receiver")
if status == "blocked":
    check("a blocked record states the blocking question", bool(oq) or open_flags > 0)
rb = bullets(sections.get("resumption", []))
if status in ("paused", "model-revision"):
    kind = rb.get("kind", "").lower()
    want = "operational pause" if status == "paused" else "model found wrong"
    check(f"a {status} record has resumption kind '{want}'", kind.startswith(want))
    nxt = rb.get("next step", "")
    check(f"a {status} record's next step names who acts", filled(nxt) and any(a in nxt for a in AGENTS))
    if status == "model-revision":
        check("a model found wrong lists downstream artifacts to review", bool(re.search(r"(?i)downstream|review", nxt)) and bool(re.search(r"\.md|/", nxt)))
elif rb and rb.get("kind", "").lower().startswith("model found wrong"):
    check("a model found wrong sets status model-revision (not resumed forward)", False)

print(f"INFO: {len(crow)} concern(s), {len(frows)} flag(s), {open_flags} open")
sys.exit(1 if fails else 0)
PYEOF
