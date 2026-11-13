#!/bin/bash
# Tests skills/container-diagram/scripts/validate-container-diagram.sh — a
# skill-owned script exercised directly with file-path CLI args.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/container-diagram/scripts/validate-container-diagram.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> [substring] -- <args...>
  local label="$1" want="$2" sub="$3"; shift 3
  local out code
  out="$("$VALIDATE" "$@" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-container-diagram: $label"
  else
    _fail "validate-container-diagram: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > ctx.md <<'EOF'
### Persons

| Person | Role | How | Source |
|---|---|---|---|
| Deckhand | x | x | x |

### External Systems

| System | Owner | Kind | Provides | Source |
|---|---|---|---|---|
| Port Authority Feed | x | x | x | x |

## Rationale
EOF

cat > good.md <<'EOF'
---
name: container-diagram
product: ferrylog
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-03-02
summary: Ferrylog as one modular monolith and its database.
traces-to: [design/architecture/system-context.md, design/context-map.md]
---

# Container diagram for Ferrylog

**Readers:** the engineers and the product owner
**Question it answers:** what runs, in what technology, how it talks and where it runs.

## Decomposition

- **Profile:** lean

| Deployable | Containers | Contexts | Forces |
|---|---|---|---|
| ferrylog | Ferrylog App, Ferrylog DB | Crossings, Manifests | modular monolith (lean) |

## Diagram

```
[Person] Deckhand
   | Logs vehicles in [HTTPS]
   v
+-- Ferrylog --------------------------+
| [Container: Application] Ferrylog App |---> [Container: Database] Ferrylog DB
+--------------------------------------+
   | Sends manifests to [HTTPS]
   v
[External System] Port Authority Feed
```

## Key

- Arrows point from the caller; solid is sync, dashed is async.

## Element Catalog

### Containers

| Container | Type | Technology | Deployable | Responsibility |
|---|---|---|---|---|
| Ferrylog App | Application | Go, net/http + chi | ferrylog | Crossings and Manifests modules |
| Ferrylog DB | Database | PostgreSQL, pgx | ferrylog | One schema per module |

### Persons and External Systems

| Name | Kind | Uses or used by |
|---|---|---|
| Deckhand | Person | Ferrylog App |
| Port Authority Feed | External System | Ferrylog App |

### Communication Matrix

| From | To | What flows | Protocol | Sync/Async |
|---|---|---|---|---|
| Deckhand | Ferrylog App | Logs vehicles in | HTTPS | sync |
| Ferrylog App | Ferrylog DB | Reads and writes rows in | SQL | sync |
| Ferrylog App | Port Authority Feed | Sends manifests to | HTTPS | sync |

## Gateway

- **Gateway:** none: the ingress routes to Ferrylog App
- **Identity:** Ferrylog App verifies every session itself
- **Planes:** north-south: clients → ingress; east-west: none

## Rationale

One deployable: lean, no disintegrator.

## Fitness Functions

| Rule | Automated check |
|---|---|
| Modules don't import each other | Import test in CI |

## Deployment View

- **Tenancy:** single deployment, no tenancy

### Environment: production

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| Ferrylog App | cluster namespace ferrylog | 2 | |
| Ferrylog DB | managed PostgreSQL | 1 | |

- **Variability:** staging runs one instance.

## Open Questions

- none
EOF
expect "a complete artifact passes, with the context check" 0 "INFO: profile 'lean', 1 deployable(s), 2 container(s), 3 connector(s)" good.md ctx.md

sed 's/^# Container diagram for Ferrylog$/# Ferrylog containers/' good.md > title.md
expect "a title without type and scope fails" 1 "title states type and scope" title.md

sed '/^\*\*Readers:/d' good.md > readers.md
expect "no readers fails" 1 "names its readers" readers.md

sed 's/^- \*\*Profile:\*\* lean$/- **Profile:** small/' good.md > profile.md
expect "an unknown profile fails" 1 "states the profile" profile.md

{ sed 's/^| ferrylog | Ferrylog App, Ferrylog DB | Crossings, Manifests | modular monolith (lean) |$/| ferrylog | Ferrylog App, Ferrylog DB | Crossings | modular monolith (lean) |\n| manifests | Manifests App | Manifests | cleaner |/' good.md; } > split.md
expect "a split with no named force fails" 1 "names its forces" split.md

sed 's/| \[Container: Application\] Ferrylog App |/| [Container: Application] Ferrylog App x3 |/' good.md > replicas.md
expect "replicas on the container view fail" 1 "carries no deployment detail" replicas.md

sed 's/^| Ferrylog App | Application | Go, net\/http + chi |/| Ferrylog App | Application | |/' good.md > notech.md
expect "a container with no technology fails" 1 "has a technology label" notech.md

sed 's/^| Ferrylog DB | Database | PostgreSQL, pgx | ferrylog |/| Ferrylog DB | Database | PostgreSQL, pgx | other |/' good.md > nodep.md
expect "a container in no listed deployable fails" 1 "belongs to a deployable" nodep.md

{ cat good.md | sed 's/^| ferrylog | Ferrylog App, Ferrylog DB | Crossings, Manifests | modular monolith (lean) |$/| ferrylog | Ferrylog App, Ferrylog DB | Crossings | modular monolith (lean) |\n| manifests | Manifests API | Manifests | security: regulated manifests |/; s/^| Ferrylog DB | Database | PostgreSQL, pgx | ferrylog | One schema per module |$/| Ferrylog DB | Database | PostgreSQL, pgx | ferrylog | One schema per module |\n| Manifests API | API | Go, net\/http + chi | manifests | Manifests |/; s/^| Ferrylog App | Port Authority Feed | Sends manifests to | HTTPS | sync |$/| Ferrylog App | Port Authority Feed | Sends manifests to | HTTPS | sync |\n| Manifests API | Ferrylog DB | Reads crossing rows in | SQL | sync |/; s/^| Ferrylog DB | managed PostgreSQL | 1 | |$/| Ferrylog DB | managed PostgreSQL | 1 | |\n| Manifests API | namespace manifests | 1 | |/; s/\[Container: Database\] Ferrylog DB/[Container: Database] Ferrylog DB  Manifests API/' ; } > shared.md
expect "a database reached from another deployable fails" 1 "no shared database" shared.md

sed 's/| Sends manifests to | HTTPS | sync |/| uses | HTTPS | sync |/' good.md > vague.md
expect "a connector labelled 'uses' fails" 1 "says what flows" vague.md

sed 's/| Logs vehicles in | HTTPS | sync |/| Logs vehicles in | HTTPS | maybe |/' good.md > mode.md
expect "a connector without sync or async fails" 1 "says sync or async" mode.md

sed 's/^| Port Authority Feed | External System | Ferrylog App |$/| Harbour Feed | External System | Ferrylog App |/; s/Port Authority Feed$/Harbour Feed/; s/| Ferrylog App | Port Authority Feed |/| Ferrylog App | Harbour Feed |/' good.md > rename.md
expect "an external system renamed from the context fails" 1 "carries its name from the system context" rename.md ctx.md

sed '/^- \*\*Identity:/d' good.md > ident.md
expect "no identity line in the gateway section fails" 1 "services verify identity" ident.md

sed 's/^- \*\*Planes:.*$/- **Planes:** clients come in/' good.md > planes.md
expect "planes not marked fails" 1 "north-south and east-west" planes.md

sed '/^| Modules don.t import/d' good.md > noff.md
expect "no fitness function fails" 1 "at least one fitness function" noff.md

sed '/^| Ferrylog DB | managed PostgreSQL/d' good.md > unmapped.md
expect "a container missing from the deployment view fails" 1 "is mapped in the deployment view" unmapped.md

sed 's/^- \*\*Tenancy:\*\* single deployment, no tenancy$/- **Tenancy:** pending multi-tenancy-design/' good.md > pending.md
expect "pending tenancy without an open question fails" 1 "listed as an open question" pending.md

sed 's/^- \*\*Tenancy:\*\* single deployment, no tenancy$/- **Tenancy:** pending multi-tenancy-design/; s/^- none$/- tenancy model: multi-tenancy-design, blocking the deployment view/' good.md > pendingok.md
expect "pending tenancy listed as an open question passes" 0 "" pendingok.md

sed '/^### Environment: production$/,/^- \*\*Variability:/d' pendingok.md > pendingnoenv.md
expect "pending tenancy still needs the environment drawn" 1 "has at least one environment" pendingnoenv.md

sed 's/^| Ferrylog App | Application | Go, net\/http + chi |/| Ferrylog App | Application | chosen in an ADR |/' good.md > placeholder.md
expect "a placeholder technology label fails" 1 "not a placeholder" placeholder.md

sed 's/^| Ferrylog App | Application | Go, net\/http + chi |/| Ferrylog App | Application | Kong (proposed, ADR pending) |/' good.md > proposed.md
expect "a proposed technology without an open question fails" 1 "listed as an open question (ADR)" proposed.md

sed 's/^| Ferrylog App | Application | Go, net\/http + chi |/| Ferrylog App | Application | Kong (proposed, ADR pending) |/; s/^- none$/- Kong for the gateway: ADR pending/' good.md > proposedok.md
expect "a proposed technology listed as an open question passes" 0 "" proposedok.md

{ cat good.md; printf '\n## Mermaid copy\n\n```mermaid\nflowchart TB\n  a --> b\n```\n'; } > flow.md
expect "a Mermaid flowchart fails (C4Container)" 1 "uses C4Container or C4Deployment" flow.md

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" 1 "FAIL: frontmatter has" notrace.md

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-container-diagram: no argument exits 2" || _fail "validate-container-diagram: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-container-diagram: a missing file exits 2" || _fail "validate-container-diagram: a missing file exits 2" "exit $code"

smoke_test_summary
