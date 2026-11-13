#!/bin/bash
# scripts/validate-multi-tenancy-design.sh — skill-owned script for skills/multi-tenancy-design.
# Purpose: mechanically check a Multi-Tenancy Design artifact
#          (artifacts/<product>/design/architecture/multi-tenancy-design.md) against
#          the structural items of resources/checklist.md: frontmatter with a
#          tenancy-model of pool | bridge | silo | mixed; title, readers, question;
#          inputs with the profile; a per-resource Model table where every row
#          names a model, its forces and an isolation mechanism, covering compute
#          and at least one data store; mixed only with more than one model in
#          the table; a Compliance Basis whose every push names its source and
#          that never claims SOC 2 (or GDPR, HIPAA, PCI DSS) requires physical or
#          per-tenant isolation; isolation enforcement for tenant context (from
#          the token), database, broker; a cross-tenant test; lifecycle with
#          onboarding, tier change and offboarding (offboarding mentions backups
#          or per-tenant keys when anything is pooled); metering and cost per
#          tenant; open questions. Whether the model is right stays with the agent.
# Usage:   validate-multi-tenancy-design.sh <multi-tenancy-design.md>
# Output:  one PASS/FAIL/WARN line per check, then counts.
# Contract: plain CLI args, advisory only. Exit 0 if every check passes (WARN
#           lines don't fail), 1 if any check fails, 2 on a usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-multi-tenancy-design.sh <multi-tenancy-design.md>" >&2
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

# Frontmatter
fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
meta = {}
for line in (fm.group(1).splitlines() if fm else []):
    m = re.match(r"^([\w-]+):\s*(.*)$", line)
    if m:
        meta[m.group(1)] = m.group(2).strip()
required = ["name", "product", "version", "phase", "owner", "created", "summary", "tenancy-model", "traces-to"]
missing = [f for f in required if not (re.search(r"\.md|/", meta.get(f, "")) if f == "traces-to" else filled(meta.get(f, "")))]
check("frontmatter has " + ", ".join(required) + (" (missing: " + ", ".join(missing) + ")" if missing else ""), not missing)
check("name is multi-tenancy-design", meta.get("name") == "multi-tenancy-design")
check("owner is enterprise-architect", meta.get("owner") == "enterprise-architect")
model = meta.get("tenancy-model", "").strip().lower()
check("tenancy-model is pool, bridge, silo or mixed (no 'physical' / 'stamp' default names)", model in ("pool", "bridge", "silo", "mixed"))

body = re.sub(r"<!--.*?-->", "", text[fm.end():] if fm else text, flags=re.S)
low = body.lower()
title = re.search(r"^# (.+)$", body, re.M)
check("title states type and scope ('# Multi-Tenancy Design for <Product>')",
      bool(title) and bool(re.match(r"(?i)multi-tenancy design for \S", title.group(1).strip())))
check("names its readers", bool(re.search(r"(?im)^\*\*readers:?\*\*:?\s*[^\s\[]", body)))
check("states the question it answers", bool(re.search(r"(?im)^\*\*question it answers:?\*\*:?\s*\S", body)))

sections, cur = {}, None
for line in body.splitlines():
    h = re.match(r"^(#{2,3}) (.+)$", line)
    if h:
        cur = h.group(2).strip().lower(); sections[cur] = []
    elif cur is not None:
        sections[cur].append(line)

def sec(name):
    return "\n".join(sections.get(name, []))

def table(lines):
    rows = [[c.strip() for c in l.strip().strip("|").split("|")] for l in lines if l.strip().startswith("|")]
    rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
    return (rows[0], [r for r in rows[1:] if r and filled(r[0])]) if rows else ([], [])

def bullets(name):
    out = {}
    for l in sections.get(name, []):
        m = re.match(r"^\s*-\s*\*\*(.+?):?\*\*:?\s*(.*)$", l)
        if m:
            out[m.group(1).strip(": ").lower()] = m.group(2).strip()
    return out

# Inputs
inp = bullets("inputs")
check("Inputs state the profile (lean, standard or enterprise)", inp.get("profile", "").lower().strip() in ("lean", "standard", "enterprise"))
check("Inputs state the tenants (count)", filled(inp.get("tenants", "")))

# Model table
_, rows = table(sections.get("model", []))
check("Model has a per-resource table", bool(rows))
models_used = set()
for r in rows:
    g = lambda i: r[i] if i < len(r) else ""
    res, mdl, forces, mech = g(0), g(1).lower(), g(2), g(3)
    m = re.search(r"\b(pool|bridge|silo)\b", mdl)
    check(f"resource '{res}': model is pool, bridge or silo", bool(m))
    if m:
        models_used.add(m.group(1))
    check(f"resource '{res}': names the forces that decided it", filled(forces))
    check(f"resource '{res}': names its isolation mechanism", filled(mech))
    if m and m.group(1) == "silo" and re.search(r"(?i)default|standard model|house", forces):
        check(f"resource '{res}': a silo is not justified as a default", False)
resnames = " ".join(r[0].lower() for r in rows)
check("Model table covers compute", bool(re.search(r"comput|app|service|api|worker", resnames)))
check("Model table covers at least one data store", bool(re.search(r"database|postgres|db\b|store|storage|bucket|index|search|cache", resnames)))
if model == "mixed":
    check("tenancy-model 'mixed' has more than one model in the table", len(models_used) > 1)
elif model in ("pool", "bridge", "silo") and models_used and models_used != {model}:
    warn(f"tenancy-model '{model}' but the table uses {sorted(models_used)}; 'mixed' may fit better")

# Compliance basis
cb = sec("compliance basis")
_, crow = table(sections.get("compliance basis", []))
check("Compliance Basis section present with at least one row", bool(crow))
SRC = re.compile(r"(?i)\b(law|contract|tier|risk|framework)\b\s*:")
for r in crow:
    src = r[1] if len(r) > 1 else ""
    check(f"compliance push '{r[0]}': names its source (law: / contract: / tier: / risk: / framework:)", bool(SRC.search(src)))
FALSE_CLAIM = re.compile(r"(?i)\b(soc ?2|gdpr|hipaa|pci(?: dss)?)\b[^.\n|]{0,40}\b(requires?|mandates?|demands?)\b[^.\n|]{0,60}\b(physical|separate|dedicated|stamp|silo|own (database|server|instance)|per[- ]tenant (database|instance))")
NEG = re.compile(r"(?i)\b(not|no|never|doesn.t|does not|nor)\b")
bad = [m.group(0) for m in FALSE_CLAIM.finditer(body) if not NEG.search(body[max(0, m.start()-40):m.end()])]
check("never claims a framework requires physical or per-tenant isolation" + (f" (found: '{bad[0]}')" if bad else ""), not bad)
check("no 'compliance requires' without a named source", not re.search(r"(?i)compliance requires", body))

# Tiers and noisy neighbour
check("Tiers and Noisy Neighbour section names a noisy-neighbour control",
      bool(re.search(r"(?i)rate limit|quota|throttl|separate queue|worker pool", sec("tiers and noisy neighbour"))))

# Isolation enforcement
_, irows = table(sections.get("isolation enforcement", []))
layers = {r[0].lower(): (r[1] if len(r) > 1 else "") for r in irows}
def layer(key):
    return next((v for k, v in layers.items() if key in k), "")
tc = layer("tenant context")
check("Isolation: tenant context comes from the token", bool(re.search(r"(?i)token|jwt|claim", tc)))
check("Isolation: tenant context is never client-supplied", bool(re.search(r"(?i)never|not from|ignored|rejected", tc)))
dbl = layer("database")
check("Isolation: database layer filled", filled(dbl))
if "pool" in models_used and re.search(r"(?i)row[- ]level|rls", dbl):
    check("Isolation: pooled row-level security is forced or uses a non-owner role",
          bool(re.search(r"(?i)force|non-owner|not the owner|non owner", dbl)))
if "pool" in models_used and dbl and not re.search(r"(?i)row[- ]level|rls|schema|own database", dbl):
    warn("pooled database without row-level security named: say what enforces isolation")
check("Isolation: broker layer filled", filled(layer("broker")))
check("names a cross-tenant test (release gate)", bool(re.search(r"(?i)cross-tenant test", body)))

# Control plane
cp = sec("control plane")
check("Control Plane says it never reads tenant data", bool(re.search(r"(?i)never reads? tenant data|does not read tenant data|no access to tenant data", cp)))

# Lifecycle
lc = bullets("lifecycle")
for k in ("onboarding", "tier change", "offboarding"):
    check(f"Lifecycle: {k} filled", filled(lc.get(k, "")) or (k == "tier change" and "none" in lc.get(k, "").lower()))
if "pool" in models_used or "bridge" in models_used:
    check("Lifecycle: pooled offboarding reaches backups or uses per-tenant keys",
          bool(re.search(r"(?i)backup|per-tenant key|crypto-?shred|destroy(ing)? (the|its) key", lc.get("offboarding", ""))))

# Metering
mt = bullets("metering and cost per tenant")
check("Metering stated", filled(mt.get("metering", "")))
check("Cost per tenant stated", filled(mt.get("cost per tenant", "")))
if "pool" in models_used:
    check("Cost per tenant in a pool comes from per-tenant consumption, not tags alone",
          bool(re.search(r"(?i)consum|usage|apportion|metered", mt.get("cost per tenant", ""))))

check("Open Questions section present", "open questions" in sections)

print(f"INFO: tenancy-model '{model or '?'}', {len(rows)} resource row(s), models used {sorted(models_used) or '-'}")
sys.exit(1 if fails else 0)
PYEOF
