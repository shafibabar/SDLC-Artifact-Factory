#!/bin/bash
# Drift test for python-chaos-test's copies of what go-chaos-test owns. Needs no
# Docker, pytest, Go or cluster. A product with Go and Python services runs one
# chaos suite with one runner, so the copies must never drift: change both together.
#   runner      run-chaos-experiment.sh: everything from `set -uo pipefail` down
#   validator   the block of validate-python-chaos-tests.sh from "manifests" to
#               "experiments" is go-chaos-test's validator block, byte for byte
#   verbatim    references/chaos-mesh-on-kind.md
#   line rule   references/experiment-method.md, templates/chaos-statement.md,
#               templates/chaos-mesh-manifests.md, templates/chaos-experiment-report.md:
#               the same lines, except a line whose Go original names Go
#   sections    references/where-it-runs.md: four sections word for word
#   blocks      the shared code blocks of experiment-definition.md and toxiproxy-setup.md
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
GO="$REPO_ROOT/skills/go-chaos-test"
PY="$REPO_ROOT/skills/python-chaos-test"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# check <description> <mode> <python file> <go file> [names...]; mode: program|block|verbatim|lines|sections|blocks
check() {
  python3 -I - "$@" <<'PY'
import re, sys
mode, py_path, go_path, names = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]
py, go = (open(p, encoding="utf-8").read() for p in (py_path, go_path))
def program(t):
    return t[t.index("\nset -uo pipefail\n"):]
def block(t):
    return t[t.index("# ---------------------------------------------------------- manifests"):
             t.index("# ---------------------------------------------------------- experiments")]
def section(t, name):
    m = re.search(r"^## " + re.escape(name) + r"\n.*?(?=^## |\Z)", t, re.S | re.M)
    return m.group(0) if m else None
def blocks(t):
    return dict(re.findall(r"^#{2,4} `([\w./-]+)`\n\n(?:[^\n`][^\n]*\n)*```\w+\n(.*?)^```", t, re.M | re.S))
ok, why = True, ""
try:
    if mode == "program":
        ok = program(py) == program(go)
    elif mode == "block":
        ok = block(py) == block(go)
    elif mode == "verbatim":
        ok = py == go
    elif mode == "lines":
        a, b = py.splitlines(), go.splitlines()
        bad = [i + 1 for i, (x, y) in enumerate(zip(a, b)) if x != y and not re.search(r"\bGo\b|go test|go-test", y)]
        ok = len(a) == len(b) and not bad
        why = f"line count {len(a)} vs {len(b)}; lines differing without naming Go: {bad[:5]}"
    elif mode == "sections":
        bad = [n for n in names if section(py, n) is None or section(py, n) != section(go, n)]
        ok, why = not bad, f"differs or missing: {bad}"
    elif mode == "blocks":
        a, b = blocks(py), blocks(go)
        bad = [n for n in names if n not in a or n not in b or a[n] != b[n]]
        ok, why = not bad, f"differs or missing: {bad}"
except ValueError as exc:
    ok, why = False, str(exc)
if not ok and why:
    print("  " + why)
sys.exit(0 if ok else 1)
PY
}
expect_same() {
  local name="$1"; shift
  if check "$@"; then echo "PASS: $name"; else echo "FAIL: $name: change both skills together"; FAILURES=$((FAILURES + 1)); fi
}
expect_differs() {
  local name="$1"; shift
  if check "$@" > /dev/null; then echo "FAIL: $name was not caught"; FAILURES=$((FAILURES + 1)); else echo "PASS: $name is caught"; fi
}

expect_same "run-chaos-experiment.sh is the same program" x program "$PY/scripts/run-chaos-experiment.sh" "$GO/scripts/run-chaos-experiment.sh"
expect_same "the validators' shared block is identical" x block "$PY/scripts/validate-python-chaos-tests.sh" "$GO/scripts/validate-go-chaos-tests.sh"
expect_same "chaos-mesh-on-kind.md is identical" x verbatim "$PY/references/chaos-mesh-on-kind.md" "$GO/references/chaos-mesh-on-kind.md"
for f in references/experiment-method.md templates/chaos-statement.md templates/chaos-mesh-manifests.md templates/chaos-experiment-report.md; do
  expect_same "$f differs only where Go is named" x lines "$PY/$f" "$GO/$f"
done
expect_same "where-it-runs.md shared sections" x sections "$PY/references/where-it-runs.md" "$GO/references/where-it-runs.md" \
  "The danger" "The privileged injector" "When experiments run" "Credentials, data and cost"
expect_same "experiment-definition.md shared definitions" x blocks "$PY/templates/experiment-definition.md" "$GO/templates/experiment-definition.md" \
  tests/chaos/experiments/degrade-on-tides-latency.json tests/chaos/experiments/pod-kill-harbour.json tests/chaos/experiments/network-partition-tides.json
expect_same "toxiproxy-setup.md shared chart" x blocks "$PY/templates/toxiproxy-setup.md" "$GO/templates/toxiproxy-setup.md" \
  tests/chaos/charts/toxiproxy/Chart.yaml tests/chaos/charts/toxiproxy/values.yaml tests/chaos/charts/toxiproxy/templates/all.yaml
if [[ "$(head -n 1 "$PY/scripts/run-chaos-experiment.sh")" == '#!/bin/bash' ]] && grep -q "python-chaos-test's copy" "$PY/scripts/run-chaos-experiment.sh"; then
  echo "PASS: the runner copy's header says whose copy it is"
else echo "FAIL: header of the runner copy"; FAILURES=$((FAILURES + 1)); fi

# The test must be able to fail: an altered copy of each kind is caught.
alter() {
  python3 -I -c 'import sys; t = open(sys.argv[1]).read(); assert sys.argv[2] in t; open(sys.argv[3], "w").write(t.replace(sys.argv[2], sys.argv[4], 1))' "$@" \
    || { echo "FAIL: the alteration '$2' could not be made in $1"; FAILURES=$((FAILURES + 1)); }
}
alter "$PY/scripts/run-chaos-experiment.sh" 'pytest collected no test (exit 5)' "$TMP/runner.sh" 'pytest collected no tests (exit 5)'
expect_differs "an altered runner copy" x program "$TMP/runner.sh" "$GO/scripts/run-chaos-experiment.sh"
alter "$PY/scripts/validate-python-chaos-tests.sh" 'chaos-mesh-2\.8\.8\.tgz' "$TMP/validator.sh" 'chaos-mesh-2\.8\.\d\.tgz'
expect_differs "an altered validator block" x block "$TMP/validator.sh" "$GO/scripts/validate-go-chaos-tests.sh"
alter "$PY/references/experiment-method.md" "0.9 over 10 s" "$TMP/method.md" "0.5 over 10 s"
expect_differs "an altered method line" x lines "$TMP/method.md" "$GO/references/experiment-method.md"
alter "$PY/references/where-it-runs.md" 'host PID' "$TMP/where.md" 'host network'
expect_differs "an altered shared section" x sections "$TMP/where.md" "$GO/references/where-it-runs.md" "The privileged injector"
alter "$PY/templates/toxiproxy-setup.md" 'apiNodePort: 30474' "$TMP/toxi.md" 'apiNodePort: 30475'
expect_differs "an altered chart block" x blocks "$TMP/toxi.md" "$GO/templates/toxiproxy-setup.md" tests/chaos/charts/toxiproxy/values.yaml

if [[ $FAILURES -eq 0 ]]; then echo "PASS: python-chaos-copies"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
