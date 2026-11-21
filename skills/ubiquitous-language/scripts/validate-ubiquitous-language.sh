#!/bin/bash
# scripts/validate-ubiquitous-language.sh — skill-owned script for skills/ubiquitous-language.
# Purpose: mechanically check one Bounded Context's ubiquitous-language.md
#          against the structural items of resources/ul-checklist.md:
#          frontmatter, a type, a domain-words meaning and a source per term,
#          rules for every Entity and Aggregate Root, a Given/When/Then for
#          every Aggregate Root and Policy, a Banned Synonyms table the drift
#          hook can read (no banned word that is also a term here), rename
#          status per ban, translations for homonyms, and open questions when
#          any term is *assumed*. Judgement calls (is this a real synonym,
#          is the meaning right) stay with the domain-modeler.
# Usage:   validate-ubiquitous-language.sh <path-to-ubiquitous-language.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-ubiquitous-language.sh <path-to-ubiquitous-language.md>" >&2
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

def filled(cell):
    return bool(cell) and not cell.startswith("[")

fm = {}
m = re.match(r"---\n(.*?)\n---\n", text, re.S)
if m:
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
for key in ("name", "version", "phase", "owner", "created", "summary", "bounded-context"):
    check(f"frontmatter has a non-empty `{key}`", filled(fm.get(key, "")))

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

def col(header, name):
    for i, h in enumerate(header):
        if name in h.lower():
            return i
    return None

def clean(w):
    return w.strip().strip("*`'\"").strip()

terms_lines = find("terms")
check("has a Terms section with a table", terms_lines is not None and bool(table(terms_lines)[1]))
header, rows = table(terms_lines)
ti, ty, me, ru, so = (col(header, n) for n in ("term", "type", "meaning", "rules", "source"))
types = {"entity", "value object", "aggregate root", "domain event", "command", "read model", "policy", "concept"}
terms, key_terms, assumed = [], [], 0
for r in rows:
    get = lambda i: r[i] if i is not None and i < len(r) else ""
    t = clean(get(ti)); terms.append(t.lower())
    typ = clean(get(ty)).lower()
    check(f"term '{t}' has a DDD type", any(typ.startswith(x) for x in types))
    check(f"term '{t}' has a meaning", filled(get(me)))
    if re.search(r"\b(a|one) (row|record|column|table|json)\b", get(me), re.I):
        check(f"term '{t}' is defined in domain words, not storage", False)
    check(f"term '{t}' has a source (artifact, session or *assumed*)", filled(get(so)))
    if "assumed" in get(so).lower():
        assumed += 1
    if typ.startswith(("entity", "aggregate root")):
        check(f"{typ} '{t}' states at least one rule that always holds", filled(get(ru)) and get(ru) not in ("—", "-"))
    if typ.startswith(("aggregate root", "policy")):
        key_terms.append(t)

ks = "\n".join(find("key scenarios") or [])
scenarios = re.findall(r"Scenario:", ks)
if key_terms:
    check("has a Key Scenarios section with at least one Given/When/Then", bool(scenarios) and "Given" in ks and "Then" in ks)
    for t in key_terms:
        check(f"key term '{t}' appears in a Key Scenario", t.lower() in ks.lower())

bans = find("banned synonyms")
check("has a Banned Synonyms section (the drift hook reads it)", bans is not None)
bh, brows = table(bans)
st = col(bh, "renamed")
for r in brows:
    if len(r) < 2:
        continue
    use = clean(r[1])
    for w in re.split(r"[,;]", r[0]):
        w = clean(w)
        if w:
            check(f"banned word '{w}' is not itself a term of this context", w.lower() not in terms)
    check(f"ban → '{use}' points to a term of this context", use.lower() in terms)
    if fm.get("profile", "") in ("standard", "enterprise"):
        check(f"ban → '{use}' records its rename status per medium", st is not None and st < len(r) and filled(r[st]))

hom = find("homonyms")
if hom is not None:
    hh, hrows = table(hom)
    tr = col(hh, "translation")
    for r in hrows:
        check(f"homonym '{clean(r[0])}' names its translation", tr is not None and tr < len(r) and filled(r[tr]))

if assumed:
    oq = find("open questions")
    check(f"{assumed} term(s) are *assumed*, so open questions for the product owner are listed", oq is not None and bool(table(oq)[1]))

if re.search(r"\b\w+V\d+\b", " ".join(terms), re.I) or any(t.startswith(("new", "real")) and t[3:4].isupper() for t in terms):
    warn("a version-suffixed or 'New…/Real…' term name: two models may be competing in one context")

print(f"INFO: {len(terms)} term(s), {assumed} *assumed*, {len(scenarios)} key scenario(s)")
sys.exit(1 if fails else 0)
PYEOF
