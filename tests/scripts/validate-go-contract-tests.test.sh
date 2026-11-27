#!/bin/bash
# Synthetic-input test for go-contract-test's validator. Needs neither Go nor Docker.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-contract-test/scripts/validate-go-contract-tests.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# check <label> <expected exit> <expected output pattern or -> <path...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$out"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$out"; FAILURES=$((FAILURES + 1))
  fi
}

# one <name> <file name> <pattern> <expected exit> <content>: a single offending file
one() {
  local name="$1" file="$2" pattern="$3" want="$4" body="$5"
  mkdir -p "$TMP/$name"
  printf '%s\n' "$body" > "$TMP/$name/$file"
  check "$name" "$want" "$pattern" "$TMP/$name"
}

check "no arguments is a usage error" 2 "usage"
check "missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty" && echo "notes" > "$TMP/empty/readme.txt"
check "nothing to check" 2 "nothing was checked" "$TMP/empty"

mkdir -p "$TMP/good/.github/workflows"
cat > "$TMP/good/provider_pact_test.go" <<'GO'
//go:build pact

package classes_test

import (
	"github.com/pact-foundation/pact-go/v2/provider"
)

// Latest: true and SoftFail: true in a comment are not code.
func TestPact(t *testing.T) {
	request := provider.VerifyRequest{
		ConsumerVersionSelectors: []provider.Selector{&provider.ConsumerVersionSelector{MainBranch: true}},
		FailIfNoPactsFound:       true,
		BeforeEach:               store.forget,
		StateHandlers:            states(store),
	}
	_ = request
}
GO
cat > "$TMP/good/spec.go" <<'GO'
package contract

func validate() error {
	options := &openapi3filter.Options{IncludeResponseStatus: true}
	compiler := jsonschema.NewCompiler()
	compiler.AssertFormat()
	return openapi3filter.ValidateResponse(ctx, input(options))
}
GO
cat > "$TMP/good/.github/workflows/pact-daily.yml" <<'YML'
on:
  schedule:
    - cron: "17 3 * * *"
  workflow_dispatch:
jobs:
  pact:
    steps:
      - run: go test -tags pact -run '^TestPact' ./...
      - run: pact-broker can-i-deploy --pacticipant classes --version "$GITHUB_SHA" --to-environment production
YML
cat > "$TMP/good/.github/workflows/ci.yml" <<'YML'
on:
  pull_request:
jobs:
  contract:
    steps:
      - run: make ci
      # oasdiff breaking without a flag, in a comment, is not a command
      - run: oasdiff breaking --fail-on WARN deployed.yaml api/openapi.yaml
YML
printf 'ci: tidy cover\ncover:\n\tgo test -race ./...\npact:\n\tgo test -tags pact ./...\n' > "$TMP/good/Makefile"
check "clean files pass" 0 "checked 5 file\(s\): 0 FAIL, 0 WARN" "$TMP/good"

one untagged a_pact_test.go "FAIL PACTTAG .*:3" 1 'package x_test

import "github.com/pact-foundation/pact-go/v2/consumer"'
one othertag a_pact_test.go "FAIL PACTTAG" 1 '//go:build integration

package x_test

import "github.com/pact-foundation/pact-go/v2/consumer"'
one messagepact a_test.go "FAIL MESSAGEPACT" 1 '//go:build pact

package x_test

import "github.com/pact-foundation/pact-go/v2/message/v4"'
one latest a_test.go "FAIL LATEST" 1 '//go:build pact

package x_test

var s = provider.ConsumerVersionSelector{Latest: true}'
one softfail a_test.go "FAIL SOFTFAIL" 1 'package x_test

var r = provider.VerifyRequest{FailIfNoPactsFound: true, SoftFail: true}'
one nopacts a_test.go "FAIL NOPACTS" 1 'package x_test

var r = provider.VerifyRequest{ProviderBaseURL: url}'
one nopactsfalse a_test.go "FAIL NOPACTS" 1 'package x_test

var r = provider.VerifyRequest{FailIfNoPactsFound: false}'
one stateguard a_test.go "WARN STATEGUARD" 0 'package x_test

var r = provider.VerifyRequest{FailIfNoPactsFound: true, StateHandlers: handlers}'
one status spec.go "FAIL STATUS" 1 'package contract

func f() error { return openapi3filter.ValidateResponse(ctx, input) }'
one format events.go "FAIL FORMAT" 1 'package contract

var c = jsonschema.NewCompiler()'
one unknownfields client.go "WARN UNKNOWNFIELDS" 0 'package client

func f(d *json.Decoder) { d.DisallowUnknownFields() }'

one dryrun deploy.yml "FAIL DRYRUN" 1 'steps:
  - run: pact-broker can-i-deploy --pacticipant a --version 1 --to-environment production --dry-run'
one dryruncontinued deploy.sh "FAIL DRYRUN .*deploy.sh:1" 1 'pact-broker can-i-deploy --pacticipant a \
  --version 1 --dry-run'
one nofailon ci.yml "FAIL NOFAILON" 1 'steps:
  - run: oasdiff breaking deployed.yaml api/openapi.yaml'
one versionbump ci.yml "FAIL VERSIONBUMP" 1 'steps:
  - run: oasdiff breaking --fail-on MISSING-VERSION-BUMP deployed.yaml api/openapi.yaml'
one ignored gate.sh "FAIL IGNORED" 1 'bash check-openapi-breaking.sh --base a --revision b || true'
one ignoredbuf ci.yml "FAIL IGNORED" 1 'steps:
  - run: buf breaking --against .git#ref=deployed || true'
one paid ci.yml "FAIL PAID" 1 'env:
  PACT_BROKER_BASE_URL: https://acme.pactflow.io'
one pactonpr pact.yml "FAIL PACTONPR" 1 'on:
  pull_request:
jobs:
  pact:
    steps:
      - run: go test -tags=pact ./...'
one pactonpush pact.yml "FAIL PACTONPR" 1 'on: [push]
jobs:
  pact:
    steps:
      - run: pact-broker publish ./pacts --consumer-app-version 1 --branch main'
one continue ci.yml "WARN CONTINUE" 0 'jobs:
  gate:
    steps:
      - run: oasdiff breaking --fail-on WARN a b
        continue-on-error: true'
one pactinci Makefile "FAIL PACTINCI .*target .cover." 1 'ci: cover
cover:
	go test -race -tags pact ./...'

# The shipped templates and examples must satisfy the validator (code blocks extracted from Markdown).
python3 -I - "$REPO_ROOT/skills/go-contract-test" "$TMP/shipped" <<'PY'
import os, re, sys
skill, out = sys.argv[1:]
count = 0
for folder in ("templates", "examples"):
    for name in sorted(os.listdir(os.path.join(skill, folder))):
        text = open(os.path.join(skill, folder, name), encoding="utf-8").read()
        for path, body in re.findall(r"^#{2,4} `([\w./-]+\.(?:go|yml|yaml|sh)|[\w./-]*Makefile)`\n\n```\w*\n(.*?)^```", text, re.M | re.S):
            target = os.path.join(out, name[:-3], path)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w", encoding="utf-8").write(body)
            count += 1
assert count > 0, "no code blocks extracted"
PY
check "shipped templates and examples are clean" 0 ": 0 FAIL, 0 WARN" "$TMP/shipped"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-go-contract-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
