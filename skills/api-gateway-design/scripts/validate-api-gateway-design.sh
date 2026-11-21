#!/bin/bash
# scripts/validate-api-gateway-design.sh — skill-owned script for skills/api-gateway-design.
# Purpose: mechanically check an API Gateway Design
#          (artifacts/<product>/deploy/api-gateway-design.md) against the
#          structural items of resources/checklist.md: frontmatter; profile and
#          "Gateway" lines; a decision section; when there is no gateway, no
#          routes or limits; when there is one, routes with upstream, owner and
#          auth; an authentication section that keeps authorization in the
#          services and does not let services skip checks or trust a header;
#          rate limits that name a known algorithm, a key, a limit, a layer, a
#          shared store and the failure behaviour; transforms free of business
#          rules and aggregation; telemetry; configuration in version control on
#          a stateless gateway with a rollback; open questions. Whether each
#          choice is right stays with the agent.
# Usage:   validate-api-gateway-design.sh <file.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-api-gateway-design.sh <file.md>" >&2
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

def field(sec, label):
    m = re.search(r"\*\*%s:\*\*\s*(.+)" % re.escape(label), sec, re.I)
    return m.group(1).strip() if m else ""

# --- frontmatter ---------------------------------------------------------
fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
check("frontmatter block is present", bool(fm))
if fm:
    for key in ("name", "version", "phase", "owner", "created", "summary"):
        check("frontmatter has '%s'" % key, bool(re.search(r"^%s:\s*\S" % key, fm.group(1), re.M)))
    nm = re.search(r"^name:\s*(\S+)", fm.group(1), re.M)
    check("frontmatter name is api-gateway-design", bool(nm) and nm.group(1) == "api-gateway-design")
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
gm = re.search(r"\*\*Gateway:\*\*\s*(\S+)", head)
gw = (gm.group(1).strip().lower().rstrip(":,.") if gm else "")
check("'Gateway' is yes or no", gw in ("yes", "no"))

check("section 'gateway decision' is present and filled", filled(secs.get("gateway decision", "").strip().split("\n")[0] if secs.get("gateway decision", "").strip() else ""))

if gw == "no":
    check("no gateway: the decision names the ingress", "ingress" in secs.get("gateway decision", "").lower())
    check("no gateway: no route rows", len(table(secs.get("routes", ""))) == 0)
    check("no gateway: no rate-limit rows", len(table(secs.get("rate limits", ""))) == 0)

if gw == "yes":
    for need in ("routes", "authentication", "rate limits", "transforms", "telemetry", "configuration and rollout"):
        check("section '%s' is present" % need, need in secs)

    routes = table(secs.get("routes", ""))
    check("routes table has at least one row", len(routes) > 0)
    for r in routes:
        nm = r.get("route", "?")[:30]
        for col in ("upstream", "owner", "auth"):
            check("route '%s': %s is filled" % (nm, col), filled(r.get(col, "")))

    au = secs.get("authentication", "")
    check("authentication: what the gateway validates is stated", filled(field(au, "Validates")))
    az = field(au, "Authorization stays in the services")
    check("authentication: authorization stays in the services", filled(az))
    check("authentication: every service verifies identity itself",
          bool(re.search(r"every service|each service|all services", az, re.I)) and "verif" in az.lower())
    forbidden = bool(re.search(r"(services?|app)[^.\n]{0,15}(skip|do not need|don't need)[^.\n]{0,30}(token|check|verif)", au, re.I)
                     or re.search(r"\btrust(ed)? the[^.\n]{0,30}header", au, re.I))
    never = bool(re.search(r"never (trust|skip)|not (trust|skip)|never trusted", au, re.I))
    check("authentication: services never skip checks or trust a header alone", (not forbidden) or never)

    algos = ("token bucket", "leaky bucket", "fixed window", "sliding window log", "sliding window counter", "sliding window")
    limits = table(secs.get("rate limits", ""))
    check("rate limits table has at least one row", len(limits) > 0)
    for r in limits:
        nm = r.get("route or caller", "?")[:30]
        alg = r.get("algorithm and why", "").lower()
        check("limit '%s': a known algorithm is named" % nm, any(a in alg for a in algos))
        check("limit '%s': a reason is given" % nm, len(alg.split()) >= 4)
        check("limit '%s': the key is stated" % nm, filled(r.get("key", "")))
        check("limit '%s': the limit and burst are stated" % nm, filled(r.get("limit and burst", "")))
        layer = r.get("layer", "").lower()
        check("limit '%s': the layer is edge, service or both" % nm, any(l in layer for l in ("edge", "service", "both")))
        check("limit '%s': the shared store and atomic operation are stated" % nm,
              filled(r.get("shared store and atomic operation", "")))
        check("limit '%s': store failure is fail open or fail closed" % nm,
              bool(re.search(r"fail[- ]open|fail[- ]closed", r.get("on store failure", ""), re.I)))
        if "tenant" in r.get("key", "").lower():
            warn("limit '%s' keys on a tenant: keep that for a multi-tenant product" % nm)
    check("rejections return 429 with a retry hint", bool(re.search(r"429", secs.get("rate limits", ""))) and bool(re.search(r"retry", secs.get("rate limits", ""), re.I)))

    tr = secs.get("transforms", "")
    bad = re.search(r"(?<!no )(?<!never )(?<!not )\b(discount|pricing|loyalty|eligib\w*|workflow|aggregat\w*|stitch\w*|compos\w*)\b", tr, re.I)
    ok_neg = bool(re.search(r"(no|never|not|without)[^.\n]{0,40}(business|aggregat|discount|pricing|compos)", tr, re.I))
    check("transforms hold no business rule or aggregation", (not bad) or ok_neg)

    check("telemetry names logs or metrics", bool(re.search(r"log|metric|latency|trace", secs.get("telemetry", ""), re.I)))

    cf = secs.get("configuration and rollout", "")
    src = field(cf, "Source of truth")
    check("configuration: the source of truth is version control", bool(re.search(r"version control|git", src, re.I)))
    check("configuration: a reviewed diff is required", bool(re.search(r"diff|review", src, re.I)))
    check("configuration: the gateway is stateless", bool(re.search(r"stateless", field(cf, "State"), re.I)))
    rr = field(cf, "Replicas and rollback")
    check("configuration: replicas and rollback are stated", filled(rr) and "rollback" in rr.lower())
    check("configuration: no live edit in an admin interface",
          not re.search(r"admin (ui|interface|api)|live edit", cf, re.I) or bool(re.search(r"never|no live|not a live|without a live", cf, re.I)))

if re.search(r"^```", body, re.M):
    warn("a code block appears: the design names policy, not code")
if re.search(r"tenant", body, re.I):
    warn("tenant appears: confirm the product is multi-tenant before keeping it")
check("'CDC' is not used for Consumer-Driven Contract",
      not re.search(r"consumer[- ]driven[^.\n]{0,30}\bCDC\b|\bCDC (test|contract)", body, re.I))
oq = secs.get("open questions", "")
check("open questions has at least one bullet", bool(re.search(r"^\s*[-*] \S", oq, re.M)))

print("\n%d check(s) failed" % fails)
sys.exit(1 if fails else 0)
PYEOF
