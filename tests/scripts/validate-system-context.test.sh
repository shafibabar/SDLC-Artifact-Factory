#!/bin/bash
# Tests skills/system-context-diagram/scripts/validate-system-context.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/system-context-diagram/scripts/validate-system-context.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <file> <exit> [substring that must appear]
  local out code
  out="$("$VALIDATE" "$2" 2>&1)"; code=$?
  if [ "$code" -eq "$3" ] && { [ -z "${4:-}" ] || echo "$out" | grep -qF -- "$4"; }; then
    _pass "validate-system-context: $1"
  else
    _fail "validate-system-context: $1" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

cat > good.md <<'EOF'
---
name: system-context-diagram
product: ferrylog
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-03-02
summary: Ferrylog as one system for deckhands, sending crossings to the port authority.
traces-to: [ideate/user-personas.md, design/event-storming/big-picture.md]
---

# System Context diagram for Ferrylog

**Readers:** the product owner and the port authority
**Question it answers:** what Ferrylog is, who uses it, and which other systems it works with.

## Diagram

```
+--------------------+
| [Person]           |
| Deckhand           |
+---------+----------+
          | Logs vehicles on each crossing in
          v
+--------------------+          +----------------------+
| [Software System]  |  Sends   | [External System]    |
| Ferrylog           |--------->| Port Authority Feed  |
+--------------------+ crossings+----------------------+
```

## Key

- `[Person]` a role; `[Software System]` the system; `[External System]` someone else's
- Arrows point from the party that starts the exchange; the label says what flows.

## Element Catalog

### System

**Ferrylog:** Logs each crossing's vehicles and passengers for one ferry operator.

### Persons

| Person | Role | How they use the system | Source |
|---|---|---|---|
| Deckhand | Loads the car deck | Logs vehicles on each crossing | persona |

### External Systems

| System | Owner | Kind | Provides or receives | Source |
|---|---|---|---|---|
| Port Authority Feed | The port authority | regulator | Receives crossing manifests | NFR |

### Relationships

| From | To | What flows | Protocol |
|---|---|---|---|
| Deckhand | Ferrylog | Logs vehicles on each crossing in | HTTPS |
| Ferrylog | Port Authority Feed | Sends crossing manifests to | HTTPS |

## Rationale

The app and its database are containers of Ferrylog.

## Boundary Notes

- **Constraints:** the port authority sets the manifest format.
- **Out of scope:** ticket sales (the booking site).

## Open Questions

- none
EOF
expect "a complete artifact passes" good.md 0 "INFO: system 'Ferrylog', 1 person(s), 1 external system(s), 2 relationship(s)"

sed 's/^# System Context diagram for Ferrylog$/# Ferrylog/' good.md > title.md
expect "a title without type and scope fails" title.md 1 "title states type and scope"

sed '/^\*\*Readers:/d' good.md > readers.md
expect "no readers named fails" readers.md 1 "names its readers"

sed '/^- Arrows point/d' good.md > key.md
expect "a key that doesn't say what an arrow means fails" key.md 1 "Key says what an arrow means"

sed 's/^| Deckhand | Loads/| User | Loads/; s/^| Deckhand | Ferrylog/| User | Ferrylog/' good.md > user.md
expect "a generic 'User' person fails" user.md 1 "is a role, not a generic 'User'"

sed 's/^| Port Authority Feed | The port authority/| Redpanda broker | The port authority/' good.md > broker.md
expect "a broker as an external system fails" broker.md 1 "is a software system, not a container"

sed 's/| Sends crossing manifests to |/| uses |/' good.md > uses.md
expect "a relationship labelled 'uses' fails" uses.md 1 "says what flows"

sed 's/^| Ferrylog | Port Authority Feed | Sends crossing manifests to |/| Deckhand | Port Authority Feed | Sends crossing manifests to |/' good.md > notouch.md
expect "a relationship that doesn't touch the system fails" notouch.md 1 "touches the system"

sed '/^| Ferrylog | Port Authority Feed/d' good.md > orphan.md
expect "an element with no relationship fails" orphan.md 1 "'Port Authority Feed' has at least one relationship"

sed 's/| Port Authority Feed  |/| Port Authority       |/' good.md > notondiag.md
expect "a catalog element missing from the diagram fails" notondiag.md 1 "appears on the diagram"

sed 's/|--------->|/|<-------->|/' good.md > twohead.md
expect "a two-headed arrow on the diagram fails" twohead.md 1 "no two-headed arrow"

sed 's/^| \[Person\]           |$/| [Person]           |\n| PostgreSQL         |/' good.md > tech.md
expect "technology on the diagram fails" tech.md 1 "no containers, technology or infrastructure on the diagram"

sed 's/^- \*\*Out of scope:\*\*.*$/- **Out of scope:** [none yet]/' good.md > scope.md
expect "boundary notes without what is out of scope fail" scope.md 1 "state what is out of scope"

sed '/^The app and its database/d' good.md > norat.md
expect "an empty rationale fails" norat.md 1 "Rationale filled"

{ cat good.md; printf '\n## Mermaid (copy of the ASCII)\n\n```mermaid\nflowchart TB\n  a --> b\n```\n'; } > flow.md
expect "a Mermaid flowchart copy fails (C4Context)" flow.md 1 "uses C4Context"

{ cat good.md; printf '\n## Mermaid (copy of the ASCII)\n\n```mermaid\nC4Context\n  title System Context diagram for Ferrylog\n```\n'; } > c4.md
expect "a Mermaid C4Context copy passes" c4.md 0

sed '/^traces-to:/d' good.md > notrace.md
expect "missing traces-to fails" notrace.md 1 "FAIL: frontmatter has"

sed 's/^owner: enterprise-architect$/owner: domain-modeler/' good.md > owner.md
expect "an owner other than enterprise-architect fails" owner.md 1 "owner is enterprise-architect"

sed '/^| Port Authority Feed | The port authority/d; /^| Ferrylog | Port Authority Feed/d; s/| Port Authority Feed  |/|                      |/' good.md > noext.md
expect "no external systems warns but passes" noext.md 0 "WARN: no external systems"

out="$("$VALIDATE" 2>&1)"; code=$?
[ "$code" -eq 2 ] && _pass "validate-system-context: no argument exits 2" || _fail "validate-system-context: no argument exits 2" "exit $code"
"$VALIDATE" /no/such/file.md >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && _pass "validate-system-context: a missing file exits 2" || _fail "validate-system-context: a missing file exits 2" "exit $code"

smoke_test_summary
