#!/bin/bash
# scripts/validate-broker-selection.sh — skill-owned script for skills/message-broker-selection.
# Purpose: mechanically check a Broker Selection Rationale
#          (artifacts/<product>/design/architecture/broker-selection.md) against
#          the structural items of resources/checklist.md: frontmatter; profile
#          and "Broker needed" lines; a need section; when a broker is needed, a
#          workloads table where every workload has a replay answer and a model,
#          no workload that needs replay on a queue, a decision with broker, why,
#          hosting and owner, retention and ADR, a reason when two models are
#          used, a delivery table with acknowledgement, retry, Dead Letter Queue
#          and alert (no auto-acknowledge, no Competing Consumers on a log);
#          when no broker is needed, no workload rows; revisit triggers and open
#          questions. Whether each choice is right stays with the agent.
# Usage:   validate-broker-selection.sh <file.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-broker-selection.sh <file.md>" >&2
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

def risk(c):
    return (c or "").strip().lower().startswith("risk-accepted")

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
    check("frontmatter name is broker-selection-rationale",
          bool(nm) and nm.group(1) == "broker-selection-rationale")
body = text[fm.end():] if fm else text
body = re.sub(r"<!--.*?-->", "", body, flags=re.S)

# --- sections ----------------------------------------------------------------
parts = re.split(r"^## (.+?)[ \t]*$", body, flags=re.M)
head = parts[0]
secs = {}
for i in range(1, len(parts), 2):
    secs[parts[i].strip().lower()] = parts[i + 1]

pm = re.search(r"\*\*Profile:\*\*\s*(\S+)", head)
profile = (pm.group(1).strip().lower() if pm else "")
check("profile is lean, standard or enterprise", profile in ("lean", "standard", "enterprise"))
bm = re.search(r"\*\*Broker needed:\*\*\s*(\S+)", head)
needed = (bm.group(1).strip().lower().rstrip(":,.") if bm else "")
check("'Broker needed' is yes or no", needed in ("yes", "no"))

check("section 'need for a broker' is present", "need for a broker" in secs)
check("need for a broker is explained", filled(secs.get("need for a broker", "").strip().split("\n")[0] if secs.get("need for a broker", "").strip() else ""))

if needed == "no":
    check("no broker: the need section names in-process events",
          "in-process" in secs.get("need for a broker", "").lower())
    check("no broker: the condition that would change it is named",
          bool(re.search(r"would change|until|when a|if a|once a|becomes", secs.get("need for a broker", "").lower())))
    wl = table(secs.get("workloads", ""))
    check("no broker: no workload rows", len(wl) == 0)
if profile == "lean" and needed == "yes":
    warn("lean profile with a broker: confirm a flow really leaves the deployable")

if needed == "yes":
    for need in ("workloads", "decision", "delivery"):
        check("section '%s' is present" % need, need in secs)

    wl = table(secs.get("workloads", ""))
    check("workloads table has at least one row", len(wl) > 0)
    models = set()
    for r in wl:
        name = r.get("workload", "?")[:40]
        replay = r.get("replay needed", "").strip().lower()
        model = r.get("broker model", "").strip().lower()
        check("workload '%s': a replay answer (yes or no) is given" % name,
              replay.startswith("yes") or replay.startswith("no"))
        check("workload '%s': model is log or queue" % name, model in ("log", "queue"))
        check("workload '%s': a why is given" % name, filled(r.get("why", "")))
        if model in ("log", "queue"):
            models.add(model)
        check("workload '%s': a workload that needs replay is not on a queue" % name,
              not (replay.startswith("yes") and model == "queue"))
        check("workload '%s': Competing Consumers is not used for a log" % name,
              not (model == "log" and re.search(r"competing consumers", " ".join(r.values()), re.I)
                   and not re.search(r"not|queue model|instead", " ".join(r.values()), re.I)))

    dec = secs.get("decision", "")
    for label in ("broker", "why this one", "hosting and owner", "retention", "adr"):
        m = re.search(r"\*\*%s:\*\*\s*(.+)" % re.escape(label), dec, re.I)
        check("decision: '%s' is filled" % label, bool(m) and filled(m.group(1)))
    if len(models) == 2:
        check("two models are used: the second broker's reason and cost are given",
              bool(re.search(r"second|two brokers|operating cost|both", dec, re.I)))

    dl = table(secs.get("delivery", ""))
    check("delivery table has at least one row", len(dl) > 0)
    for r in dl:
        name = r.get("broker", "?")[:30]
        for col, label in (("acknowledgement", "acknowledgement"), ("retry", "retry"),
                           ("dead letter queue", "Dead Letter Queue"), ("alert", "alert")):
            v = r.get(col, "")
            check("delivery '%s': %s is stated (or risk-accepted)" % (name, label), filled(v) or risk(v))
        ack = r.get("acknowledgement", "").lower()
        check("delivery '%s': no auto-acknowledge or commit before processing" % name,
              not re.search(r"auto[- ]?ack|before processing|before the work|at-most-once", ack) or risk(r.get("acknowledgement", "")))
        rt = r.get("retry", "").lower()
        check("delivery '%s': retry is not unlimited or for every failure" % name,
              not re.search(r"infinite|unlimited|forever|until it works|every failure|all failures", rt))

# --- whole-document checks ---------------------------------------------------
if re.search(r"^```", body, re.M):
    warn("a code block appears: the rationale names the choice, not code")
if re.search(r"exactly[- ]once", body, re.I) and not re.search(r"effectively|topic-to-topic|not exactly|no exactly|never exactly", body, re.I):
    warn("'exactly-once' appears without 'effectively-once' or a topic-to-topic transform")
check("'CDC' is not used for Consumer-Driven Contract",
      not re.search(r"consumer[- ]driven[^.\n]{0,30}\bCDC\b|\bCDC (test|contract)", body, re.I))
rv = secs.get("revisit when", "")
check("revisit triggers have at least one bullet", bool(re.search(r"^\s*[-*] \S", rv, re.M)))
oq = secs.get("open questions", "")
check("open questions has at least one bullet", bool(re.search(r"^\s*[-*] \S", oq, re.M)))

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
