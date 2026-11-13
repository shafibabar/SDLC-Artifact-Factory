#!/bin/bash
# Tests skills/multi-tenancy-design/scripts/validate-multi-tenancy-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/multi-tenancy-design/scripts/validate-multi-tenancy-design.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> [substring] -- <args...>
  local label="$1" want="$2" sub="$3"; shift 3
  local out code
  out="$("$VALIDATE" "$@" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-multi-tenancy-design: $label"
  else
    _fail "validate-multi-tenancy-design: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: multi-tenancy-design
product: kennelbook
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-01-10
summary: Kennelbook pools every resource across its dog-boarding tenants with forced row-level security.
tenancy-model: pool
traces-to: [ideate/nfr-specification.md]
---

# Multi-Tenancy Design for Kennelbook

**Readers:** enterprise-architect, security-architect
**Question it answers:** what is shared, what keeps tenants apart, how they join and leave.

## Inputs

- **Profile:** lean
- **Tenants:** 300 kennels
- **Data classification:** internal
- **Residency and obligations:** none
- **Tiers:** none

## Model

- **Overall:** pool

| Resource | Model | Forces | Isolation mechanism |
|---|---|---|---|
| App compute | pool | cost, operations | tenant context from the token |
| PostgreSQL | pool | cost | forced RLS, non-owner role, SET LOCAL |

## Compliance Basis

| Push | Source | Effect |
|---|---|---|
| SOC 2 report | framework: attests access controls only | none |

## Tiers and Noisy Neighbour

| Tier | Promises | Resources | Noisy-neighbour controls |
|---|---|---|---|
| all tenants | one plan | pooled | per-tenant rate limit |

- **Partition key and hot tenant:** tenant_id leads every key; the largest kennel is capped per tenant

## Isolation Enforcement

| Layer | Mechanism |
|---|---|
| Tenant context | from the verified token claim; never client-supplied |
| Database | RLS forced, non-owner role, SET LOCAL per transaction |
| Broker | none (in-process) |

- **Cross-tenant test (release gate):** tenant A's token against tenant B's ids expects 404.

## Control Plane

- **Holds:** tenant table
- **Never reads tenant data:** no grants on tenant tables

## Lifecycle

- **Onboarding:** tenant row and first user
- **Tier change:** none (one plan)
- **Offboarding:** export, delete by tenant key, backups expire after 30 days

## Metering and Cost per Tenant

- **Metering:** bookings per month
- **Cost per tenant:** apportioned from per-tenant usage

## Open Questions

- none
EOF

expect "a complete pooled design passes" 0 "" good.md

sed 's/^tenancy-model: pool$/tenancy-model: physical/' good.md > physical.md
expect "a 'physical' tenancy-model fails" 1 "tenancy-model is pool, bridge, silo or mixed" physical.md

sed 's/^| PostgreSQL | pool | cost |/| PostgreSQL | pool | |/' good.md > noforce.md
expect "a resource without forces fails" 1 "names the forces" noforce.md

sed 's/^| PostgreSQL | pool | cost | forced RLS, non-owner role, SET LOCAL |$/| PostgreSQL | pool | cost | |/' good.md > nomech.md
expect "a resource without a mechanism fails" 1 "names its isolation mechanism" nomech.md

sed 's/^| SOC 2 report | framework: attests access controls only | none |$/| SOC 2 report | auditors | none |/' good.md > nosrc.md
expect "a compliance push without a source fails" 1 "names its source" nosrc.md

sed 's/^- \*\*Cross-tenant test (release gate):\*\*.*$/- Isolation is tested./' good.md > notest.md
expect "no cross-tenant test fails" 1 "cross-tenant test" notest.md

{ cat good.md; printf '\nNote: SOC 2 requires a separate database per tenant.\n'; } > soc2.md
expect "claiming SOC 2 requires a separate database fails" 1 "never claims a framework requires" soc2.md

{ cat good.md; printf '\nNote: SOC 2 does not require a separate database per tenant.\n'; } > soc2ok.md
expect "saying SOC 2 does not require a separate database passes" 0 "" soc2ok.md

sed 's/^| Tenant context | from the verified token claim; never client-supplied |$/| Tenant context | from the X-Tenant header |/' good.md > header.md
expect "tenant context not from the token fails" 1 "tenant context comes from the token" header.md

sed 's/^| Database | RLS forced, non-owner role, SET LOCAL per transaction |$/| Database | RLS on every table |/' good.md > rls.md
expect "pooled RLS that is not forced fails" 1 "forced or uses a non-owner role" rls.md

sed 's/^- \*\*Offboarding:\*\*.*$/- **Offboarding:** delete rows by tenant key/' good.md > nobackup.md
expect "pooled offboarding without backups or keys fails" 1 "reaches backups or uses per-tenant keys" nobackup.md

sed 's/^- \*\*Cost per tenant:\*\*.*$/- **Cost per tenant:** cloud bill tags/' good.md > tags.md
expect "pooled cost per tenant from tags alone fails" 1 "per-tenant consumption" tags.md

sed 's/^tenancy-model: pool$/tenancy-model: mixed/' good.md > mixed.md
expect "'mixed' with one model in the table fails" 1 "more than one model" mixed.md

sed 's/^- \*\*Never reads tenant data:\*\*.*$/- **Access:** admin console/' good.md > cp.md
expect "control plane without the never-reads rule fails" 1 "never reads tenant data" cp.md

sed '/^- \*\*Partition key and hot tenant:/d' good.md > nohot.md
expect "a pooled design without the hot-tenant line fails" 1 "hot tenant" nohot.md

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" 1 "FAIL: frontmatter has" notrace.md

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-multi-tenancy-design: no argument exits 2" || _fail "validate-multi-tenancy-design: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-multi-tenancy-design: a missing file exits 2" || _fail "validate-multi-tenancy-design: a missing file exits 2" "exit $code"

smoke_test_summary
