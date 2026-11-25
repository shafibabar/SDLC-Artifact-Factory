#!/bin/bash
# validate-criteria.sh — skill-owned script for skills/acceptance-criteria.
# Purpose: mechanically check a story's acceptance criteria
#          (artifacts/<product>/ideate/acceptance-criteria/US-n.md): frontmatter
#          and file name; no unfilled placeholders; the derived-from example map
#          exists, is this story's, is ready and has no open question; honest
#          run mode; a filled criterion under each of Happy, Negative and Edge;
#          every criterion has a unique AC-US-n.m ID, a From line citing real
#          map rules and examples, and a complete Given/When/Then (one When) or
#          Rule/Verify/Example body; every map rule has a criterion; no
#          ambiguous words, technical wording or response-time targets; a
#          filled out-of-scope list. Whether an outcome is truly observable or
#          says what was agreed stays with the agent.
# Usage:   validate-criteria.sh <US-n.md>
# Output:  one FAIL/WARN line per problem, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-criteria.sh <US-n.md>" >&2
  exit 2
fi
if [ ! -f "$1" ]; then
  echo "error: file not found: $1" >&2
  exit 2
fi

python3 - "$1" <<'PYEOF'
import os, re, sys

path = sys.argv[1]
fails = passes = 0

def read(p):
    return open(p, encoding="utf-8", errors="replace").read().replace("\r\n", "\n")

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

def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    out = {}
    if m:
        for line in m.group(1).splitlines():
            kv = re.match(r"^([A-Za-z_-]+):[ \t]*(.*)$", line)
            if kv:
                out[kv.group(1)] = kv.group(2).strip().strip("\"'")
    return m, out

def sections(body):
    parts = re.split(r"^## (.+?)[ \t]*$", body, flags=re.M)
    return {parts[i].strip().lower(): parts[i + 1] for i in range(1, len(parts), 2)}

clean = re.sub(r"<!--.*?-->", "", read(path), flags=re.S)
m, front = frontmatter(clean)
check("frontmatter block is present", bool(m))
for key in ("name", "product", "story-id", "version", "phase", "owner", "created",
            "summary", "profile", "run", "traces_to"):
    check("frontmatter has '%s'" % key, bool(front.get(key)))
check("frontmatter name is acceptance-criteria", front.get("name") == "acceptance-criteria")
check("frontmatter phase is ideate", front.get("phase") == "ideate")
check("profile is lean, standard or enterprise", front.get("profile") in ("lean", "standard", "enterprise"))
run = front.get("run", "")
check("run is agent-run or workshop", run in ("agent-run", "workshop"))
story = front.get("story-id", "")
check("story-id is US-n", bool(re.fullmatch(r"US-\d+[a-z]?", story)))
check("file name is <story-id>.md", os.path.basename(path) == story + ".md")

body = clean[m.end():] if m else clean
left = re.findall(r"<[^<>\n]+>", clean) + re.findall(r"\[[^\]\n]*[A-Za-z][^\]\n]*\](?!\()", body) \
    + re.findall(r"\bTBD\b|\?\?\?", body)
check("no unfilled placeholder remains%s" % ((": " + left[0][:40]) if left else ""), not left)
check("no assumption or unknown outcome (it goes back to the example map as a question)",
      not re.search(r"\b(assumption|assumed|unknown)\b[^\n]{0,20}\bQ-\d+|\bunknown \(", body, re.I))
check("heading is '# Acceptance Criteria: %s <title>'" % (story or "US-n"),
      bool(re.search(r"^# Acceptance Criteria: %s\b[ :\u2014-]*\S" % re.escape(story or "US-n"), body, re.M)))

secs = sections(body)
ref = secs.get("story reference", "")
check("story reference has As a / I want / so that",
      bool(re.search(r"\bAs an? .+\bI want\b.+\bso that\b", ref, re.I | re.S)))

how = secs.get("how these were made", "")
if run == "agent-run":
    check("agent-run file says one agent drafted it", bool(re.search(r"\bone agent\b", how, re.I)))
    check("agent-run file says no workshop or session was held",
          bool(re.search(r"\bno (?:workshop|session|meeting)\b", how, re.I)))
if run == "workshop":
    check("workshop file names its participants", bool(re.search(r"Participants:[ \t]*\S", how)))

# ---- the example map ----
derived = secs.get("derived from", "")
mp = re.search(r"Example map:[ \t]*`?(\S*?example-maps/(US-\d+[a-z]?)\.md)", derived)
named = check("Derived From names the story's own map (ideate/example-maps/%s.md)" % (story or "US-n"),
              bool(mp) and mp.group(2) == story)
rules, examples, edge_examples = [], [], []
if named:
    here = os.path.dirname(os.path.abspath(path))
    sibling = os.path.normpath(os.path.join(here, "..", "example-maps", story + ".md"))
    found = next((p for p in (sibling, mp.group(1)) if os.path.isfile(p)), None)
    if check("the example map file exists (%s)" % sibling, bool(found)):
        mclean = re.sub(r"<!--.*?-->", "", read(found), flags=re.S)
        _, mf = frontmatter(mclean)
        check("the map is this story's", mf.get("story-id") == story)
        check("the map is ready (readiness: ready)", mf.get("readiness") == "ready")
        msecs = sections(mclean)
        open_rows = [l for l in msecs.get("questions for the product owner", "").splitlines()
                     if re.match(r"^\|\s*Q-\d+", l) and re.search(r"\|\s*open\s*\|", l, re.I)]
        check("the map has no open question", not open_rows)
        rsec = msecs.get("rules and examples", "")
        rules = re.findall(r"^### (R\d+):", rsec, re.M)
        examples = re.findall(r"^\|\s*(R\d+\.E\d+)\s*\|", rsec, re.M)
        edge_examples = re.findall(r"^\|\s*(R\d+\.E\d+)\s*\|\s*Edge\s*\|", rsec, re.M)
        check("the map has rules to draw criteria from", bool(rules))

# ---- criteria ----
VAGUE = re.compile(r"\b(should|properly|easily|easy|quickly|quick|fast|user-friendly|intuitive|"
                   r"flexible|robust|seamless(?:ly)?|efficient(?:ly)?|gracefully|appropriate(?:ly)?|"
                   r"as needed|and/or|approximately|several)\b|\betc\b|(?<!\bas )\bwell\b(?!-)", re.I)
TECH = [re.compile(r"\b(GET|POST|PUT|PATCH|DELETE)\s+/"),
        re.compile(r"\bSELECT\b.+\bFROM\b|\bINSERT\s+INTO\b|\bUPDATE\s+\w+\s+SET\b", re.I),
        re.compile(r"\b[a-z]+(_[a-z]+)+\s*(=|==)\s*\S|\b[a-z_]+\.[a-z_]+\s*(=|==)\s*\S"),
        re.compile(r"`[^`\n]*[_./=(][^`\n]*`")]
TECH_WORD = re.compile(r"\bHTTP\b|\bJSON\b|\bendpoint\b|\bdatabase\b|\bstdout\b", re.I)
TARGET = re.compile(r"\b(milliseconds?|p9\d|latency|uptime|response time)\b|\b\d+ ?ms\b", re.I)
SOFT_TARGET = re.compile(r"\b(within|under|in less than) \d+ seconds?\b", re.I)

ANGLES = ("Happy Path", "Error / Negative Scenarios", "Boundary / Edge Cases")
ids, cited_rules, cited_examples, total = set(), set(), set(), 0
for angle in ANGLES:
    sec = secs.get(angle.lower(), "")
    parts = re.split(r"^### (.+?)[ \t]*$", sec, flags=re.M)
    crits = [(parts[i], parts[i + 1]) for i in range(1, len(parts), 2)]
    complete = 0
    for head, block in crits:
        total += 1
        hm = re.match(r"(AC-US-(\d+[a-z]?)\.(\d+)):[ \t]*(\S.*)$", head)
        cid = hm.group(1) if hm else head.split(":")[0]
        check("heading '%s' is '### AC-US-n.m: title' (AC-US-n.m is the only ID form)" % head[:40], bool(hm))
        if hm:
            check("%s: ID is AC-%s.m, this story's" % (cid, story), "US-" + hm.group(2) == story)
        check("%s: ID is unique" % cid, cid not in ids)
        ids.add(cid)
        fm_ = re.search(r"^[-*] From:[ \t]*(.+)$", block, re.M)
        refs_r = set(re.findall(r"\bR\d+\b(?!\.E)", fm_.group(1))) if fm_ else set()
        refs_e = set(re.findall(r"\bR\d+\.E\d+\b", fm_.group(1))) if fm_ else set()
        refs_r |= {e.split(".")[0] for e in refs_e}
        if check("%s: From line cites the map rule and example" % cid, bool(refs_e)) and rules:
            missing = sorted((refs_r - set(rules)) | (refs_e - set(examples)))
            check("%s: cited rules and examples exist in the map (%s)" % (cid, ", ".join(missing)), not missing)
        cited_rules |= refs_r
        cited_examples |= refs_e
        gm = re.findall(r"^```gherkin[ \t]*\n(.*?)^```", block, re.M | re.S)
        is_rule = bool(re.search(r"^\*\*Rule:\*\*", block, re.M))
        if not check("%s: is written as Gherkin or as Rule/Verify/Example" % cid, bool(gm) != is_rule):
            continue
        if gm:
            steps = [l.strip() for g in gm for l in g.splitlines() if l.strip()]
            keys, last = [], ""
            for s in steps:
                k = s.split()[0]
                if k in ("Given", "When", "Then"):
                    last = k
                    if len(s.split()) > 1:
                        keys.append(k)
                elif k in ("And", "But", "*") and last == "When":
                    keys.append("When")
            a = check("%s: has Given, When and Then, each with content" % cid,
                      len(gm) == 1 and {"Given", "When", "Then"} <= set(keys))
            b = check("%s: exactly one When (split a second action into the Given or another criterion)" % cid,
                      keys.count("When") <= 1)
            complete += a and b
            content = "\n".join(steps)
        else:
            vals = [re.search(r"^\*\*%s:\*\*[ \t]*(\S.*)$" % f, block, re.M) for f in ("Rule", "Verify", "Example")]
            complete += check("%s: Rule, Verify and Example are filled" % cid, all(vals))
            content = "\n".join(v.group(1) for v in vals if v)
        content = (hm.group(4) if hm else "") + "\n" + content
        unquoted = re.sub(r"\"[^\"\n]*\"|\u201c[^\u201d\n]*\u201d", '""', content)
        v = VAGUE.search(unquoted) or re.search(r"\bmay\b", unquoted)
        check("%s: no ambiguous word%s" % (cid, (" ('%s')" % v.group(0)) if v else ""), not v)
        t = next((x for x in (p.search(unquoted) for p in TECH) if x), None)
        check("%s: no technical wording%s" % (cid, (" ('%s')" % t.group(0)[:30]) if t else ""), not t)
        check("%s: no quality target (cite the NFR ID under Derived From)" % cid, not TARGET.search(unquoted))
        w = TECH_WORD.search(unquoted)
        if w:
            warn("%s says '%s'; keep it only if that is the user's own language" % (cid, w.group(0)))
        if SOFT_TARGET.search(unquoted):
            warn("%s looks like a speed target; if it is not a business rule, cite the NFR ID instead" % cid)
    check("'## %s' holds at least one criterion that is filled in" % angle, complete > 0)

headed = len(re.findall(r"^### AC-", body, re.M))
check("every criterion sits under Happy, Negative or Edge", headed <= total)
stray = re.findall(r"\bAC-(?!US-\d)[A-Za-z0-9-]*\d[A-Za-z0-9.-]*", body)
check("no other criterion ID scheme appears%s" % ((" (%s)" % stray[0]) if stray else ""), not stray)
if rules:
    uncovered = [r for r in rules if r not in cited_rules]
    check("every map rule has a criterion (missing: %s)" % ", ".join(uncovered), not uncovered)
    for e in examples:
        if e not in cited_examples:
            warn("map example %s is cited by no criterion; confirm it proves nothing the others do not" % e)
    if edge_examples and not set(edge_examples) & cited_examples:
        warn("no map Edge example is cited by any criterion")
if total > 12:
    warn("%d criteria (more than 12): propose a story split to the product owner" % total)

scope = secs.get("explicitly out of scope", "")
check("out of scope names at least one case", bool(re.search(r"^[-*][ \t]+\S", scope, re.M)))

print("%d check(s) passed, %d check(s) failed" % (passes, fails))
sys.exit(1 if fails else 0)
PYEOF
