#!/bin/bash
# Tests skills/api-gateway-design/scripts/validate-api-gateway-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/api-gateway-design/scripts/validate-api-gateway-design.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-api-gateway-design: $label"
  else
    _fail "validate-api-gateway-design: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

mutate() { # mutate <name> <old> <new>: copy good.md with one replacement
  python3 - "$1" "$2" "$3" <<'PY'
import sys
name, old, new = sys.argv[1:4]
t = open("good.md").read()
assert old in t, "fixture missing: " + old
open(name, "w").write(t.replace(old, new, 1))
PY
}

cat > good.md <<'EOF'
---
name: api-gateway-design
product: bookwise
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-11-20
summary: One gateway validates tokens, limits per key and routes to three services.
traces-to: [design/architecture/container-diagram.md]
---

# API Gateway Design for Bookwise

- **Profile:** standard
- **Gateway:** yes: Kong (proposal pending an ADR)

## Gateway Decision

The container diagram places one gateway as the north-south entry for three services.

## Routes

| Route | Upstream | Owner | Auth |
|---|---|---|---|
| /v1/orders | orders service | orders team | required |
| /v1/catalog | catalog service | catalog team | none: public |

## Authentication

- **Validates:** token signature, expiry and issuer
- **Authorization stays in the services:** every service verifies identity itself and decides what the caller may do; a header the gateway adds is never trusted alone

## Rate Limits

| Route or caller | Algorithm and why | Key | Limit and burst | Layer | Shared store and atomic operation | On store failure |
|---|---|---|---|---|---|---|
| /v1/orders | sliding window counter: close to a log's accuracy at a window's memory cost | API key | 600 per minute, burst 50 | both | Redis, one atomic increment with expiry | fail open with an alert |

Rejected requests return 429 with a Retry-After hint.

## Transforms

- Add a request id and strip internal headers; no business rules or aggregation here.

## Telemetry

- Request logs, latency and 5xx rates go to the existing stack.

## Configuration and Rollout

- **Source of truth:** declarative files in version control; a diff against the running gateway is reviewed before a change ships
- **State:** stateless gateway
- **Replicas and rollback:** three instances; rollback to the previous reviewed files; never a live edit

## Open Questions

- Whether partners need a higher limit; owner: product owner.
EOF

cat > nogateway.md <<'EOF'
---
name: api-gateway-design
product: hivebook
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-11-20
summary: No gateway; the ingress routes to the single application.
traces-to: [design/architecture/container-diagram.md]
---

# API Gateway Design for Hivebook

- **Profile:** lean
- **Gateway:** no

## Gateway Decision

One application: the ingress routes to it and it validates tokens itself. A gateway is added when several deployables share a public API.

## Open Questions

- None for now.
EOF
sed_in_place 's/^- None for now\./- None: nothing is open./' nogateway.md

expect "a complete design passes" 0 "0 check(s) failed" good.md
expect "a no-gateway design passes" 0 "0 check(s) failed" nogateway.md
expect "missing file is a usage error" 2 "" nosuch.md
out="$("$VALIDATE" 2>&1)"; code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -qF "Usage"; then
  _pass "validate-api-gateway-design: no arguments is a usage error"
else
  _fail "validate-api-gateway-design: no arguments is a usage error" "exit $code"
fi

mutate badname.md "name: api-gateway-design" "name: other"
expect "wrong frontmatter name fails" 1 "frontmatter name is api-gateway-design" badname.md

mutate badgw.md "**Gateway:** yes: Kong (proposal pending an ADR)" "**Gateway:** maybe"
expect "gateway must be yes or no" 1 "'Gateway' is yes or no" badgw.md

mutate noupstream.md "| /v1/orders | orders service | orders team | required |" "| /v1/orders |  | orders team | required |"
expect "a route without an upstream fails" 1 "upstream is filled" noupstream.md

mutate skip.md "every service verifies identity itself and decides what the caller may do; a header the gateway adds is never trusted alone" "services can skip the token check because the gateway validated it"
expect "services skipping token checks fails" 1 "every service verifies identity itself" skip.md

mutate trusthdr.md "a header the gateway adds is never trusted alone" "services trust the user-id header the gateway adds"
expect "trusting a gateway header fails" 1 "never skip checks or trust a header alone" trusthdr.md

mutate noalgo.md "sliding window counter: close to a log's accuracy at a window's memory cost" "a rate limiter, 600 per minute"
expect "an unnamed algorithm fails" 1 "a known algorithm is named" noalgo.md

mutate nostore.md "Redis, one atomic increment with expiry" "?"
expect "a missing shared store fails" 1 "shared store and atomic operation are stated" nostore.md

mutate nofail.md "fail open with an alert" "n/a"
expect "a missing store failure mode fails" 1 "fail open or fail closed" nofail.md

mutate nolayer.md "| 600 per minute, burst 50 | both |" "| 600 per minute, burst 50 | somewhere |"
expect "an unclear layer fails" 1 "layer is edge, service or both" nolayer.md

mutate no429.md "Rejected requests return 429 with a Retry-After hint." "Rejected requests are dropped."
expect "no 429 with a retry hint fails" 1 "429 with a retry hint" no429.md

mutate bizrule.md "- Add a request id and strip internal headers; no business rules or aggregation here." "- Apply the loyalty discount and compose the dashboard payload."
expect "business logic in transforms fails" 1 "no business rule or aggregation" bizrule.md

mutate nogit.md "declarative files in version control; a diff against the running gateway is reviewed before a change ships" "edited in the admin UI"
expect "configuration outside version control fails" 1 "source of truth is version control" nogit.md

mutate norollback.md "three instances; rollback to the previous reviewed files; never a live edit" "three instances"
expect "no rollback fails" 1 "replicas and rollback are stated" norollback.md

mutate nobullet.md "- Whether partners need a higher limit; owner: product owner." "nothing"
expect "no open question bullet fails" 1 "open questions has at least one bullet" nobullet.md

python3 - <<'PY'
t = open("nogateway.md").read()
open("nogateway-routes.md", "w").write(t.replace("## Open Questions", """## Routes

| Route | Upstream | Owner | Auth |
|---|---|---|---|
| /v1/x | svc | team | required |

## Open Questions"""))
open("nogateway-noingress.md", "w").write(t.replace("ingress", "router"))
PY
expect "no gateway but route rows fails" 1 "no route rows" nogateway-routes.md
expect "no gateway without naming the ingress fails" 1 "names the ingress" nogateway-noingress.md

mutate tenant.md "| API key | 600 per minute" "| tenant | 600 per minute"
expect "a tenant key warns but passes" 0 "WARN: limit" tenant.md

mutate code.md "## Telemetry" '```
code
```

## Telemetry'
expect "a code block warns" 0 "WARN: a code block" code.md

smoke_test_summary
