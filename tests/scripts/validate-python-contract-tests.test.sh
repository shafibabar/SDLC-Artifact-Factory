#!/bin/bash
# Synthetic-input test for python-contract-test's validator. It reads text
# only, so neither Python packages nor Docker are needed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-contract-test/scripts/validate-python-contract-tests.sh"
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

# one <name> <relative file> <pattern> <expected exit> <content>: a single offending file
one() {
  local name="$1" file="$2" pattern="$3" want="$4" body="$5"
  mkdir -p "$TMP/$name/$(dirname "$file")"
  printf '%s\n' "$body" > "$TMP/$name/$file"
  check "$name" "$want" "$pattern" "$TMP/$name"
}

check "no arguments is a usage error" 2 "usage"
check "missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty" && echo "notes" > "$TMP/empty/readme.txt"
check "nothing to check" 2 "nothing was checked" "$TMP/empty"

# A project with nothing wrong: every rule below is this tree with one change.
GOOD="$TMP/good"
mkdir -p "$GOOD/pact_tests/consumer" "$GOOD/pact_tests/provider" "$GOOD/tests/contract" "$GOOD/.github/workflows" "$GOOD/.venv/lib"
cat > "$GOOD/pact_tests/conftest.py" <<'PYF'
import pytest

def pytest_collection_modifyitems(items):
    for item in items:
        item.add_marker(pytest.mark.pact)
PYF
cat > "$GOOD/pact_tests/consumer/test_rentals_plots_pact.py" <<'PYF'
"""Never from pact.v2 import Consumer; never latest=True (text in a docstring is not code)."""
from pact import Pact, match

# .add_custom_header("Authorization", "x") in a comment is not code
async def test_reads(pact):
    with pact.serve() as mock:
        pass
    pact.write_file("pacts")
PYF
cat > "$GOOD/pact_tests/provider/test_plots_provider_pact.py" <<'PYF'
from pact import Verifier

def test_verify():
    verifier = (
        Verifier("plots", host="127.0.0.1")
        .state_handler(provider_state, teardown=True)
        .set_error_on_empty_pact()
        .broker_source("http://broker", selector=True)
        .consumer_version(main_branch=True)
        .include_pending()
        .build()
    )
PYF
cat > "$GOOD/tests/contract/events.py" <<'PYF'
from jsonschema import Draft202012Validator

def check(schema, data):
    Draft202012Validator(schema, format_checker=Draft202012Validator.FORMAT_CHECKER).validate(data)
PYF
cat > "$GOOD/tests/contract/test_client.py" <<'PYF'
import httpx, respx

async def test_client():
    router = respx.Router(assert_all_called=True)
    async with httpx.AsyncClient(transport=httpx.MockTransport(router.async_handler)) as http:
        pass
PYF
cat > "$GOOD/pyproject.toml" <<'TOML'
[tool.pytest.ini_options]
testpaths = ["tests"]
markers = [
    "integration: needs a real database or broker",
    "pact: Pact consumer or provider test; daily run only",
]
TOML
cat > "$GOOD/Makefile" <<'MK'
ci: install lint typecheck test freshness

test: ## the full suite
	uv run bash scripts/check-python-coverage.sh --source src

api-gate:
	bash scripts/check-openapi-breaking.sh --base deployed.yaml --revision api/openapi.yaml

pact-consumer:
	uv run pytest pact_tests/consumer -m pact
MK
cat > "$GOOD/.github/workflows/pact-daily.yml" <<'YML'
name: pact-daily
on:
  schedule:
    - cron: "23 3 * * *"
  workflow_dispatch:
jobs:
  pact:
    runs-on: ubuntu-24.04
    steps:
      - run: make pact-consumer
      - run: uv run pact broker publish pacts --consumer-app-version "$GIT_SHA" --branch "$GIT_BRANCH"
YML
cat > "$GOOD/.github/workflows/contract-gates.yml" <<'YML'
name: contract-gates
on:
  pull_request:
jobs:
  gates:
    runs-on: ubuntu-24.04
    steps:
      - run: make contract-gates
YML
cat > "$GOOD/deploy.sh" <<'SH'
#!/bin/bash
# never: can-i-deploy --dry-run
pact broker can-i-deploy --pacticipant plots --version "$GIT_SHA" --to-environment production
SH
# Skipped folders are not read.
echo 'from pact.v2 import Consumer' > "$GOOD/.venv/lib/old.py"
check "a clean project passes" 0 "checked [0-9]+ file\(s\): 0 FAIL, 0 WARN" "$GOOD"

# variant <name> <relative file> <python expression on text t>: the clean tree with one file changed
variant() {
  rm -rf "$TMP/$1" && cp -R "$GOOD" "$TMP/$1"
  python3 -I - "$TMP/$1/$2" "$3" <<'PY'
import sys
path, code = sys.argv[1:]
t = open(path, encoding="utf-8").read()
new = eval(code)
assert new != t, "the change did nothing"
open(path, "w", encoding="utf-8").write(new)
PY
}
PROVIDER=pact_tests/provider/test_plots_provider_pact.py
CONSUMER=pact_tests/consumer/test_rentals_plots_pact.py

variant latest "$PROVIDER" 't.replace("main_branch=True", "latest=True")'
check "latest=True selector" 1 "FAIL LATEST .*test_plots_provider_pact.py:9" "$TMP/latest"
variant nopacts "$PROVIDER" 't.replace("set_error_on_empty_pact()", "set_error_on_empty_pact(enabled=False)")'
check "zero pacts allowed" 1 "FAIL NOPACTS" "$TMP/nopacts"
variant nopacts-unstated "$PROVIDER" 't.replace("        .set_error_on_empty_pact()\n", "")'
check "zero-pact setting not stated is a warning" 0 "WARN NOPACTS" "$TMP/nopacts-unstated"
variant pending "$PROVIDER" 't.replace("        .include_pending()\n", "")'
check "no pending is a warning" 0 "WARN PENDING" "$TMP/pending"
variant customheader "$PROVIDER" 't.replace(".set_error_on_empty_pact()", ".set_error_on_empty_pact()\n        .add_custom_header(\"Authorization\", token)")'
check "token through add_custom_header" 1 "FAIL CUSTOMHEADER" "$TMP/customheader"
variant customheaders "$PROVIDER" 't.replace(".set_error_on_empty_pact()", ".set_error_on_empty_pact()\n        .add_custom_headers({\"authorization\": token})")'
check "token through add_custom_headers" 1 "FAIL CUSTOMHEADER" "$TMP/customheaders"
variant otherheader "$PROVIDER" 't.replace(".set_error_on_empty_pact()", ".set_error_on_empty_pact()\n        .add_custom_header(\"X-Request-Id\", \"1\")")'
check "another custom header is not flagged" 0 "0 FAIL" "$TMP/otherheader"
variant stateguard "$PROVIDER" 't.replace(", teardown=True", "")'
check "state handler without teardown is a warning" 0 "WARN STATEGUARD" "$TMP/stateguard"
variant messagepact "$CONSUMER" 't + "\npact.upon_receiving(\"a trip ended\", \"Async\")\n"'
check "message pact on the consumer" 1 "FAIL MESSAGEPACT" "$TMP/messagepact"
variant messagehandler "$PROVIDER" 't.replace(".include_pending()", ".include_pending()\n        .message_handler(produce)")'
check "message pact on the provider" 1 "FAIL MESSAGEPACT" "$TMP/messagehandler"
variant oldapi "$CONSUMER" 't.replace("from pact import Pact, match", "from pact.v2 import Consumer, Provider")'
check "pact.v2 import" 1 "FAIL OLDAPI" "$TMP/oldapi"
variant nowrite "$CONSUMER" 't.replace("    pact.write_file(\"pacts\")\n", "")'
check "pact file never written is a warning" 0 "WARN NOWRITE" "$TMP/nowrite"
variant nomarker pact_tests/conftest.py 't.replace("item.add_marker(pytest.mark.pact)", "pass")'
check "Pact tests without the marker" 1 "FAIL NOMARKER .*test_rentals_plots_pact.py" "$TMP/nomarker"
variant unregistered pyproject.toml 't.replace("    \"pact: Pact consumer or provider test; daily run only\",\n", "")'
check "pact marker not registered" 1 "FAIL UNREGISTERED" "$TMP/unregistered"
variant addopts pyproject.toml 't.replace("testpaths = [\"tests\"]", "testpaths = [\"tests\"]\naddopts = \"-m \\\"not pact\\\"\"")'
check "selection in addopts" 1 "FAIL ADDOPTS" "$TMP/addopts"

rm -rf "$TMP/misplaced" && cp -R "$GOOD" "$TMP/misplaced" && cp "$GOOD/$CONSUMER" "$TMP/misplaced/tests/contract/test_pact_here.py"
check "Pact test under tests/" 1 "FAIL PACTPLACE .*tests/contract/test_pact_here.py" "$TMP/misplaced"

variant format tests/contract/events.py 't.replace(", format_checker=Draft202012Validator.FORMAT_CHECKER", "")'
check "validator without a format checker" 1 "FAIL FORMAT" "$TMP/format"
variant appshortcut tests/contract/test_client.py 't.replace("transport=httpx.MockTransport(router.async_handler)", "app=app")'
check "httpx app= shortcut" 1 "FAIL APPSHORTCUT" "$TMP/appshortcut"
variant providerapp tests/contract/test_client.py 't + "\ntransport = httpx.ASGITransport(app=provider_app)\n"'
check "consumer test driving an app in-process is a warning" 0 "WARN PROVIDERAPP" "$TMP/providerapp"
variant uncalled tests/contract/test_client.py 't.replace("async def test_client():", "async def test_client(respx_mock):").replace("assert_all_called=True", "")'
check "bare respx_mock fixture is a warning" 0 "WARN UNCALLED" "$TMP/uncalled"
variant forbid tests/contract/test_client.py 't + "\nmodel_config = ConfigDict(extra=\"forbid\")\n"'
check "model rejecting unknown fields is a warning" 0 "WARN UNKNOWNFIELDS" "$TMP/forbid"
variant ownchecker tests/contract/events.py 't + "\ndef assert_backward_compatible(old, new):\n    pass\n"'
check "hand-written compatibility checker is a warning" 0 "WARN OWNCHECKER" "$TMP/ownchecker"
variant skipped tests/contract/test_client.py 't.replace("async def test_client", "@pytest.mark.skip\nasync def test_client")'
check "skipped contract case is a warning" 0 "WARN SKIPPED" "$TMP/skipped"
variant servedspec tests/contract/test_client.py 't + "\nschema = schemathesis.openapi.from_asgi(\"/openapi.json\", app)\n"'
check "schemathesis reading the served description" 1 "FAIL SERVEDSPEC" "$TMP/servedspec"

variant pactinci Makefile 't.replace("ci: install lint typecheck test freshness", "ci: install lint typecheck test freshness pact-consumer")'
check "ci depends on a Pact target" 1 "FAIL PACTINCI .*Makefile:1" "$TMP/pactinci"
variant pactintest Makefile 't.replace("\tuv run bash scripts/check-python-coverage.sh --source src", "\tuv run bash scripts/check-python-coverage.sh --source src\n\tuv run pytest pact_tests/consumer -m pact")'
check "test target runs Pact" 1 "FAIL PACTINCI" "$TMP/pactintest"
variant contractmarker Makefile 't + "\ncontract:\n\tuv run pytest -m contract tests/contract\n"'
check "the contract marker that selects nothing" 1 "FAIL CONTRACTMARKER" "$TMP/contractmarker"
variant pactonpr .github/workflows/pact-daily.yml 't.replace("  schedule:\n    - cron: \"23 3 * * *\"\n", "  pull_request:\n")'
check "Pact on a pull request" 1 "FAIL PACTONPR" "$TMP/pactonpr"
variant continue .github/workflows/contract-gates.yml 't.replace("      - run: make contract-gates", "      - run: bash scripts/check-openapi-breaking.sh --base a --revision b\n        continue-on-error: true")'
check "continue-on-error beside a gate is a warning" 0 "WARN CONTINUE" "$TMP/continue"

one dryrun deploy.sh "FAIL DRYRUN" 1 'pact broker can-i-deploy --pacticipant plots --version "$GIT_SHA" --to-environment production --dry-run'
one jsonexit deploy.sh "WARN JSONEXIT" 0 'pact broker can-i-deploy --pacticipant plots --version "$GIT_SHA" --to-environment production --output json'
one jsonsaved report.sh "0 FAIL, 0 WARN" 0 'pact broker can-i-deploy --pacticipant plots --version "$GIT_SHA" --to-environment production --output json > "pact-results/plots.production.json" 2>&1'
one nofailon gate.sh "FAIL NOFAILON" 1 'oasdiff breaking deployed.yaml api/openapi.yaml'
one versionbump gate.sh "FAIL VERSIONBUMP" 1 'oasdiff breaking --fail-on MISSING-VERSION-BUMP deployed.yaml api/openapi.yaml'
one ignored gate.sh "FAIL IGNORED" 1 'bash scripts/check-openapi-breaking.sh --base a --revision b || true'
one continued gate.sh "FAIL IGNORED" 1 'oasdiff breaking --fail-on WARN a b \
  || true'
one paid deploy.sh "FAIL PAID" 1 'export PACT_BROKER_BASE_URL=https://acme.pactflow.io'
one oldverifier deploy.sh "FAIL OLDAPI" 1 'pact-verifier --provider plots'
mkdir -p "$TMP/heredoc"
cat > "$TMP/heredoc/tool.sh" <<'OUTER'
#!/bin/bash
python3 - <<'PY'
print("oasdiff breaking a b || true")   # text inside a here-document is another program
print("pactflow.io")
PY
OUTER
check "text inside a here-document is not shell" 0 "0 FAIL, 0 WARN" "$TMP/heredoc"
check "the validator passes over itself and its sibling scripts" 0 "0 FAIL, 0 WARN" "$REPO_ROOT/skills/python-contract-test/scripts"
one commented deploy.sh "0 FAIL, 0 WARN" 0 '# oasdiff breaking a b || true'

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-python-contract-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
