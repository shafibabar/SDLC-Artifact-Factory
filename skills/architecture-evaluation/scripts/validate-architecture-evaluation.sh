#!/bin/bash
# scripts/validate-architecture-evaluation.sh — skill-owned script for skills/architecture-evaluation.
# Purpose: mechanically check an Architecture Evaluation
#          (artifacts/<product>/design/architecture/architecture-evaluation.md)
#          against the structural items of resources/checklist.md: frontmatter
#          with self-check: true; a profile and a self-check statement that says
#          "not independent" and "not an ATAM" and never claims an ATAM was
#          performed; scenarios that carry an NFR id, a rating and a response
#          measure; tactics questionnaire rows with a yes/partial/no answer;
#          every evaluated scenario covered by a questionnaire row, a risk or a
#          non-risk; risks with a decision and an action; non-risks with a
#          reason; sensitivity points with the response they govern; trade-off
#          points that raise one attribute and lower a different one and carry
#          an ADR, an accepted reason or a user decision; risk themes absent at
#          lean and tied to a business driver at enterprise; fitness functions
#          with a check and a place to run; the product owner's confirmation at
#          enterprise; open questions. Whether each judgement is right stays
#          with the agent.
# Usage:   validate-architecture-evaluation.sh <file.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-architecture-evaluation.sh <file.md>" >&2
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

# --- frontmatter ---------------------------------------------------------
fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
check("frontmatter block is present", bool(fm))
if fm:
    for key in ("name", "version", "phase", "owner", "created", "summary"):
        check("frontmatter has '%s'" % key, bool(re.search(r"^%s:\s*\S" % key, fm.group(1), re.M)))
    nm = re.search(r"^name:\s*(\S+)", fm.group(1), re.M)
    check("frontmatter name is architecture-evaluation", bool(nm) and nm.group(1) == "architecture-evaluation")
    check("frontmatter says self-check: true", bool(re.search(r"^self-check:\s*true\s*$", fm.group(1), re.M)))
body = text[fm.end():] if fm else text
body = re.sub(r"<!--.*?-->", "", body, flags=re.S)

parts = re.split(r"^## (.+?)[ \t]*$", body, flags=re.M)
head = parts[0]
secs = {}
for i in range(1, len(parts), 2):
    secs[parts[i].strip().lower()] = parts[i + 1]

pm = re.search(r"\*\*Profile:\*\*\s*(\S+)", head)
profile = (pm.group(1).strip().lower() if pm else "")
check("profile is lean, standard or enterprise", profile in ("lean", "standard", "enterprise"))

# --- the self-check statement ---------------------------------------------------
sc = re.search(r"\*\*Self-check:\*\*\s*(.+)", head)
sct = sc.group(1).lower() if sc else ""
check("a self-check statement is present", bool(sc) and filled(sc.group(1)))
check("the statement says it is not independent", "not independent" in sct or "not an independent" in sct)
check("the statement says it is not an ATAM", bool(re.search(r"not an atam|not a full atam", sct)))

bad_atam = False
for sent in re.split(r"(?<=[.!?])\s+|\n", body):
    if re.search(r"\bATAM\b", sent) and not re.search(r"\b(not|no|without|instead of|never|lighter|lightweight|rather than)\b", sent, re.I):
        bad_atam = True
check("ATAM is never claimed as the method performed", not bad_atam)
bad_indep = False
for sent in re.split(r"(?<=[.!?])\s+|\n", body):
    if re.search(r"independent(ly)?[- ](review|evaluat|assess)", sent, re.I) and not re.search(r"\b(not|no|never|without|rather than)\b", sent, re.I):
        bad_indep = True
check("no claim of an independent review", not bad_indep)

# --- scenarios ---------------------------------------------------------------------
sc_text = secs.get("scenarios evaluated", "")
none_high = bool(re.search(r"no scenario is rated high|none (is )?rated high|no scenario rated high", sc_text, re.I))
scen = table(sc_text)
ids = []
if none_high and profile == "lean":
    print("PASS: lean with no scenario rated high: stated in one sentence")
else:
    check("section 'scenarios evaluated' has at least one row", len(scen) > 0)
    for r in scen:
        sid = r.get("scenario", "?")
        m = re.match(r"(NFR-[A-Z]+-\d+)", sid)
        check("scenario '%s': carries an NFR id" % sid[:30], bool(m))
        if m:
            ids.append(m.group(1))
        check("scenario '%s': a rating is given" % sid[:30], filled(r.get("rating (value, impact)", "")))
        check("scenario '%s': a response measure is given" % sid[:30], filled(r.get("response measure", "")))
        check("scenario '%s': approaches are named" % sid[:30], filled(r.get("approaches that serve it", "")))
    if profile == "lean" and len(scen) > 3:
        warn("lean evaluates more than 3 scenarios: keep to the top 2 or 3")

    # --- questionnaire -------------------------------------------------------------------
    tq = table(secs.get("tactics questionnaire", ""))
    check("tactics questionnaire has at least one row", len(tq) > 0)
    for r in tq:
        nm = "%s / %s" % (r.get("scenario", "?")[:20], r.get("tactic family", "?")[:24])
        check("questionnaire '%s': the answer is yes, partial or no" % nm,
              r.get("answer", "").strip().lower() in ("yes", "partial", "no"))
        check("questionnaire '%s': the place in the design is given" % nm, filled(r.get("where in the design", "")))

risks = table(secs.get("risks", ""))
nonr = table(secs.get("non-risks", ""))
for r in risks:
    rid = r.get("id", "?")
    check("risk %s: names a scenario" % rid, bool(re.search(r"NFR-[A-Z]+-\d+", r.get("scenario", ""))))
    check("risk %s: names the decision" % rid, filled(r.get("decision", "")))
    check("risk %s: has an action" % rid, filled(r.get("action", "")))
for r in nonr:
    rid = r.get("id", "?")
    check("non-risk %s: states the reason it is safe" % rid, filled(r.get("reason it is safe", "")))

covered = set(re.findall(r"NFR-[A-Z]+-\d+", secs.get("tactics questionnaire", "") + secs.get("risks", "") + secs.get("non-risks", "")))
for sid in ids:
    check("scenario %s has a questionnaire row, a risk or a non-risk" % sid, sid in covered)
if profile != "lean" or not none_high:
    check("at least one risk or non-risk is recorded", len(risks) + len(nonr) > 0)

for r in table(secs.get("sensitivity points", "")):
    sid = r.get("id", "?")
    check("sensitivity point %s: names the property" % sid, filled(r.get("property", "")))
    check("sensitivity point %s: names the response it governs" % sid, filled(r.get("response it governs", "")))

# --- trade-off points -----------------------------------------------------------------
for r in table(secs.get("trade-off points", "")):
    tid = r.get("id", "?")
    up, down = r.get("raises", "").strip().lower(), r.get("lowers", "").strip().lower()
    check("trade-off %s: names the attribute it raises" % tid, filled(up))
    check("trade-off %s: names a different attribute it lowers" % tid, filled(down) and up != down)
    check("trade-off %s: says where it came from" % tid, filled(r.get("carried from", "")))
    res = r.get("resolution", "")
    check("trade-off %s: resolved by an ADR, an accepted reason or a user decision" % tid,
          bool(re.search(r"ADR-\d+|accepted, no ADR:\s*\S+|the user decides:\s*\S+", res, re.I)))

# --- risk themes ---------------------------------------------------------------------------
themes = table(secs.get("risk themes", ""))
if profile == "lean":
    check("lean has no risk themes", len(themes) == 0)
for r in themes:
    tid = r.get("id", "?")
    check("risk theme %s: groups at least two risks" % tid, len(re.findall(r"\bR-\d+", r.get("risks", ""))) >= 2)
    check("risk theme %s: names the systemic weakness" % tid, filled(r.get("systemic weakness", "")))
    check("risk theme %s: is tied to a business driver" % tid, filled(r.get("business driver threatened", "")))
if profile == "enterprise" and (risks or nonr):
    check("enterprise records at least one risk theme or states none", len(themes) > 0 or bool(re.search(r"no risk theme", body, re.I)))

# --- fitness functions ---------------------------------------------------------------------
ff = table(secs.get("fitness functions", ""))
if profile in ("standard", "enterprise"):
    check("fitness functions has at least one row", len(ff) > 0)
for r in ff:
    nm = r.get("characteristic", "?")[:30]
    check("fitness function '%s': an automated check is named" % nm, filled(r.get("check", "")))
    check("fitness function '%s': where it runs is stated" % nm, filled(r.get("where it runs", "")))
    check("fitness function '%s': an owner is named" % nm, filled(r.get("owner", "")))
    check("fitness function '%s': not a one-time review" % nm,
          not re.search(r"one[- ]time|once at the (design )?gate|manual review", r.get("check", ""), re.I))

# --- enterprise confirmation ----------------------------------------------------------------
if profile == "enterprise":
    m = re.search(r"\*\*Product owner confirmation:\*\*\s*(.+)", secs.get("confirmation", ""))
    check("enterprise records the product owner's confirmation", bool(m) and filled(m.group(1)))

if re.search(r"^```", body, re.M):
    warn("a code block appears: the record names findings, not code")
check("'CDC' is not used for Consumer-Driven Contract",
      not re.search(r"consumer[- ]driven[^.\n]{0,30}\bCDC\b|\bCDC (test|contract)", body, re.I))
oq = secs.get("open questions", "")
check("open questions has at least one bullet", bool(re.search(r"^\s*[-*] \S", oq, re.M)))

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
