#!/bin/bash
# Tests skills/api-contract-design/scripts/validate-openapi-spec.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here, never from the skill's examples, so the test does
# not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/api-contract-design/scripts/validate-openapi-spec.sh"
cd "$SCRATCH_DIR"

if ! python3 -c "import yaml" 2>/dev/null; then
  _pass "validate-openapi-spec: skipped (PyYAML not installed; the script degrades to a WARN)"
  smoke_test_summary
  exit 0
fi

expect() { # expect <label> <exit> <substring> <file>
  local label="$1" want="$2" sub="$3" file="$4"
  local out code
  out="$("$VALIDATE" "$file" 2>&1)"; code=$?
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || echo "$out" | grep -qF -- "$sub"; }; then
    _pass "validate-openapi-spec: $label"
  else
    _fail "validate-openapi-spec: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

mutate() { # mutate <name> <old> <new>: copy good.yaml with one replacement
  python3 - "$1" "$2" "$3" <<'PY'
import sys
name, old, new = sys.argv[1:4]
t = open("good.yaml").read()
assert old in t, "fixture missing: " + old
open(name, "w").write(t.replace(old, new, 1))
PY
}

cat > good.yaml <<'EOF'
openapi: 3.1.0
info:
  title: Orders API
  version: 1.0.0
security:
  - BearerAuth: []
paths:
  /healthz:
    get:
      operationId: getHealth
      security: []
      responses:
        "200": { description: ok }
  /v1/orders:
    get:
      operationId: listOrders
      parameters:
        - name: cursor
          in: query
          schema: { type: string }
        - name: limit
          in: query
          schema: { type: integer, maximum: 100, default: 25 }
      responses:
        "200": { description: A page of orders }
        "401":
          description: unauthenticated
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorResponse" }
    post:
      operationId: createOrder
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "201": { description: created }
        "400":
          description: bad request
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorResponse" }
  /v1/orders/{id}:
    get:
      operationId: getOrder
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string }
      responses:
        "200": { description: one order }
        "404":
          description: not found
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorResponse" }
  /v1/orders/{id}:cancel:
    post:
      operationId: cancelOrder
      responses:
        "200": { description: cancelled }
  /v1/orders:export:
    post:
      operationId: exportOrders
      responses:
        "202":
          description: accepted
          content:
            application/json:
              schema:
                type: object
                properties:
                  operation: { type: string, description: "/v1/operations/{id}, an Operation" }
  /v1/operations/{id}:
    get:
      operationId: getOperation
      responses:
        "200": { description: an Operation }
components:
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      schema: { type: string }
  securitySchemes:
    BearerAuth: { type: http, scheme: bearer }
  schemas:
    Operation:
      type: object
      required: [name, done]
      properties:
        name: { type: string }
        done: { type: boolean }
    ErrorResponse:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string }
            message: { type: string }
EOF

expect "a complete spec passes" 0 "0 check(s) failed" good.yaml
expect "missing file is a usage error" 2 "" nosuch.yaml
out="$("$VALIDATE" 2>&1)"; code=$?
if [ "$code" -eq 2 ] && echo "$out" | grep -qF "Usage"; then
  _pass "validate-openapi-spec: no arguments is a usage error"
else
  _fail "validate-openapi-spec: no arguments is a usage error" "exit $code"
fi

printf 'a: [unclosed\n' > bad.yaml
expect "invalid YAML fails" 1 "not valid YAML" bad.yaml

mutate v30.yaml "openapi: 3.1.0" "openapi: 3.0.3"
expect "OpenAPI 3.0 fails" 1 "openapi version is 3.1.x" v30.yaml

mutate unversioned.yaml "/v1/orders/{id}:" "/orders/{id}:"
expect "an unversioned path fails" 1 "starts with a major version" unversioned.yaml

mutate verb.yaml "/v1/orders:export:" "/v1/getOrders:"
expect "a verb endpoint fails" 1 "is a noun, not a verb endpoint" verb.yaml

mutate camel.yaml "/v1/orders/{id}:" "/v1/orderItems/{id}:"
expect "a camelCase segment fails" 1 "lowercase kebab-case" camel.yaml

mutate nosec.yaml "security:
  - BearerAuth: []
paths:" "paths:"
expect "no global security fails" 1 "a global security requirement is declared" nosec.yaml

mutate lifted.yaml "      operationId: listOrders" "      operationId: listOrders
      security: []"
expect "security lifted on a non-health endpoint fails" 1 "security is lifted only for a health endpoint" lifted.yaml

mutate dup.yaml "operationId: getOrder" "operationId: listOrders"
expect "a duplicate operationId fails" 1 "is unique" dup.yaml

mutate noerr.yaml "schema: { \$ref: \"#/components/schemas/ErrorResponse\" }
  /v1/orders/{id}:" "schema: { type: object }
  /v1/orders/{id}:"
expect "an error response off the envelope fails" 1 "error uses the ErrorResponse schema" noerr.yaml

mutate flag.yaml '"200": { description: A page of orders }' '"200":
          description: A page of orders
          content:
            application/json:
              schema:
                type: object
                properties:
                  success: { type: boolean }'
expect "a success flag in a body fails" 1 "no success flag" flag.yaml

mutate no202.yaml "operation: { type: string, description: \"/v1/operations/{id}, an Operation\" }" "other: { type: string }"
expect "a 202 without an Operation fails" 1 "a 202 points to an Operation" no202.yaml

mutate noopschema.yaml "    Operation:
      type: object
      required: [name, done]
      properties:
        name: { type: string }
        done: { type: boolean }
" ""
expect "a 202 without an Operation schema fails" 1 "components define an Operation schema" noopschema.yaml

mutate offset.yaml "        - name: cursor" "        - name: page"
expect "page instead of cursor fails" 1 "uses cursor and limit" offset.yaml

mutate uncapped.yaml "{ type: integer, maximum: 100, default: 25 }" "{ type: integer, default: 25 }"
expect "an uncapped limit fails" 1 "limit is capped" uncapped.yaml

mutate keyget.yaml "      operationId: getOrder
      parameters:" "      operationId: getOrder
      parameters:
        - \$ref: \"#/components/parameters/IdempotencyKey\""
expect "an Idempotency-Key on a GET fails" 1 "no Idempotency-Key" keyget.yaml

mutate noerrschema.yaml "required: [code, message]" "required: [code]"
expect "an envelope without message fails" 1 "requires code and message" noerrschema.yaml

mutate tenant.yaml "security:
  - BearerAuth: []
paths:" "servers:
  - url: https://api.example.com/{tenantId}
security:
  - BearerAuth: []
paths:"
mutate refresp.yaml '        "401":
          description: unauthenticated
          content:
            application/json:
              schema: { $ref: "#/components/schemas/ErrorResponse" }' '        "401": { $ref: "#/components/responses/Error" }'
python3 - <<'PY'
t = open("refresp.yaml").read()
t = t.replace("components:\n", "components:\n  responses:\n    Error:\n      description: error\n      content:\n        application/json:\n          schema: { $ref: \"#/components/schemas/ErrorResponse\" }\n", 1)
open("refresp.yaml", "w").write(t)
PY
expect "a reusable error response that points to ErrorResponse passes" 0 "0 check(s) failed" refresp.yaml

expect "a tenant path variable warns but passes" 0 "WARN: a tenant path variable" tenant.yaml

smoke_test_summary
