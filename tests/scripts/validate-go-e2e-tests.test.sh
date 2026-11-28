#!/bin/bash
# Synthetic-input test for go-e2e-test's validator. Needs no Go, Docker or cluster.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/go-e2e-test/scripts/validate-go-e2e-tests.sh"
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

# go_case <name> <pattern> <exit> <build tag line> <body>: one Go file under tests/e2e/
go_case() {
  local name="$1" pattern="$2" want="$3" tag="$4" body="$5"
  mkdir -p "$TMP/$name/tests/e2e"
  printf '%s\n\npackage e2e\n\n%s\n' "$tag" "$body" > "$TMP/$name/tests/e2e/a_test.go"
  check "$name" "$want" "$pattern" "$TMP/$name"
}

# sh_case <name> <pattern> <exit> <script body>: one script under tests/e2e/
sh_case() {
  local name="$1" pattern="$2" want="$3" body="$4"
  mkdir -p "$TMP/$name/tests/e2e"
  printf '#!/bin/bash\n%s\n' "$body" > "$TMP/$name/tests/e2e/run.sh"
  check "$name" "$want" "$pattern" "$TMP/$name"
}

# wf_case <name> <pattern> <exit> <workflow text>
wf_case() {
  local name="$1" pattern="$2" want="$3" body="$4"
  mkdir -p "$TMP/$name/.github/workflows"
  printf '%s\n' "$body" > "$TMP/$name/.github/workflows/e2e.yml"
  check "$name" "$want" "$pattern" "$TMP/$name"
}

check "no arguments is a usage error" 2 "usage"
check "missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty" && echo "package x" > "$TMP/empty/main.go"
check "nothing to check" 2 "nothing was checked" "$TMP/empty"

JOURNEY='//go:build e2e && !smoke'
go_case clean-journey ": 0 FAIL, 0 WARN" 0 "$JOURNEY" '// TestJourney_Books proves AC-US-4.1.
// time.Sleep( and ON CONFLICT DO UPDATE in a comment are not code.
func TestJourney_Books(t *testing.T) {
	api.Do(ctx, http.MethodPost, "/bookings", nil, nil)
	db.ExecContext(ctx, `INSERT INTO bookings (id) VALUES ($1)`, id)
}'
go_case untagged "FAIL TAG .*no e2e or smoke build tag" 1 "// no tag" 'func TestJourney_X(t *testing.T) {}'
go_case other-tag "FAIL TAG" 1 "//go:build integration" 'func TestX(t *testing.T) {}'
mkdir -p "$TMP/nontest/tests/e2e"
printf '//go:build e2e\n\npackage e2e\n' > "$TMP/nontest/tests/e2e/helpers.go"
check "helper that is not a _test.go file" 1 "FAIL TAG .*not a _test.go file" "$TMP/nontest"
go_case smoke-http-write "FAIL SMOKEWRITE .*HTTP write" 1 "//go:build smoke" 'func TestSmoke_X(t *testing.T) { c.Do(ctx, http.MethodDelete, "/bookings/1", nil, nil) }'
go_case smoke-sql-write "FAIL SMOKEWRITE .*database" 1 "//go:build smoke" 'const q = `DELETE FROM bookings WHERE id = $1`'
go_case journey-without-not-smoke "FAIL SMOKEWRITE .*build tag: e2e\)" 1 "//go:build e2e" 'func TestJourney_X(t *testing.T) { c.Do(ctx, "POST", "/x", nil, nil) }'
go_case shared-helper-write "FAIL SMOKEWRITE" 1 "//go:build e2e || smoke" 'func seed() { c.Do(ctx, http.MethodPut, "/x", nil, nil) }'
go_case smoke-read-only ": 0 FAIL" 0 "//go:build smoke" 'func TestSmoke_Reads(t *testing.T) { c.Do(ctx, http.MethodGet, "/bookings", nil, nil) }'
go_case smoke-refusal-check ": 0 FAIL" 0 "//go:build smoke" 'func TestSmoke_WritesAreRefused(t *testing.T) {
	for _, m := range []string{http.MethodPost, http.MethodDelete} { // smoke-refusal-check: each must be refused
	}
}'
go_case upsert "FAIL UPSERT" 1 "$JOURNEY" 'const q = `INSERT INTO tenants (id) VALUES ($1)
	ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name`'
go_case sleep "FAIL SLEEP" 1 "$JOURNEY" 'func wait() { time.Sleep(3 * time.Second) }'
go_case env-address "FAIL ENVADDR" 1 "$JOURNEY" 'var base = os.Getenv("E2E_BASE_URL")'
go_case smoke-env-address-allowed ": 0 FAIL" 0 "//go:build smoke" 'var base = os.Getenv("E2E_SMOKE_URL")'
go_case skip "FAIL SKIP" 1 "$JOURNEY" 'func TestJourney_X(t *testing.T) { t.Skip("flaky, investigate later") }'
go_case no-criterion "WARN NOCRITERION .*TestJourney_Books" 0 "$JOURNEY" '// TestJourney_Books books a slot.
func TestJourney_Books(t *testing.T) {}'

GOOD_SCRIPT='k() { kubectl --kubeconfig "$KCFG" --context "$CONTEXT" "$@"; }
h() { helm --kubeconfig "$KCFG" --kube-context "$CONTEXT" "$@"; }
trap teardown EXIT INT TERM
# kubectl get pods in a comment is not a command
kind create cluster --name "$CLUSTER" --kubeconfig "$KCFG" --wait 180s
kind load docker-image app:e2e --name "$CLUSTER"
h upgrade --install app charts/app --wait --timeout 180s
k rollout status deployment/app --timeout 180s
helm version --short
go test -tags e2e -count=1 ./tests/e2e/
kind delete cluster --name "$CLUSTER" --kubeconfig "$KCFG"'
sh_case clean-script ": 0 FAIL, 0 WARN" 0 "$GOOD_SCRIPT"
sh_case kubectl-current-context "FAIL KUBECONFIG .*kubectl without --kubeconfig" 1 'kubectl rollout status deploy/app'
sh_case helm-current-context "FAIL KUBECONFIG .*helm without --kubeconfig" 1 'helm install app charts/app --wait'
sh_case kind-default-kubeconfig "FAIL KUBECONFIG .*kind without --kubeconfig" 1 'kind create cluster --name e2e-1 --wait 120s
go test -tags e2e ./tests/e2e/
kind delete cluster --name e2e-1 --kubeconfig "$KCFG"'
sh_case kind-default-name "FAIL KUBECONFIG .*kind without --name" 1 'kind create cluster --kubeconfig "$KCFG"
go test -tags e2e ./tests/e2e/
kind delete cluster --name x --kubeconfig "$KCFG"'
sh_case use-context "FAIL KUBECONFIG .*kubectl config" 1 'kubectl config use-context kind-e2e'
sh_case continued-line "FAIL KUBECONFIG .*run.sh:2" 1 'helm install app charts/app \
  --wait --timeout 180s'
sh_case helm-no-wait "FAIL HELMWAIT" 1 'helm --kubeconfig "$KCFG" upgrade --install app charts/app'
sh_case sleep-wait "FAIL SLEEP" 1 'sleep 30'
sh_case sleep-in-loop "FAIL SLEEP" 1 'for i in 1 2 3; do sleep 5; done'
sh_case trap-only "FAIL TRAPONLY .*before the tests run" 1 'cleanup() { kind delete cluster --name "e2e-$RUN" --kubeconfig "$KCFG"; }
trap cleanup EXIT
kind create cluster --name "e2e-$RUN" --kubeconfig "$KCFG" --wait 120s'
sh_case provision-only "FAIL TRAPONLY .*does not run the tests" 1 'kind create cluster --name "e2e-$RUN" --kubeconfig "$KCFG"
kind delete cluster --name old --kubeconfig "$KCFG"'
sh_case no-teardown "FAIL NOTEARDOWN" 1 'kind create cluster --name "e2e-$RUN" --kubeconfig "$KCFG"
go test -tags e2e ./tests/e2e/'
sh_case rerun-everything "FAIL RERUN" 1 'go test -tags e2e ./tests/e2e/ || go test -tags e2e ./tests/e2e/'
sh_case cloud "FAIL CLOUD" 1 'aws ec2 terminate-instances --filters Name=tag:Name,Values=e2e-*'
sh_case compose "FAIL COMPOSE" 1 'docker compose up -d'

mkdir -p "$TMP/make"
printf 'local-up:\n\tkind create cluster --name dev\n\ne2e:\n\thelm install app charts/app\n' > "$TMP/make/Makefile"
check "only the e2e targets of a Makefile are read" 1 "Makefile:5: helm without --kubeconfig" "$TMP/make"
mkdir -p "$TMP/make-ok"
printf 'local-up:\n\tkind create cluster --name dev\n\ne2e:\n\t./tests/e2e/run-e2e-environment.sh\n' > "$TMP/make-ok/Makefile"
check "a Makefile whose e2e target calls the script" 0 "1 Makefile\(s\).*: 0 FAIL" "$TMP/make-ok"

GOOD_WF='name: e2e
on:
  schedule:
    - cron: "17 2 * * *"
  workflow_dispatch:
  workflow_call:
permissions:
  contents: read
jobs:
  e2e:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - run: make e2e
      - if: ${{ always() }}
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9
        with:
          path: e2e-evidence/'
wf_case clean-workflow "1 workflow\(s\): 0 FAIL, 0 WARN" 0 "$GOOD_WF"
wf_case no-permissions "FAIL PERMISSIONS .*no permissions block" 1 "$(printf '%s\n' "$GOOD_WF" | grep -v -e '^permissions' -e 'contents: read')"
wf_case write-all "FAIL PERMISSIONS .*write-all" 1 "$(printf '%s\n' "$GOOD_WF" | sed 's/^permissions:$/permissions: write-all/' | grep -v 'contents: read')"
wf_case release-published "FAIL RELEASE .*after the release exists" 1 'on:
  release:
    types: [published]
permissions:
  contents: read
jobs:
  e2e:
    steps:
      - run: make e2e'
wf_case pull-request "FAIL PRTRIGGER" 1 'on:
  pull_request:
permissions:
  contents: read
jobs:
  e2e:
    steps:
      - run: make e2e'
wf_case stored-credential "FAIL CREDENTIALS .*STAGING_KUBECONFIG" 1 "$GOOD_WF
        env:
          KUBECONFIG_DATA: \${{ secrets.STAGING_KUBECONFIG }}"
wf_case workflow-current-context "FAIL KUBECONFIG" 1 "$GOOD_WF
      - run: kind delete cluster --name chart-testing"
wf_case unpinned-action "WARN UNPINNED .*actions/checkout@v4" 0 "$(printf '%s\n' "$GOOD_WF" | sed 's/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1/checkout@v4/')"
wf_case upload-skipped-on-failure "WARN NOALWAYS" 0 "$(printf '%s\n' "$GOOD_WF" | grep -v 'always()' | sed 's/^        uses: actions.upload/      - uses: actions\/upload/')"
mkdir -p "$TMP/other-wf/.github/workflows"
printf 'on:\n  pull_request:\njobs:\n  ci:\n    steps:\n      - run: make ci\n' > "$TMP/other-wf/.github/workflows/ci.yml"
check "a workflow that does not run the suite is not read" 2 "nothing was checked" "$TMP/other-wf"

# The shipped scripts, templates and examples must satisfy the validator.
python3 -I - "$REPO_ROOT/skills/go-e2e-test" "$TMP/shipped" <<'PY'
import os, re, shutil, sys
skill, out = sys.argv[1:]
count = 0
for folder in ("templates", "examples"):
    for name in sorted(os.listdir(os.path.join(skill, folder))):
        text = open(os.path.join(skill, folder, name), encoding="utf-8").read()
        for path, lang, body in re.findall(r"^#{2,4} `([\w./-]+)`\n\n```(go|yaml|makefile|bash)\n(.*?)^```", text, re.M | re.S):
            target = os.path.join(out, name[:-3], path)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w", encoding="utf-8").write(body)
            count += 1
assert count > 5, f"only {count} shipped blocks extracted"
os.makedirs(os.path.join(out, "scripts", "tests", "e2e"))
for script in ("run-e2e-environment.sh", "run-go-e2e-suite.sh"):
    shutil.copy(os.path.join(skill, "scripts", script), os.path.join(out, "scripts", "tests", "e2e", script))
PY
check "shipped scripts, templates and examples are clean" 0 ": 0 FAIL, 0 WARN" "$TMP/shipped"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-go-e2e-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
