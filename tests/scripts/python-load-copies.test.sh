#!/bin/bash
# Drift test for python-load-test's copies of what go-load-test owns. Needs no
# k6, Docker or cluster. Each skill keeps its own copy under its own folder:
#   scripts  run-load-test.sh, write-load-report.sh, and validate-go-load-tests.sh
#            (validate-python-load-tests.sh here): everything from
#            `set -uo pipefail` down must be the same program
#   blocks   the k6 files (lib/gate.js and the seven test-type scripts), the
#            designation record, issue-subjects.sh, the impact statement, the
#            indicative suite lines, load-e2e.conf and load-verdict.yml must be
#            byte for byte the same in both skills' templates
# A product with Go and Python services runs one load suite, so the two must
# never drift: change both together.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
GO="$REPO_ROOT/skills/go-load-test"
PY="$REPO_ROOT/skills/python-load-test"
FAILURES=0

# same_program <python copy> <go copy>
same_program() {
  if python3 -I - "$1" "$2" <<'PY'
import sys
def program(path):
    text = open(path, encoding="utf-8").read()
    return text[text.index("\nset -uo pipefail\n"):]
sys.exit(0 if program(sys.argv[1]) == program(sys.argv[2]) else 1)
PY
  then echo "PASS: $(basename "$1") is the same program as go-load-test's $(basename "$2")"
  else echo "FAIL: $(basename "$1") differs from go-load-test's $(basename "$2"); change both together"; FAILURES=$((FAILURES + 1)); fi
}
same_program "$PY/scripts/run-load-test.sh" "$GO/scripts/run-load-test.sh"
same_program "$PY/scripts/write-load-report.sh" "$GO/scripts/write-load-report.sh"
same_program "$PY/scripts/validate-python-load-tests.sh" "$GO/scripts/validate-go-load-tests.sh"

for copy in run-load-test.sh write-load-report.sh validate-python-load-tests.sh; do
  if [[ "$(head -n 1 "$PY/scripts/$copy")" == '#!/bin/bash' ]] && grep -q "python-load-test's copy" "$PY/scripts/$copy"; then
    echo "PASS: the header of $copy says whose copy it is"
  else echo "FAIL: header of $copy"; FAILURES=$((FAILURES + 1)); fi
done

# same_blocks <template file name> <published path>...
same_blocks() {
  local file="$1"; shift
  if python3 -I - "$PY/templates/$file" "$GO/templates/$file" "$@" <<'PY'
import re, sys
def blocks(path):
    text = open(path, encoding="utf-8").read()
    return {p: body for p, body in re.findall(r"^#{2,4} `([\w./-]+)`\n\n```\w+\n(.*?)^```", text, re.M | re.S)}
py, go = blocks(sys.argv[1]), blocks(sys.argv[2])
bad = [p for p in sys.argv[3:] if p not in py or p not in go or py[p] != go[p]]
for p in bad:
    print(f"  differs or missing: {p}")
sys.exit(1 if bad else 0)
PY
  then echo "PASS: templates/$file: $# shared block(s) identical"
  else echo "FAIL: templates/$file: shared blocks differ from go-load-test's; change both together"; FAILURES=$((FAILURES + 1)); fi
}
same_blocks k6-scripts.md tests/load/lib/gate.js tests/load/smoke.js tests/load/average-load.js tests/load/overload.js \
  tests/load/stress.js tests/load/soak.js tests/load/spike.js tests/load/breakpoint.js
same_blocks designation-record.md tests/load/designation.json tests/load/issue-subjects.sh \
  tests/load/statements/verify-lockers-staging-2026-12.json
same_blocks make-targets.md tests/load/indicative-suites.conf tests/load/load-e2e.conf
same_blocks workflows.md .github/workflows/load-verdict.yml

# The test must be able to fail: an altered copy of each kind is caught.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$PY/scripts/run-load-test.sh" "$TMP/run-load-test.sh"
printf '# drift\n' >> "$TMP/run-load-test.sh"
if python3 -I - "$TMP/run-load-test.sh" "$GO/scripts/run-load-test.sh" <<'PY'
import sys
program = lambda p: (lambda t: t[t.index("\nset -uo pipefail\n"):])(open(p, encoding="utf-8").read())
sys.exit(0 if program(sys.argv[1]) == program(sys.argv[2]) else 1)
PY
then echo "FAIL: an altered runner copy was not caught"; FAILURES=$((FAILURES + 1)); else echo "PASS: an altered runner copy is caught"; fi
python3 -I - "$PY/templates/k6-scripts.md" "$TMP/k6-scripts.md" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write(text.replace("dropped_iterations: ['count==0'],", "dropped_iterations: ['count<10'],", 1))
PY
if python3 -I - "$TMP/k6-scripts.md" "$GO/templates/k6-scripts.md" <<'PY'
import re, sys
blocks = lambda p: dict(re.findall(r"^#{2,4} `([\w./-]+)`\n\n```\w+\n(.*?)^```", open(p, encoding="utf-8").read(), re.M | re.S))
a, b = blocks(sys.argv[1]), blocks(sys.argv[2])
sys.exit(0 if all(a[k] == b[k] for k in ("tests/load/lib/gate.js", "tests/load/overload.js", "tests/load/breakpoint.js")) else 1)
PY
then echo "FAIL: an altered k6 block was not caught"; FAILURES=$((FAILURES + 1)); else echo "PASS: an altered k6 block is caught"; fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: python-load-copies"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
