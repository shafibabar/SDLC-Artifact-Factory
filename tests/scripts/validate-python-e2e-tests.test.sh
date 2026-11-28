#!/bin/bash
# Synthetic-input test for python-e2e-test's validator. It needs no pytest,
# Docker or cluster: every case is text in a temporary folder. The last case
# extracts every shipped whole-file block of the skill and expects it clean.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SKILL="$REPO_ROOT/skills/python-e2e-test"
SCRIPT="$SKILL/scripts/validate-python-e2e-tests.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# check <label> <expected exit> <output pattern or -> <paths...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local rc
  OUT="$(bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$OUT"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$OUT"; FAILURES=$((FAILURES + 1))
  fi
}
# py_case <name> <folder: journeys|smoke|.> <file name> <pattern> <expected exit> <content>
py_case() {
  local dir="$TMP/py-$1/tests/e2e/$2"
  mkdir -p "$dir"
  printf '%s\n' "$6" > "$dir/$3"
  check "python: $1" "$5" "$4" "$TMP/py-$1"
}
sh_case() {
  mkdir -p "$TMP/sh-$1/tests/e2e"
  printf '%s\n' "$4" > "$TMP/sh-$1/tests/e2e/run.sh"
  check "script: $1" "$3" "$2" "$TMP/sh-$1"
}
wf_case() {
  mkdir -p "$TMP/wf-$1/.github/workflows"
  printf '%s\n' "$4" > "$TMP/wf-$1/.github/workflows/e2e.yml"
  check "workflow: $1" "$3" "$2" "$TMP/wf-$1"
}

check "no arguments is a usage error" 2 "usage"
check "a missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty/src"; printf 'x = 1\n' > "$TMP/empty/src/app.py"
check "nothing to check is not a pass" 2 "nothing was checked" "$TMP/empty"

# ------------------------------------------------------------- Python files
GOOD_JOURNEY='from __future__ import annotations

import httpx

from tests.e2e.support import eventually


def test_journey_loan_is_confirmed(api: httpx.Client) -> None:
    """AC-US-3.1: a requested loan is confirmed. The word POST in a docstring,
    "ON CONFLICT DO UPDATE" in a comment below, and time.sleep in prose are not code."""
    # never ON CONFLICT (id) DO UPDATE; never time.sleep(3)
    made = api.post("/loans", json={"exhibit": "bronze-mirror"}).json()

    def confirmed() -> None:
        assert api.get("/loans/" + made["id"]).json()["status"] == "confirmed"

    eventually("loan confirmed", confirmed, within=20)'
py_case clean-journey journeys test_journey_loan.py ": 0 FAIL, 0 WARN" 0 "$GOOD_JOURNEY"
py_case clean-smoke smoke test_smoke.py ": 0 FAIL, 0 WARN" 0 'import httpx


def test_smoke_loans_can_be_listed(smoke: httpx.Client) -> None:
    assert smoke.get("/loans").status_code == 200'
py_case test-outside-the-two-folders . test_stray.py "FAIL LAYOUT .*neither journeys/ nor smoke/" 1 'def test_stray() -> None:
    pass'
py_case test-in-another-folder helpers test_extra.py "FAIL LAYOUT" 1 'def test_extra() -> None:
    pass'
py_case smoke-posts smoke test_smoke.py "FAIL SMOKEWRITE .*HTTP POST in a smoke file" 1 'def test_smoke_creates(smoke):
    assert smoke.post("/loans", json={}).status_code == 201'
py_case smoke-method-word smoke test_smoke.py "FAIL SMOKEWRITE .*HTTP write method" 1 'def test_smoke_changes(smoke):
    smoke.request("PUT", "/loans/1", json={})'
py_case smoke-refusal-check-is-allowed smoke test_smoke_guard.py ": 0 FAIL" 0 'import pytest


def test_smoke_writes_are_refused(smoke):
    for method in ("POST", "PUT", "PATCH", "DELETE"):  # smoke-refusal-check: each must be refused
        with pytest.raises(Exception):
            smoke.request(method, "/", json={})'
py_case smoke-uses-journey-fixture smoke test_smoke.py "FAIL SMOKEWRITE .*asks for the journey fixture .create_loan." 1 'def test_smoke_seeds(smoke, create_loan):
    create_loan(exhibit="x")'
py_case smoke-uses-env smoke test_smoke.py "FAIL SMOKEWRITE .*journey fixture .env." 1 'async def test_smoke_env(env):
    pass'
py_case smoke-imports-journey-code smoke test_smoke.py "FAIL SMOKEWRITE .*imports tests.e2e.journeys.seed_db" 1 'from tests.e2e.journeys.seed_db import insert_loan_row


def test_smoke_x(smoke):
    pass'
py_case smoke-imports-a-database-driver smoke test_smoke.py "FAIL SMOKEWRITE .*imports asyncpg" 1 'import asyncpg


def test_smoke_x(smoke):
    pass'
py_case smoke-sql-write smoke test_smoke.py "FAIL SMOKEWRITE .*database write" 1 'def test_smoke_x(smoke, connection):
    connection.execute("DELETE FROM loans WHERE id = 1")'
py_case upsert journeys seed_db.py "FAIL UPSERT" 1 'async def seed(connection, tenant):
    await connection.execute(
        """INSERT INTO tenants (id, name) VALUES ($1, $2)
           ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name""", tenant, "e2e")'
py_case plain-insert-is-fine journeys seed_db.py ": 0 FAIL" 0 'async def seed(connection, loan_id):
    await connection.execute("INSERT INTO loans (id) VALUES ($1)", loan_id)'
py_case time-sleep journeys test_journey_x.py "FAIL SLEEP" 1 'import time


def test_journey_x(api):
    """AC-US-1.1"""
    api.post("/loans", json={})
    time.sleep(3)'
py_case asyncio-sleep journeys test_journey_x.py "FAIL SLEEP" 1 'import asyncio


async def test_journey_x(env):
    """AC-US-1.1"""
    await asyncio.sleep(2)'
py_case poll-interval-is-allowed . support.py ": 0 FAIL" 0 'import time


def eventually(check, within):
    deadline = time.monotonic() + within
    while time.monotonic() < deadline:
        time.sleep(0.2)  # e2e-poll-interval: a pause between checks inside a deadline'
py_case address-from-environment journeys conftest.py "FAIL ENVADDR .*E2E_BASE_URL" 1 'import os

import pytest


@pytest.fixture(scope="session")
def base_url() -> str:
    return os.environ["E2E_BASE_URL"]'
py_case broker-address-from-environment journeys conftest.py "FAIL ENVADDR .*E2E_KAFKA_BOOTSTRAP" 1 'import os

BOOTSTRAP = os.getenv("E2E_KAFKA_BOOTSTRAP")'
py_case smoke-url-in-the-shared-conftest . conftest.py ": 0 FAIL" 0 'import os

BASE = os.environ.get("E2E_SMOKE_URL", "")
RUN = os.environ.get("E2E_RUN_ID", "")'
py_case smoke-url-in-a-journey journeys test_journey_x.py "FAIL ENVADDR .*E2E_SMOKE_URL" 1 'import os


def test_journey_x(api):
    """AC-US-1.1"""
    api.post(os.environ["E2E_SMOKE_URL"] + "/loans", json={})'
py_case plain-httpx-client journeys conftest.py "FAIL RAWCLIENT" 1 'import httpx
import pytest


@pytest.fixture
def client():
    with httpx.AsyncClient(base_url="http://127.0.0.1:8080", timeout=10.0) as c:
        yield c'
py_case requests-library journeys test_journey_x.py "FAIL RAWCLIENT" 1 'import requests


def test_journey_x():
    """AC-US-1.1"""
    requests.get("http://127.0.0.1:8080/loans")'
py_case support-may-build-clients . support.py ": 0 FAIL" 0 'import httpx


def bound_client(base):
    return httpx.Client(base_url=base)'
py_case asgi-transport journeys test_journey_x.py "FAIL INPROCESS .*no network hop" 1 'import httpx
from app.main import app


async def test_journey_x(env):
    """AC-US-1.1"""
    transport = httpx.ASGITransport(app=app)'
py_case fastapi-testclient journeys test_journey_x.py "FAIL INPROCESS" 1 'from fastapi.testclient import TestClient'
py_case kube-client-default-loader . support.py "FAIL KUBECLIENT .*caller.s kubeconfig" 1 'from kubernetes import config


def marker():
    config.load_kube_config()'
py_case kube-client-with-the-runs-file . support.py ": 0 FAIL" 0 'from kubernetes import config


def marker(path, context):
    return config.new_client_from_config(config_file=path, context=context, persist_config=False)'
py_case skip-marker journeys test_journey_x.py "FAIL SKIP" 1 'import pytest


@pytest.mark.skip(reason="flaky, investigate later")
def test_journey_x(api):
    """AC-US-1.1"""'
py_case xfail journeys test_journey_x.py "FAIL SKIP" 1 'import pytest


@pytest.mark.xfail
def test_journey_x(api):
    """AC-US-1.1"""'
py_case skip-call journeys test_journey_x.py "FAIL SKIP" 1 'import pytest


def test_journey_x(api):
    """AC-US-1.1"""
    pytest.skip("no cluster")'
py_case quarantine-marker journeys test_journey_x.py "FAIL QUARANTINEMARK .*quarantine-python.txt" 1 'import pytest


@pytest.mark.quarantine
def test_journey_x(api):
    """AC-US-1.1"""'
py_case flaky-marker journeys test_journey_x.py "FAIL RERUN .*rerun set in the test" 1 'import pytest


@pytest.mark.flaky(reruns=5, reruns_delay=2)
def test_journey_x(api):
    """AC-US-1.1"""'
py_case no-criterion journeys test_journey_x.py "WARN NOCRITERION .*test_journey_x" 0 'def test_journey_x(api):
    """A loan is confirmed."""'
py_case criterion-in-a-comment-above journeys test_journey_x.py ": 0 FAIL, 0 WARN" 0 '# AC-US-3.1
def test_journey_x(api):
    pass'
py_case evidence-folder-is-not-read e2e-evidence copy.py "nothing was checked" 2 'import time
time.sleep(1)'

# --------------------------------------------------------- pytest settings
settings_case() {
  mkdir -p "$TMP/set-$1/tests/e2e/journeys"
  printf 'def test_journey_x(api):\n    """AC-US-1.1"""\n' > "$TMP/set-$1/tests/e2e/journeys/test_journey_x.py"
  printf '%s\n' "$4" > "$TMP/set-$1/pyproject.toml"
  check "settings: $1" "$3" "$2" "$TMP/set-$1"
}
settings_case clean "1 pytest settings file\(s\).*: 0 FAIL" 0 '[tool.pytest.ini_options]
asyncio_mode = "auto"
markers = ["integration: needs a real database"]'
settings_case reruns-in-addopts "FAIL RERUN .*pyproject.toml:2" 1 '[tool.pytest.ini_options]
addopts = "--reruns 2 -ra"'
settings_case reruns-key "FAIL RERUN" 1 '[tool.pytest.ini_options]
reruns = 1'
settings_case commented-reruns-are-ignored ": 0 FAIL" 0 '[tool.pytest.ini_options]
# addopts = "--reruns 2"
asyncio_mode = "auto"'
settings_case thread-timeout "FAIL TIMEOUTTHREAD .*no teardown" 1 '[tool.pytest.ini_options]
timeout = 60
timeout_method = "thread"'
settings_case signal-timeout-is-fine ": 0 FAIL" 0 '[tool.pytest.ini_options]
timeout = 60
timeout_method = "signal"'

# ------------------------------------------------------------------ scripts
GOOD_SCRIPT='k() { kubectl --kubeconfig "$KCFG" --context "$CONTEXT" "$@"; }
h() { helm --kubeconfig "$KCFG" --kube-context "$CONTEXT" "$@"; }
trap teardown EXIT INT TERM
# kubectl get pods in a comment is not a command
kind create cluster --name "$CLUSTER" --kubeconfig "$KCFG" --wait 180s
kind load docker-image app:e2e --name "$CLUSTER"
h upgrade --install app charts/app --wait --timeout 180s
k rollout status deployment/app --timeout 180s
helm version --short
echo "run pytest through the runner"
./tests/e2e/run-python-e2e-suite.sh journeys
kind delete cluster --name "$CLUSTER" --kubeconfig "$KCFG"'
sh_case clean-script ": 0 FAIL, 0 WARN" 0 "$GOOD_SCRIPT"
# The script this skill used to show: the exit trap deletes the cluster when
# the script ends, and pytest ran in the next workflow step.
sh_case the-earlier-provisioning-script "FAIL TRAPONLY .*before the tests run" 1 'teardown() { kind delete cluster --name "${CLUSTER}" >/dev/null 2>&1 || true; }
trap teardown EXIT
kind create cluster --name "${CLUSTER}" --wait 120s
helm install "${svc}" "charts/${svc}" --namespace app --wait --timeout 180s
kubectl -n app port-forward svc/ingress 8080:80 >/dev/null 2>&1 &
echo "E2E_BASE_URL=http://127.0.0.1:8080"'
if grep -qE "FAIL KUBECONFIG .*kind without --kubeconfig" <<<"$OUT" && grep -qE "FAIL KUBECONFIG .*helm without --kubeconfig" <<<"$OUT" \
  && grep -qE "FAIL KUBECONFIG .*kubectl without --kubeconfig" <<<"$OUT"; then
  echo "PASS: script: the earlier script also acts on the caller's context three times"; else
  echo "FAIL: script: caller's-context findings missing"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
sh_case kubectl-current-context "FAIL KUBECONFIG .*kubectl without --kubeconfig" 1 'kubectl rollout status deploy/app'
sh_case use-context "FAIL KUBECONFIG .*kubectl config" 1 'kubectl config use-context kind-e2e'
sh_case kind-default-name "FAIL KUBECONFIG .*kind without --name" 1 'kind create cluster --kubeconfig "$KCFG"
./tests/e2e/run-python-e2e-suite.sh journeys
kind delete cluster --name x --kubeconfig "$KCFG"'
sh_case helm-no-wait "FAIL HELMWAIT" 1 'helm --kubeconfig "$KCFG" upgrade --install app charts/app'
sh_case sleep-wait "FAIL SLEEP" 1 'sleep 30'
sh_case provision-only "FAIL TRAPONLY .*does not run the tests" 1 'kind create cluster --name "e2e-$RUN" --kubeconfig "$KCFG"
kind delete cluster --name old --kubeconfig "$KCFG"'
sh_case no-teardown "FAIL NOTEARDOWN" 1 'kind create cluster --name "e2e-$RUN" --kubeconfig "$KCFG"
./tests/e2e/run-python-e2e-suite.sh journeys'
sh_case delete-every-cluster "FAIL SWEEP .*every kind cluster" 1 'kind delete clusters --all'
sh_case delete-by-pattern "FAIL SWEEP .*by pattern" 1 'kind get clusters | grep "^e2e-" | xargs -n1 kind delete cluster --kubeconfig "$KCFG" --name'
sh_case delete-in-a-loop "FAIL SWEEP" 1 'for c in $(kind get clusters); do kind delete cluster --name "$c" --kubeconfig "$KCFG"; done'
sh_case pytest-directly "FAIL RERUN .*pytest called directly" 1 'pytest tests/e2e -m "e2e and not quarantine" -v'
sh_case rerun-plugin "FAIL RERUN .*rerun plugin or a rerun loop" 1 'pytest tests/e2e -m e2e --reruns 1 --only-rerun "" -p no:cacheprovider -v'
sh_case rerun-loop "FAIL RERUN" 1 'pytest tests/e2e/journeys || pytest tests/e2e/journeys --lf'
sh_case uv-run-pytest "FAIL RERUN .*pytest called directly" 1 'uv run pytest tests/e2e/smoke -m smoke'
sh_case the-runner-is-fine ": 0 FAIL" 0 'uv run ./tests/e2e/run-python-e2e-suite.sh smoke'
sh_case cloud "FAIL CLOUD" 1 'aws ec2 terminate-instances --filters Name=tag:Name,Values=e2e-*'
sh_case compose "FAIL COMPOSE" 1 'docker compose up -d'
sh_case compose-v1 "FAIL COMPOSE" 1 'docker-compose -f tests/e2e/docker-compose.yml up -d'

mkdir -p "$TMP/make"
printf 'local-up:\n\tkind create cluster --name dev\n\ntest:\n\tuv run pytest tests/unit\n\ne2e:\n\tuv run pytest tests/e2e -m e2e\n' > "$TMP/make/Makefile"
check "only the e2e targets of a Makefile are read" 1 "Makefile:8: pytest called directly" "$TMP/make"
if [[ "$(grep -c "^FAIL " <<<"$OUT")" -eq 1 ]]; then echo "PASS: the other targets raise nothing"; else echo "FAIL: other targets were read"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
mkdir -p "$TMP/make-ok"
printf 'e2e:\n\t./tests/e2e/run-e2e-environment.sh\n\ne2e-smoke:\n\tuv run ./tests/e2e/run-python-e2e-suite.sh smoke\n' > "$TMP/make-ok/Makefile"
check "a Makefile whose e2e targets call the scripts" 0 "1 Makefile\(s\).*: 0 FAIL" "$TMP/make-ok"

# ---------------------------------------------------------------- workflows
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
      - run: make install
      - run: make e2e
      - if: ${{ always() }}
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9
        with:
          path: e2e-evidence/
      - if: ${{ always() }}
        run: kind delete cluster --name "e2e-gh-${{ github.run_id }}-${{ github.run_attempt }}" --kubeconfig "$RUNNER_TEMP/backstop"'
wf_case clean-workflow ": 0 FAIL, 0 WARN" 0 "$GOOD_WF"
# The workflow this skill used to show.
wf_case the-earlier-workflow "FAIL RELEASE" 1 'name: e2e-journeys
on:
  schedule:
    - cron: "0 2 * * *"
  release:
    types: [published]
  workflow_dispatch: {}
jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - id: provision
        run: ./tests/e2e/provision-kind.sh | tee -a "$GITHUB_ENV"
      - run: pytest tests/e2e -m "e2e and not quarantine" --reruns 1 -v
      - if: always()
        run: kind delete cluster --name "e2e-${GITHUB_RUN_ID}" || true'
for rule in "FAIL PERMISSIONS .*no permissions block" "FAIL ENVFILE" "FAIL RERUN" "FAIL KUBECONFIG .*kind without --kubeconfig" "WARN UNPINNED .*actions/checkout@v4"; do
  if grep -qE -- "$rule" <<<"$OUT"; then echo "PASS: workflow: the earlier workflow also raises $rule"; else
    echo "FAIL: workflow: the earlier workflow lacks $rule"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
done
wf_case pull-request-trigger "FAIL PRTRIGGER" 1 "$(printf '%s\n' "$GOOD_WF" | sed 's/^  workflow_dispatch:$/  pull_request:/')"
wf_case write-all "FAIL PERMISSIONS .*write-all" 1 "$(printf '%s\n' "$GOOD_WF" | sed 's/^  contents: read$//' | sed 's/^permissions:$/permissions: write-all/')"
wf_case stored-credential "FAIL CREDENTIALS .*STAGING_KUBECONFIG" 1 "$GOOD_WF
        env:
          KUBECONFIG_DATA: \${{ secrets.STAGING_KUBECONFIG }}"
wf_case smoke-by-plain-pytest "FAIL RERUN .*pytest called directly" 1 "$GOOD_WF
      - run: pytest tests/e2e -m smoke -v"
wf_case unit-pytest-is-not-flagged ": 0 FAIL" 0 "$GOOD_WF
      - run: uv run pytest tests/unit"
wf_case sweep "FAIL SWEEP" 1 "$GOOD_WF
      - run: kind delete clusters --all"
wf_case upload-skipped-on-failure "WARN NOALWAYS" 0 "$(printf '%s\n' "$GOOD_WF" | grep -v 'always()' | sed 's/^        uses: actions.upload/      - uses: actions\/upload/')"
mkdir -p "$TMP/other-wf/.github/workflows"
printf 'on:\n  pull_request:\njobs:\n  ci:\n    steps:\n      - run: make ci\n' > "$TMP/other-wf/.github/workflows/ci.yml"
check "a workflow that does not run the suite is not read" 2 "nothing was checked" "$TMP/other-wf"

# The shipped scripts, templates and examples must satisfy the validator.
python3 -I - "$SKILL" "$TMP/shipped" <<'PY'
import os, re, shutil, sys
skill, out = sys.argv[1:]
count = 0
for folder in ("templates", "examples"):
    for name in sorted(os.listdir(os.path.join(skill, folder))):
        text = open(os.path.join(skill, folder, name), encoding="utf-8").read()
        for path, lang, body in re.findall(r"^#{2,4} `([\w./-]+)`\n\n```(python|yaml|makefile|bash|text)\n(.*?)^```", text, re.M | re.S):
            target = os.path.join(out, name[:-3], path)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w", encoding="utf-8").write(body)
            count += 1
assert count > 20, f"only {count} shipped blocks extracted"
for product in os.listdir(out):
    target = os.path.join(out, product, "tests", "e2e")
    os.makedirs(target, exist_ok=True)
    for script in ("run-e2e-environment.sh", "run-python-e2e-suite.sh"):
        shutil.copy(os.path.join(skill, "scripts", script), os.path.join(target, script))
PY
check "shipped scripts, templates and examples are clean" 0 ": 0 FAIL, 0 WARN" "$TMP/shipped"
if grep -qE "checked [1-9][0-9]+ Python file\(s\), 0 pytest settings file\(s\), [1-9][0-9]* script\(s\), [1-9] Makefile\(s\), 1 workflow\(s\)" <<<"$OUT"; then
  echo "PASS: the shipped Python files, scripts, Makefile and workflow were all read"; else echo "FAIL: shipped coverage"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-python-e2e-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
