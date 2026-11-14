#!/bin/bash
# scripts/validate-integration-design.sh — skill-owned script for skills/integration-design.
# Purpose: mechanically check an Integration Design artifact
#          (artifacts/<product>/design/architecture/integration-design.md) against
#          the structural items of resources/checklist.md: frontmatter; title,
#          readers, question, profile; an inventory where every row has a shape,
#          consistency, contract strictness, a contract test (never "CDC" for a
#          Consumer-Driven Contract) and resilience; sync rows with a timeout (or a
#          risk-accepted reason), retries only when idempotent or keyed, and at
#          standard/enterprise a breaker (or a risk-accepted reason); async rows
#          with outbox / idempotent consumer / DLQ (or Change Data Capture); a
#          detail block per sync row with timeout and retry; cross-context reads
#          naming one of the three options (never a shared database); no
#          request/reply over the broker; open questions.
#          Whether each choice is right stays with the agent.
# Usage:   validate-integration-design.sh <integration-design.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-integration-design.sh <integration-design.md>" >&2
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

def norm(x):
    return re.sub(r"\s+", " ", x.strip().strip("`").strip()).lower()

fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "version", "phase", "owner", "created", "summary", "traces-to"]
missing = [f for f in required if not (re.search(r"\.md|/", meta.get(f, "")) if f == "traces-to" else filled(meta.get(f, "")))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is integration-design", meta.get("name") == "integration-design")
check("owner is enterprise-architect", meta.get("owner") == "enterprise-architect")

body = re.sub(r"<!--.*?-->", "", text[fm.end():] if fm else text, flags=re.S)
title = re.search(r"^# (.+)$", body, re.M)
check("title states type and scope ('# Integration Design for <Product>')",
      bool(title) and bool(re.match(r"(?i)integration design for \S", title.group(1).strip())))
check("names its readers", bool(re.search(r"(?im)^\*\*readers:?\*\*:?\s*[^\s\[]", body)))
check("states the question it answers", bool(re.search(r"(?im)^\*\*question it answers:?\*\*:?\s*\S", body)))
pm = re.search(r"(?im)^\s*-\s*\*\*profile:?\*\*:?\s*(\w+)", body)
profile = pm.group(1).lower() if pm else ""
check("states the profile (lean, standard or enterprise)", profile in ("lean", "standard", "enterprise"))

sections, cur, order = {}, None, []
for line in body.splitlines():
    h = re.match(r"^(#{2,3}) (.+)$", line)
    if h:
        cur = h.group(2).strip().lower(); sections[cur] = []; order.append((len(h.group(1)), cur))
    elif cur is not None:
        sections[cur].append(line)

def sec(name):
    return "\n".join(sections.get(name, []))

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], [r for r in rows[1:] if r and filled(r[0])]) if rows else ([], [])

def bullets_of(lines):
    out = {}
    for l in lines:
        m = re.match(r"^\s*-\s*\*\*(.+?):?\*\*:?\s*(.*)$", l)
        if m:
            out[m.group(1).strip(": ").lower()] = m.group(2).strip()
    return out

# Inventory
_, inv = table(sections.get("integration inventory", []))
check("Integration Inventory lists at least one integration", bool(inv))
sync_rows = []
for r in inv:
    g = lambda i: r[i] if i < len(r) else ""
    frm, to, shape, cons, proto, strict, ctest, res = (g(i) for i in range(8))
    lab = f"'{frm}' → '{to}'"
    sh = shape.lower()
    is_event = bool(re.search(r"\bevent", sh)) and "request" not in sh
    is_sync = bool(re.search(r"request", sh))
    check(f"{lab}: shape is request/response, request/acknowledge or event", is_event or is_sync)
    check(f"{lab}: consistency is atomic or eventual", bool(re.search(r"(?i)\b(atomic|eventual)", cons)))
    check(f"{lab}: contract strictness is strict or loose", bool(re.search(r"(?i)\b(strict|loose)", strict)))
    check(f"{lab}: contract test stated (or 'none: <reason>')", filled(ctest))
    check(f"{lab}: contract test doesn't abbreviate Consumer-Driven Contract as CDC", not re.search(r"\bCDC\b", ctest))
    check(f"{lab}: resilience stated", filled(res))
    ra = re.search(r"(?i)risk-accepted", res)
    if ra:
        check(f"{lab}: a risk-accepted choice gives its reason", bool(re.search(r"(?i)risk-accepted\s*[:(—-]\s*\S", res)))
    if is_sync:
        sync_rows.append((frm, to))
        check(f"{lab}: a synchronous call has a timeout (or a risk-accepted reason)", bool(re.search(r"(?i)timeout", res)) or bool(ra))
        if re.search(r"(?i)retr", res):
            check(f"{lab}: retries only idempotent or keyed calls (or no auto-retry)",
                  bool(re.search(r"(?i)idempot|key|no auto-retry|reconcil|\bread", res)))
        if profile in ("standard", "enterprise"):
            check(f"{lab}: standard/enterprise sync call has a circuit breaker (or a risk-accepted reason)",
                  bool(re.search(r"(?i)breaker", res)) or bool(ra))
        if re.search(r"(?i)kafka|topic|broker|amqp", proto):
            check(f"{lab}: no request/reply over the broker", False)
    if is_event:
        check(f"{lab}: async integration names its mechanism (outbox, idempotent consumer, DLQ or Change Data Capture)",
              bool(re.search(r"(?i)outbox|idempot|dlq|dead letter|change data capture|event-driven-patterns", res)))

# Sync details
sd_heads = []
in_sync = False
for lvl, name in order:
    if lvl == 2:
        in_sync = (name == "synchronous integrations")
    elif lvl == 3 and in_sync:
        sd_heads.append(name)
if sync_rows:
    check("Synchronous Integrations has a detail block per sync row", len(sd_heads) >= len({(a.lower(), b.lower()) for a, b in sync_rows}))
for h in sd_heads:
    b = bullets_of(sections.get(h, []))
    check(f"sync detail '{h}': timeout stated", filled(b.get("timeout", "")))
    check(f"sync detail '{h}': retry stated", filled(b.get("retry", "")))
    rt = b.get("retry", "")
    if filled(rt) and not re.search(r"(?i)no auto-retry|none|not retried|^no\b", rt):
        check(f"sync detail '{h}': retry says idempotent or names the idempotency key",
              bool(re.search(r"(?i)idempot|key|\bread", rt)))

# Cross-context reads
_, reads = table(sections.get("cross-context reads", []))
for r in reads:
    if re.match(r"(?i)none\b", r[0]):
        continue
    opt = r[2] if len(r) > 2 else ""
    check(f"cross-context read by '{r[0]}': option is API composition, event replication or Change Data Capture",
          bool(re.search(r"(?i)api composition|event replication|change data capture", opt)))
    if re.search(r"(?i)shared (database|table|schema)", opt):
        check(f"cross-context read by '{r[0]}' is not a shared database", False)

# CDC ambiguity anywhere
for line in body.splitlines():
    if re.search(r"\bCDC\b", line) and re.search(r"(?i)contract|consumer-driven", line):
        check(f"'CDC' used next to a contract (spell out Consumer-Driven Contract): '{line.strip()[:60]}'", False)
        break

check("Open Questions section present", "open questions" in sections)

print(f"INFO: profile '{profile or '?'}', {len(inv)} integration(s), {len(sync_rows)} sync, {len(sd_heads)} sync detail block(s)")
sys.exit(1 if fails else 0)
PYEOF
