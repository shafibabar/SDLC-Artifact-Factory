#!/bin/bash
# scripts/validate-event-driven-patterns.sh — skill-owned script for skills/event-driven-patterns.
# Purpose: mechanically check the "## Event-Driven Pattern Decisions" section
#          (a section of artifacts/<product>/design/architecture/integration-design.md,
#          or a draft file holding just that section) against the structural
#          items of resources/checklist.md: profile and broker lines; a flow
#          classification where every flow has communication, consistency and
#          coordination, never atomic and choreographed, and an orchestrated flow
#          pointing to workflow-orchestration; publication rows naming the
#          Transactional Outbox, Change Data Capture (with a reason it is
#          needed) or an in-process publisher; topics with a partition key that is
#          not random or round-robin and a stated ordering; consumers with dedup,
#          retry (transient only), a Dead Letter Queue and an alert; lean without
#          topics when there is no broker; open questions. Whether each choice is
#          right stays with the agent.
# Usage:   validate-event-driven-patterns.sh <file.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-event-driven-patterns.sh <file.md>" >&2
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
    return bool(c) and c not in ("—", "-", "?") and not c.startswith("[") and "[" not in c[:2]

def risk(c):
    return (c or "").strip().lower().startswith("risk-accepted")

# --- the section -------------------------------------------------------
m = re.search(r"^## Event-Driven Pattern Decisions[ \t]*$", text, re.M)
check("a '## Event-Driven Pattern Decisions' section is present", bool(m))
if not m:
    print("\n%d check(s) failed" % fails)
    sys.exit(1)
rest = text[m.end():]
nxt = re.search(r"^## (?!#)", rest, re.M)
body = rest[:nxt.start()] if nxt else rest

# strip HTML comments so template guidance is not read as content
body = re.sub(r"<!--.*?-->", "", body, flags=re.S)

# --- subsections and tables --------------------------------------------
parts = re.split(r"^### (.+?)[ \t]*$", body, flags=re.M)
head = parts[0]
subs = {}
for i in range(1, len(parts), 2):
    subs[parts[i].strip().lower()] = parts[i + 1]

def table(name):
    raw = subs.get(name, "")
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

# --- profile and broker -------------------------------------------------
pm = re.search(r"\*\*Profile:\*\*\s*(\S+)", head)
profile = (pm.group(1).strip().lower() if pm else "")
check("profile is lean, standard or enterprise", profile in ("lean", "standard", "enterprise"))
bm = re.search(r"\*\*Broker:\*\*\s*(.+)", head)
broker = bm.group(1).strip() if bm else ""
check("broker line is filled (a broker, or 'none: in-process events')", filled(broker))
no_broker = broker.lower().startswith("none")

# --- required subsections -----------------------------------------------
need = ["flow classification", "publication", "open questions"]
if not (profile == "lean" and no_broker):
    need += ["topics and ordering", "delivery and idempotency"]
for n in need:
    check("subsection '%s' is present" % n, n in subs)
if profile == "lean" and no_broker:
    check("lean with no broker has no topics or delivery tables",
          "topics and ordering" not in subs and "delivery and idempotency" not in subs)

# --- flow classification -------------------------------------------------
flows = table("flow classification")
check("flow classification has at least one row", len(flows) > 0)
for r in flows:
    name = r.get("flow", "?")[:40]
    comm = r.get("communication", "").strip().lower()
    cons = r.get("consistency", "").strip().lower()
    coord = r.get("coordination", "").strip().lower()
    check("flow '%s': communication is sync or async" % name, comm in ("sync", "async"))
    check("flow '%s': consistency is atomic or eventual" % name, cons in ("atomic", "eventual"))
    check("flow '%s': coordination is choreographed or orchestrated" % name,
          coord in ("choreographed", "orchestrated"))
    check("flow '%s': never atomic and choreographed" % name,
          not (cons == "atomic" and coord == "choreographed"))
    why = r.get("why", "")
    check("flow '%s': a why is given" % name, filled(why))
    if coord == "orchestrated":
        check("flow '%s': orchestrated, points to workflow-orchestration" % name,
              "workflow-orchestration" in why)

# --- publication ----------------------------------------------------------
pubs = table("publication")
check("publication has at least one row", len(pubs) > 0)
for r in pubs:
    name = r.get("publisher", "?")[:40]
    mech = r.get("mechanism", "").lower()
    ok_mech = any(k in mech for k in ("outbox", "change data capture", "in-process"))
    check("publisher '%s': mechanism is Outbox, Change Data Capture or in-process" % name, ok_mech)
    why = r.get("why", "")
    check("publisher '%s': a why is given" % name, filled(why))
    if "change data capture" in mech:
        check("publisher '%s': Change Data Capture says why the source cannot publish" % name,
              bool(re.search(r"legacy|cannot|can't|can not|vendor|third|unmodif|not ours|not own", why.lower())))
    check("publisher '%s': no dual write" % name, "dual write" not in mech or "no dual" in mech)

# --- topics ---------------------------------------------------------------
if "topics and ordering" in subs:
    tops = table("topics and ordering")
    check("topics table has at least one row", len(tops) > 0)
    for r in tops:
        name = r.get("topic", "?")[:40]
        key = r.get("partition key", "")
        check("topic '%s': partition key is filled" % name, filled(key))
        check("topic '%s': partition key is not random or round-robin" % name,
              not re.search(r"round[- ]robin|random", key.lower()))
        check("topic '%s': ordering guarantee is stated" % name, filled(r.get("ordering guaranteed", "")))
        check("topic '%s': consumer groups are named" % name, filled(r.get("consumer groups", "")))

# --- delivery --------------------------------------------------------------
if "delivery and idempotency" in subs:
    cons = table("delivery and idempotency")
    check("delivery table has at least one row", len(cons) > 0)
    for r in cons:
        name = r.get("consumer", "?")[:40]
        for col, label in (("dedup (key and store)", "dedup"), ("retry and backoff", "retry"),
                           ("dead letter queue", "Dead Letter Queue"), ("alert", "alert")):
            v = r.get(col, "")
            check("consumer '%s': %s is stated (or risk-accepted)" % (name, label), filled(v) or risk(v))
        dd = r.get("dedup (key and store)", "")
        check("consumer '%s': dedup is not 'none' without risk-accepted" % name,
              not re.match(r"^none\b", dd.strip().lower()) or risk(dd))
        rt = r.get("retry and backoff", "").lower()
        check("consumer '%s': retry is not unlimited or for every failure" % name,
              not re.search(r"infinite|unlimited|forever|until it works|every failure|all failures", rt))

# --- whole-section checks ---------------------------------------------------
check("'CDC' is not used for Consumer-Driven Contract",
      not re.search(r"consumer[- ]driven[^.\n]{0,30}\bCDC\b|\bCDC (test|contract)", body, re.I))
if re.search(r"exactly[- ]once", body, re.I) and not re.search(r"effectively|topic-to-topic", body, re.I):
    warn("'exactly-once' appears without 'effectively-once' or a topic-to-topic transform")
oq = subs.get("open questions", "")
check("open questions has at least one bullet", bool(re.search(r"^\s*[-*] \S", oq, re.M)))

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
