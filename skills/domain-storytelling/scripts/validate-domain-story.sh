#!/bin/bash
# scripts/validate-domain-story.sh — skill-owned script for skills/domain-storytelling.
# Purpose: mechanically check one domain story against the structural items of
#          resources/story-checklist.md: the frontmatter and the three scope
#          factors with valid values, the run mode, one concrete case with no
#          branches or numbered sub-steps, every sentence with an actor,
#          activity, work object and source, no "the system" actor, no
#          software actor in a pure story (heuristic, warning), groups with a
#          hint, open questions and a written retelling when agent-run, and no
#          code. Judgement calls (is this the teller's word, is the group a
#          real boundary) stay with the domain-modeler.
# Usage:   validate-domain-story.sh <path-to-domain-story.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI arg, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-domain-story.sh <path-to-domain-story.md>" >&2
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
    return bool(c) and not c.startswith("[")

fm = {}
m = re.match(r"---\n(.*?)\n---\n", text, re.S)
if m:
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip()
for key in ("name", "scenario", "version", "phase", "owner", "created", "summary"):
    check(f"frontmatter has a non-empty `{key}`", filled(fm.get(key, "")))
gran, pit, pur = fm.get("granularity", ""), fm.get("point_in_time", ""), fm.get("purity", "")
check("granularity is coarse-grained or fine-grained", gran in ("coarse-grained", "fine-grained"))
check("point_in_time is as-is or to-be (one per story)", pit in ("as-is", "to-be"))
check("purity is pure or digitalised (not 'annotated')", pur in ("pure", "digitalised"))
run = fm.get("run", "")
check("run is agent-run or a dated workshop", run == "agent-run" or run.startswith("workshop"))

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

story = find("the story")
header, rows = table(story)
check("has a story table with at least one sentence", bool(rows))
cn, ca, cv, cw, cs = (col(header, n) for n in ("#", "actor", "activity", "work object", "source"))
assumed, numbers = 0, []
software = re.compile(r"\b(app|system|platform|portal|database|server|api|software|service)\b", re.I)
for r in rows:
    g = lambda i: r[i] if i is not None and i < len(r) else ""
    n = g(cn)
    numbers.append(n)
    if re.fullmatch(r"\d+[a-z]", n):
        check(f"sentence {n}: no numbered sub-steps (a variant is its own story)", False)
    for label, i in (("actor", ca), ("activity", cv), ("work object", cw), ("source", cs)):
        check(f"sentence {n}: the {label} is filled in", filled(g(i)))
    if re.fullmatch(r"(the )?system", g(ca).strip("* ").lower()):
        check(f"sentence {n}: the actor is named, not 'the system'", False)
    if re.match(r"^(if|else|otherwise|when not)\b", g(cv).lower()) or "?" in g(cv):
        check(f"sentence {n}: no branch in the activity (one concrete case)", False)
    if " and " in g(cv):
        warn(f"sentence {n}: activity '{g(cv)}' may be two verbs; one verb per sentence")
    if pur == "pure" and (software.search(g(ca)) or software.search(g(cw))):
        warn(f"sentence {n}: '{g(ca)} / {g(cw)}' looks like software in a pure story")
    if "assumed" in g(cs).lower():
        assumed += 1
nums = [int(x) for x in numbers if x.isdigit()]
if nums:
    check("sentences are numbered 1, 2, 3 … in order", nums == list(range(1, len(nums) + 1)))
if re.search(r"(?i)decision diamond|\byes branch\b|\bno branch\b|◇|◆", text):
    check("no decision diamond or yes/no branches (variants are separate stories)", False)

if gran == "coarse-grained":
    gl = find("groups")
    gh, grows = table(gl)
    hi = col(gh, "hint")
    if grows:
        check("every group records its hint", hi is not None and all(hi < len(r) and filled(r[hi]) for r in grows))
    else:
        warn("a coarse-grained story with no groups; boundary hints are its main use")

if run == "agent-run":
    tt = fm.get("traces-to", "")
    check("agent-run story lists its input artifacts in `traces-to`", bool(tt) and tt != "[]" and not tt.startswith("[the"))
    oq = find("open questions")
    if assumed:
        check(f"{assumed} sentence(s) are *assumed*, so open questions for the product owner are listed", oq is not None and bool(table(oq)[1]))
    rt = "\n".join(find("retelling") or [])
    check("agent-run story writes out the retelling for the product owner to check", bool(re.search(r"^\s*1\.\s+\S", rt, re.M)) and "[Sentence 1" not in rt)

check("no code in a design artifact (D047-10)", not re.search(r"```(go|golang|java|ts|typescript|python)\b|^\s*func \(|^\s*type \w+ struct", text, re.M))

print(f"INFO: {len(rows)} sentence(s), {assumed} *assumed*")
sys.exit(1 if fails else 0)
PYEOF
