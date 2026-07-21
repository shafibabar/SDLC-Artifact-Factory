#!/bin/bash
# Proves backend-engineer can actually invoke go-chi-handler and produce
# real, compiling Go code — not just answer a question about the skill's
# content (that's the .contract.sh tier).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

HANDLER_DIR_REL="internal/handlers/http"
ROUTER="$SCRATCH_DIR/$HANDLER_DIR_REL/router.go"
ERRORS="$SCRATCH_DIR/$HANDLER_DIR_REL/errors.go"

validate_go_chi_handler() {
  local scratch="$1"
  local dir="$scratch/$HANDLER_DIR_REL"

  [[ -f "$dir/router.go" ]] || { echo "missing $HANDLER_DIR_REL/router.go"; return 1; }
  [[ -f "$dir/errors.go" ]] || { echo "missing $HANDLER_DIR_REL/errors.go"; return 1; }

  local handler_files test_files
  handler_files=$(find "$dir" -maxdepth 1 -name '*.go' ! -name '*_test.go' ! -name 'router.go' ! -name 'errors.go')
  test_files=$(find "$dir" -maxdepth 1 -name '*_test.go')
  [[ -n "$handler_files" ]] || { echo "no handler file found in $HANDLER_DIR_REL besides router.go/errors.go"; return 1; }
  [[ -n "$test_files" ]] || { echo "no _test.go file found in $HANDLER_DIR_REL (TDD is non-negotiable per this repo's rules)"; return 1; }

  local all_go_files="$dir/router.go $dir/errors.go $handler_files"
  grep -q 'r\.Context()' $all_go_files || { echo "no r.Context() usage found — handler must propagate request context, not context.Background()"; return 1; }
  grep -qE '\.MustParse\(' $all_go_files && { echo "found a Must*Parse call on what should be request-derived data — anti-pattern: a panic on untrusted input is a DoS vector"; return 1; }
  grep -q 'writeDomainError' "$dir/errors.go" || { echo "no writeDomainError function found in errors.go — single error-mapping-point convention not followed"; return 1; }

  assert_go_valid "$scratch" || return 1
  return 0
}

smoke_test_acceptance \
  "agents/backend-engineer (acceptance)" \
  "Use the Agent tool to dispatch the 'backend-engineer' subagent with exactly this task: using the go-chi-handler skill from this plugin, implement a single HTTP handler for 'GET /v1/widgets/{id}' that looks up a widget by UUID id and returns it, mapping a not-found case to 404 through the skill's single writeDomainError mapping point. Define whatever minimal application-layer interface/types you need (e.g. a query handler) as stand-ins so the package is self-contained and compiles on its own — the deliverable is the transport layer. This is a standalone Go module — run 'go mod init acceptancetest' and 'go mod tidy' at $SCRATCH_DIR first so the module resolves its dependencies (chi, uuid). You must create ALL FOUR of these exact files (all four are required, none optional) under $SCRATCH_DIR/$HANDLER_DIR_REL/: (1) router.go — the chi router; (2) a handler file (any name) with the GET /v1/widgets/{id} handler; (3) errors.go — writeError, writeDomainError, and the error envelope; (4) a _test.go file using net/http/httptest, written first per TDD. Do not run gofmt, go vet, go build, or any tests yourself after writing the files — validation happens separately. Do not produce anything else, do not ask for approval, just write the four files and stop." \
  "$ROUTER" \
  validate_go_chi_handler

smoke_test_summary
