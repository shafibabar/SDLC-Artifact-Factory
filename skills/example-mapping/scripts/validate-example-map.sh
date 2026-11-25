#!/bin/bash
# validate-example-map.sh — skill-owned script for skills/example-mapping.
# Purpose: mechanically check an Example Map
#          (artifacts/<product>/ideate/example-maps/US-n.md): frontmatter and
#          file name; no unfilled placeholders; required sections; the run mode
#          stated honestly with all three perspectives; each rule sourced, with
#          typed, filled examples that do not restate it; assumptions and
#          unknown outcomes tied to open questions; questions answered or moved
#          only with the product owner's dated reply; no Given/When/Then or
#          criterion IDs; counts; and a readiness verdict that matches the map
#          (ready needs no open question or assumption, a Happy and a Negative
#          example per rule and an Edge example). Whether an example is truly
#          concrete or a rule right stays with the agent.
# Usage:   validate-example-map.sh <US-n.md>
# Output:  one FAIL/WARN line per problem, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail; a truthful not-ready map passes), 1 if any check
#           fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-example-map.sh <US-n.md>" >&2
  exit 2
fi
if [ ! -f "$1" ]; then
  echo "error: file not found: $1" >&2
  exit 2
fi

python3 - "$1" <<'PYEOF'
import os, re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")
fails = passes = 0

def check(label, ok):
    global fails, passes
    if ok:
        passes += 1
    else:
        fails += 1
        print("FAIL: " + label)
    return ok

def warn(label):
    print("WARN: " + label)

def filled(c):
    return (c or "").strip() not in ("", "—", "-", "?", "...", "TBD", "tbd")

def table(raw):
    rows, header = [], None
    for line in raw.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue
        if header is None:
            header = [c.lower() for c in cells]
            continue
        rows.append(dict(zip(header, cells)))
    return rows

def norm(s):
    return " ".join(re.findall(r"[a-z0-9]+", s.lower()))

clean = re.sub(r"<!--.*?-->", "", text, flags=re.S)
fm = re.match(r"^---\n(.*?)\n---\n", clean, re.S)
check("frontmatter block is present", bool(fm))
front = {}
if fm:
    for line in fm.group(1).splitlines():
        m = re.match(r"^([A-Za-z_-]+):[ \t]*(.*)$", line)
        if m:
            front[m.group(1)] = m.group(2).strip().strip("\"'")
for key in ("name", "product", "story-id", "version", "phase", "owner", "created",
            "summary", "profile", "run", "readiness", "traces_to"):
    check("frontmatter has '%s'" % key, bool(front.get(key)))
check("frontmatter name is example-map", front.get("name") == "example-map")
check("frontmatter phase is ideate", front.get("phase") == "ideate")
check("profile is lean, standard or enterprise", front.get("profile") in ("lean", "standard", "enterprise"))
run = front.get("run", "")
check("run is agent-run or workshop", run in ("agent-run", "workshop"))
readiness = front.get("readiness", "")
check("readiness is ready or not-ready", readiness in ("ready", "not-ready"))
story = front.get("story-id", "")
check("story-id is US-n", bool(re.fullmatch(r"US-\d+[a-z]?", story)))
check("file name is <story-id>.md", os.path.basename(path) == story + ".md")
check("frontmatter has no 'ready-for-sprint' (use readiness)", "ready-for-sprint" not in front)

left = re.findall(r"<[^<>\n]+>", clean)
check("no unfilled <placeholder> remains%s" % ((": " + left[0][:40]) if left else ""), not left)

body = clean[fm.end():] if fm else clean
check("no Given/When/Then (acceptance-criteria writes it)",
      not re.search(r"(^[ \t]*(?:[-*][ \t]*)?(?:\*\*)?(?:Given|When|Then)\b)|(\|[ \t]*Given\b)|\bGiven\b[^\n]*\bWhen\b[^\n]*\bThen\b|```gherkin|^[ \t]*Scenario(?: Outline)?:", body, re.M))
check("no criterion IDs (AC-US-n.m is assigned by acceptance-criteria)", not re.search(r"\bAC-US-\d", body))

parts = re.split(r"^## (.+?)[ \t]*$", body, flags=re.M)
secs = {parts[i].strip().lower(): parts[i + 1] for i in range(1, len(parts), 2)}
for name in ("story", "how this map was made", "rules and examples",
             "questions for the product owner", "split check", "readiness"):
    check("section '%s' is present" % name, name in secs)

st = secs.get("story", "")
check("story card has As a / I want / so that",
      bool(re.search(r"\bAs an? .+\bI want\b.+\bso that\b", st, re.I | re.S)))
check("story states the seed example", bool(re.search(r"Seed example:[ \t]*\S", st)))

how = secs.get("how this map was made", "")
if run == "agent-run":
    check("agent-run map says one agent played the perspectives", bool(re.search(r"\bone agent\b", how, re.I)))
    check("agent-run map says no workshop or session was held",
          bool(re.search(r"\bno (?:workshop|session|meeting)\b", how, re.I)))
    check("agent-run map names what was read", bool(re.search(r"^[-*] Read:[ \t]*\S", how, re.M)))
if run == "workshop":
    check("workshop map names its participants", bool(re.search(r"Participants:[ \t]*\S", how)))
seen = {r.get("perspective", "").lower(): r.get("what it raised", "") for r in table(how)}
for p in ("customer", "developer", "tester"):
    check("perspective '%s' is recorded" % p, filled(seen.get(p)))

questions = {}
for r in table(secs.get("questions for the product owner", "")):
    qid = r.get("id", "")
    check("question id '%s' is a unique Q-n" % qid, bool(re.fullmatch(r"Q-\d+", qid)) and qid not in questions)
    questions[qid] = r

rsec = secs.get("rules and examples", "")
blocks = re.split(r"^### (R\d+):[ \t]*(.*)$", rsec, flags=re.M)
rules = [(blocks[i], blocks[i + 1].strip(), blocks[i + 2]) for i in range(1, len(blocks), 3)]
check("at least one rule (### R1: ...)", bool(rules))
check("every ### heading under rules is a numbered rule",
      len(re.findall(r"^### ", rsec, re.M)) == len(rules))
check("rule ids are unique", len({r[0] for r in rules}) == len(rules))

gaps, assumed, ex_ids, edges = [], [], set(), 0

def source_ref(src, where):
    # Only a cell (or ;-part) that starts with the word counts, so a path such as
    # ideate/assumption-tests/... or an outcome mentioning an "unknown" code does not.
    for kind, pattern in (("assumption", r"(?:^|;)\s*assumption\b(?!-)"),
                          ("unknown", r"^unknown\b(?=\s*(?:\(|$))")):
        if re.search(pattern, src, re.I):
            refs = re.findall(r"Q-\d+", src)
            assumed.append(where)
            check("%s: %s names an open question" % (where, kind),
                  bool(refs) and all(questions.get(q, {}).get("status", "").lower() == "open" for q in refs))

for rid, statement, block in rules:
    check("%s: has a statement" % rid, filled(statement))
    m = re.search(r"^[-*] Source:[ \t]*(.+)$", block, re.M)
    if check("%s: has a source" % rid, bool(m) and filled(m.group(1))):
        source_ref(m.group(1).strip(), rid)
    if re.search(r"\b(milliseconds?|ms|p9\d|uptime|latency|response time)\b|\b(loads?|responds?)\b.*\bseconds?\b", statement, re.I) \
            and "NFR-" not in statement:
        warn("%s looks like a quality target; cite the NFR ID instead of making it a rule" % rid)
    types = []
    for r in table(block):
        eid = r.get("example", "")
        check("example '%s' is a unique %s.En id" % (eid, rid),
              bool(re.fullmatch(re.escape(rid) + r"\.E\d+", eid)) and eid not in ex_ids)
        ex_ids.add(eid)
        kind = r.get("type", "")
        check("%s: type is Happy, Negative or Edge" % eid, kind in ("Happy", "Negative", "Edge"))
        types.append(kind)
        case, out, src = r.get("case", ""), r.get("expected outcome", ""), r.get("source", "")
        check("%s: case, expected outcome and source are filled" % eid, filled(case) and filled(out) and filled(src))
        check("%s: does not just restate the rule" % eid,
              norm(statement) not in (norm(case), norm(out), norm(case + " " + out)))
        source_ref(src, eid)
        source_ref(out, eid + " outcome")
        both = case + " " + out
        if filled(case) and not re.search(r"\d|[\"'“‘][^\"'”’]+[\"'”’]|(?<=[a-z,;] )[A-Z][a-z]+|^[A-Z][a-z]+ [a-z]+s\b", both):
            warn("%s may not be concrete: no number, quoted value or name" % eid)
    for need in ("Happy", "Negative"):
        if need not in types:
            gaps.append("%s has no %s example" % (rid, need))
    edges += types.count("Edge")
if not edges:
    gaps.append("the story has no Edge example")

open_q = []
for qid, r in questions.items():
    status, answer = r.get("status", "").lower(), r.get("answer", "")
    check("%s: question, affects, why it matters and recommendation are filled" % qid,
          all(filled(r.get(c)) for c in ("question", "affects", "why it matters", "recommendation")))
    check("%s: status is open, answered or moved" % qid, status in ("open", "answered", "moved"))
    by_owner = bool(re.search(r"product owner", answer, re.I) and re.search(r"\d{4}-\d{2}-\d{2}", answer))
    if status == "open":
        open_q.append(qid)
        check("%s: an open question has no answer yet" % qid, not filled(answer))
    elif status == "answered":
        check("%s: answered by the product owner, with a date" % qid, by_owner)
    elif status == "moved":
        others = [s for s in re.findall(r"US-\d+[a-z]?", answer) if s != story]
        check("%s: moved to another story, agreed by the product owner, with a date" % qid, by_owner and bool(others))

split = secs.get("split check", "")
m = re.search(r"Rules:[ \t]*(\d+).*?Open questions:[ \t]*(\d+)", split)
check("split check counts match the map (rules %d, open questions %d)" % (len(rules), len(open_q)),
      bool(m) and int(m.group(1)) == len(rules) and int(m.group(2)) == len(open_q))
d = re.search(r"Decision:[ \t]*(.+)", split)
check("split check states a decision", bool(d) and filled(d.group(1)))
if len(rules) >= 6 and not (d and "split" in d.group(1).lower()):
    warn("%d rules: consider proposing a split" % len(rules))

ready = secs.get("readiness", "")
v = re.search(r"\*\*Verdict:\*\*[ \t]*(.+)", ready)
verdict = v.group(1).strip().rstrip(".").lower() if v else ""
check("verdict matches frontmatter readiness",
      (verdict, readiness) in (("ready", "ready"), ("not ready", "not-ready")))
b = re.search(r"Blocking:[ \t]*(.+)", ready)
blocking = b.group(1).strip() if b else ""
listed = set(re.findall(r"Q-\d+", blocking))
check("blocking line lists exactly the open questions (or none)",
      bool(b) and listed == set(open_q) and (bool(open_q) or blocking.lower().startswith("none")))
if readiness == "ready":
    check("ready: no open question (%s)" % ", ".join(open_q), not open_q)
    check("ready: no assumption or unknown outcome (%s)" % ", ".join(assumed), not assumed)
    for g in gaps:
        check("ready: " + g, False)
    if not gaps:
        passes += 1
elif readiness == "not-ready":
    check("not-ready: at least one open question says what is blocking", bool(open_q))
    for g in gaps:
        warn(g)

print("%d check(s) passed, %d check(s) failed" % (passes, fails))
sys.exit(1 if fails else 0)
PYEOF
