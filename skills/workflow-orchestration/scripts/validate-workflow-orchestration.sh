#!/bin/bash
# scripts/validate-workflow-orchestration.sh — skill-owned script for skills/workflow-orchestration.
# Purpose: mechanically check a Workflow Orchestration Design
#          (artifacts/<product>/design/architecture/workflow-orchestration.md)
#          against the structural items of resources/checklist.md: frontmatter;
#          a profile line; an orchestration decision naming the trigger that
#          fired; and, per "## Saga:" section, a pivot line, a coordinator, a
#          persistence line (Outbox, one transaction, not in-memory), a steps
#          table with exactly one pivot, compensatable steps before it with a
#          compensation and captured data, retriable steps after it, a state
#          machine, timeouts with an expiry path, an isolation row per exposed
#          record with a known countermeasure, and open questions. Whether each
#          choice is right stays with the agent.
# Usage:   validate-workflow-orchestration.sh <file.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-workflow-orchestration.sh <file.md>" >&2
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

def subsections(raw):
    parts = re.split(r"^### (.+?)[ \t]*$", raw, flags=re.M)
    subs = {}
    for i in range(1, len(parts), 2):
        subs[parts[i].strip().lower()] = parts[i + 1]
    return parts[0], subs

# --- frontmatter ---------------------------------------------------------
fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
check("frontmatter block is present", bool(fm))
if fm:
    for key in ("name", "version", "phase", "owner", "created", "summary"):
        check("frontmatter has '%s'" % key, bool(re.search(r"^%s:\s*\S" % key, fm.group(1), re.M)))
    nm = re.search(r"^name:\s*(\S+)", fm.group(1), re.M)
    check("frontmatter name is workflow-orchestration-design",
          bool(nm) and nm.group(1) == "workflow-orchestration-design")
body = text[fm.end():] if fm else text
body = re.sub(r"<!--.*?-->", "", body, flags=re.S)

# --- profile --------------------------------------------------------------
pm = re.search(r"\*\*Profile:\*\*\s*(\S+)|^- \*\*Profile:\*\*\s*(\S+)", body, re.M)
profile = ((pm.group(1) or pm.group(2)) if pm else "").strip().lower()
check("profile is lean, standard or enterprise", profile in ("lean", "standard", "enterprise"))

# --- orchestration decision ----------------------------------------------
dm = re.search(r"^## Orchestration Decision[ \t]*$", body, re.M)
check("'## Orchestration Decision' section is present", bool(dm))
decisions = []
if dm:
    rest = body[dm.end():]
    nxt = re.search(r"^## ", rest, re.M)
    decisions = table(rest[:nxt.start()] if nxt else rest)
check("orchestration decision has at least one row", len(decisions) > 0)
triggers = ("branch", "loop", "long-running", "long running", "progress", "compensation across", "4+", "four")
for r in decisions:
    name = r.get("flow", "?")[:40]
    trig = r.get("trigger that fired", "")
    check("flow '%s': a Richardson trigger is named" % name,
          filled(trig) and any(t in trig.lower() for t in triggers))
    check("flow '%s': why not choreography is given" % name, filled(r.get("why not choreography", "")))
    check("flow '%s': a coordinator is chosen" % name, filled(r.get("coordinator", "")))

# --- sagas ----------------------------------------------------------------
sagas = [(m.group(1).strip(), m.start(), m.end()) for m in re.finditer(r"^## Saga: (.+?)[ \t]*$", body, re.M)]
check("at least one '## Saga:' section is present", len(sagas) > 0)
if profile == "lean" and sagas:
    warn("lean profile with an orchestrated saga: confirm the flow cannot stay choreographed or one local transaction")

for idx, (sname, start, end) in enumerate(sagas):
    stop = len(body)
    nxt = re.search(r"^## ", body[end:], re.M)
    if nxt:
        stop = end + nxt.start()
    sec = body[end:stop]
    head, subs = subsections(sec)
    tag = "saga '%s'" % sname[:40]

    pv = re.search(r"\*\*Pivot:\*\*\s*(.+)", head)
    check("%s: a pivot is named" % tag, bool(pv) and filled(pv.group(1)))
    co = re.search(r"\*\*Coordinator:\*\*\s*(.+)", head)
    check("%s: the coordinator is described" % tag, bool(co) and filled(co.group(1)))
    sp = re.search(r"\*\*State persistence:\*\*\s*(.+)", head)
    spt = sp.group(1).lower() if sp else ""
    check("%s: state persistence is stated" % tag, bool(sp) and filled(sp.group(1)))
    check("%s: persistence uses the Outbox in one transaction" % tag,
          "outbox" in spt and bool(re.search(r"one|single|same", spt)) and "transaction" in spt)
    check("%s: not held only in memory" % tag,
          not re.search(r"in[- ]memory", spt) or bool(re.search(r"(no|not|never|without)[^.]{0,20}in[- ]memory", spt)))
    bl = re.search(r"\*\*Business logic in the coordinator:\*\*\s*(.+)", head)
    check("%s: no business logic in the coordinator" % tag,
          bool(bl) and bl.group(1).strip().lower().startswith("none"))

    for need in ("steps", "state machine", "timeouts", "isolation"):
        check("%s: subsection '%s' is present" % (tag, need), need in subs)

    steps = table(subs.get("steps", ""))
    check("%s: steps table has at least one row" % tag, len(steps) > 0)
    classes = [r.get("class", "").strip().lower() for r in steps]
    for r, c in zip(steps, classes):
        nm = "%s step '%s'" % (tag, r.get("step (command)", "?")[:30])
        check("%s: class is compensatable, pivot or retriable" % nm,
              c in ("compensatable", "pivot", "retriable"))
        check("%s: owner is named" % nm, filled(r.get("owner", "")))
        comp = r.get("compensation", "")
        cap = r.get("captured on the way forward", "")
        if c == "compensatable":
            check("%s: a compensation is written" % nm,
                  filled(comp) and not comp.strip().lower().startswith("none"))
            check("%s: captured data is named" % nm,
                  filled(cap) and not re.search(r"look ?up|current state|re-?read", cap.lower())
                  and not cap.strip().lower().startswith("none"))
        elif c in ("pivot", "retriable"):
            check("%s: no compensation after the pivot commits" % nm,
                  comp.strip().lower().startswith("none") or comp.strip() in ("", "—", "-"))
    check("%s: exactly one pivot (two points of no return are two sagas)" % tag, classes.count("pivot") == 1)
    if classes.count("pivot") == 1:
        p = classes.index("pivot")
        check("%s: compensatable steps all come before the pivot" % tag,
              all(c != "compensatable" for c in classes[p + 1:]))
        check("%s: retriable steps all come after the pivot" % tag,
              all(c != "retriable" for c in classes[:p]))

    sm = table(subs.get("state machine", ""))
    check("%s: state machine has at least one row" % tag, len(sm) > 0)
    for r in sm:
        check("%s: state '%s' has a success and a failure transition" % (tag, r.get("state", "?")[:30]),
              filled(r.get("on success", "")) and filled(r.get("on failure", "")) or
              r.get("state", "").strip().lower() in ("completed", "compensated", "needs repair"))

    tms = table(subs.get("timeouts", ""))
    check("%s: timeouts table has at least one row" % tag, len(tms) > 0)
    for r in tms:
        wait = r.get("wait", "?")
        if wait.strip().lower().startswith("none"):
            continue
        check("%s: wait '%s' has a timeout" % (tag, wait[:30]), filled(r.get("timeout", "")))
        check("%s: wait '%s' has an expiry path" % (tag, wait[:30]), filled(r.get("when it expires", "")))

    iso = table(subs.get("isolation", ""))
    check("%s: isolation table has at least one row" % tag, len(iso) > 0)
    known = ("semantic lock", "commutative", "pessimistic view", "reread value", "by value", "by-value")
    for r in iso:
        rec = r.get("record exposed", "?")[:30]
        cm = r.get("countermeasure", "").lower()
        check("%s: record '%s' names an anomaly" % (tag, rec),
              any(a in r.get("anomaly possible", "").lower() for a in ("lost update", "dirty read", "fuzzy")))
        check("%s: record '%s' names a countermeasure (or risk-accepted)" % (tag, rec),
              any(k in cm for k in known) or risk(r.get("countermeasure", "")))
        if "semantic lock" in cm:
            rel = r.get("cleared by, and how a stale one is released", "")
            check("%s: record '%s' semantic lock says what clears it and how a stale one is released" % (tag, rec),
                  filled(rel) and bool(re.search(r"releas|expir|limit|sweep|timeout", rel.lower())))

# --- whole-document checks -------------------------------------------------
if re.search(r"^```", body, re.M):
    warn("a code block appears: the design names behaviour, not code")
check("no two-phase commit proposed",
      not re.search(r"two-phase commit|2pc|\bxa transaction", body, re.I) or
      bool(re.search(r"(no|not|never|without|instead of|replaces?)[^.\n]{0,40}(two-phase commit|2pc)", body, re.I)))
check("'CDC' is not used for Consumer-Driven Contract",
      not re.search(r"consumer[- ]driven[^.\n]{0,30}\bCDC\b|\bCDC (test|contract)", body, re.I))
oq = re.search(r"^## Open Questions[ \t]*$(.*)", body, re.M | re.S)
check("open questions has at least one bullet",
      bool(oq) and bool(re.search(r"^\s*[-*] \S", oq.group(1), re.M)))

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
