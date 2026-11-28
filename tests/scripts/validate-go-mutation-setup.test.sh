#!/bin/bash
# Synthetic-input test for go-mutation-test's setup validator: a clean product
# passes, and each defect found in go-mutation-test 2.2.0, or forbidden by the
# product owner's mutation decisions (D048, 2026-11-28), is flagged.
# Needs no Go and no Gremlins.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-mutation-test/scripts/validate-go-mutation-setup.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

python3 -I - "$TMP/clean" <<'PY'
import os, sys
root = sys.argv[1]
def put(path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)
mutants = "".join(f"  {m}:\n    enabled: true\n" for m in (
    "arithmetic-base", "conditionals-boundary", "conditionals-negation", "increment-decrement",
    "invert-assignments", "invert-bitwise", "invert-bwassign", "invert-logical", "invert-loopctrl",
    "invert-negatives", "remove-self-assignments"))
put("go.mod", "module example.com/kilnworks\n\ngo 1.27\n")
put(".gitignore", "mutation-out/\n")
put(".gremlins.yaml", "# settings\nunleash:\n  threshold:\n    efficacy: 0\n    mutant-coverage: 0\n"
    "  timeout-coefficient: 10\n  exclude-files:\n    - \"^internal/test/\"\n    - \"_moq\\\\.go$\"\nmutants:\n" + mutants)
put("internal/firing/schedule.go", "package firing\n\nfunc Next(a int) int { return a + 1 }\n")
put("internal/firing/port_moq.go", "package firing\n")
put("internal/test/kilns/kilns.go", "package kilns\n")
put("internal/legacy/importer.go", "package legacy\n")
put("scripts/run-go-mutation.sh", "#!/bin/bash\n")
put("scripts/check-go-mutation.sh", "#!/bin/bash\n")
put("mutation/mutant-record.txt", "# record\ninternal/firing/schedule.go:3:32 | ARITHMETIC_BASE | equivalent | 0123456789ab | "
    "no caller can observe the difference at this boundary | test-strategist 2026-11-28\n")
put("mutation/exclusions.txt", "# exclusions\n")
put("Makefile", """GREMLINS_VERSION := v0.6.0

mutation-tools:
\tgo install github.com/go-gremlins/gremlins/cmd/gremlins@$(GREMLINS_VERSION)

mutation:
\t./scripts/run-go-mutation.sh --gremlins-version $(GREMLINS_VERSION) .
\t./scripts/check-go-mutation.sh --mode release --commit "$$(git rev-parse HEAD)" --record mutation/mutant-record.txt .

mutation-changed:
\t./scripts/run-go-mutation.sh --diff "$$(git describe --tags --abbrev=0)" .
\t./scripts/check-go-mutation.sh --mode scheduled --commit "$$(git rev-parse HEAD)" .
""")
put(".github/workflows/mutation.yml", """name: mutation
on:
  schedule:
    - cron: "41 3 1 * *"
  workflow_dispatch:
  workflow_call:
    inputs:
      scope:
        type: string
        default: full
jobs:
  mutation:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0
      - run: make mutation-tools
      - if: ${{ inputs.scope == 'full' }}
        run: make mutation
      - if: ${{ inputs.scope != 'full' }}
        run: make mutation-changed
""")
put(".github/workflows/release.yml", """name: release
on:
  push:
    tags: ["v*"]
jobs:
  mutation:
    uses: ./.github/workflows/mutation.yml
    with:
      scope: full
  publish:
    needs: [mutation]
    runs-on: ubuntu-26.04
    steps:
      - run: echo publish
""")
PY

# case <name> <expected exit> <regex> <python that breaks a copy of the clean product>
case_() {
  local name="$1" want="$2" pattern="$3" change="$4"
  rm -rf "$TMP/p"
  cp -R "$TMP/clean" "$TMP/p"
  python3 -I - "$TMP/p" "$change" <<'PY'
import os, sys
root, change = sys.argv[1], sys.argv[2]
def put(path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)
def edit(path, old, new):
    full = os.path.join(root, path)
    text = open(full).read()
    assert old in text, (path, old)
    open(full, "w").write(text.replace(old, new))
exec(change)
PY
  local out code
  out="$(/bin/bash "$SCRIPT" "$TMP/p" 2>&1)"
  code=$?
  if [ "$code" -eq "$want" ] && grep -E -e "$pattern" > /dev/null <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $code, want $want; pattern '$pattern')"
    printf '%s\n' "$out" | sed 's/^/    /' | head -10
    FAILURES=$((FAILURES + 1))
  fi
}

case_ "clean product" 0 "^0 FAIL, 0 WARN$" "pass"
case_ "flat threshold-efficacy key (2.2.0)" 1 "'unleash.threshold-efficacy' is not a Gremlins v0.6.0 setting" \
  "edit('.gremlins.yaml', '  timeout-coefficient: 10\n', '  timeout-coefficient: 10\n  threshold-efficacy: 60\n')"
case_ "excludes list (2.2.0)" 1 "'excludes' is not a Gremlins v0.6.0 setting" \
  "edit('.gremlins.yaml', 'mutants:\n', 'excludes:\n  - internal/firing/schedule.go:3\nmutants:\n')"
case_ "a percentage threshold" 1 "unleash.threshold.efficacy is 60: keep it 0" \
  "edit('.gremlins.yaml', 'efficacy: 0', 'efficacy: 60')"
case_ "threshold of 100" 1 "unleash.threshold.mutant-coverage is 100" \
  "edit('.gremlins.yaml', 'mutant-coverage: 0', 'mutant-coverage: 100')"
case_ "a mutant type left off" 1 "enable every mutant type .*: invert-loopctrl" \
  "edit('.gremlins.yaml', '  invert-loopctrl:\n    enabled: true\n', '')"
case_ "test-cpu" 1 "test-cpu makes Gremlins pass '-cpu N' as one argument" \
  "edit('.gremlins.yaml', '  timeout-coefficient: 10\n', '  timeout-coefficient: 10\n  test-cpu: 2\n')"
case_ "dry-run in the file" 1 "unleash.dry-run is set" \
  "edit('.gremlins.yaml', '  timeout-coefficient: 10\n', '  timeout-coefficient: 10\n  dry-run: true\n')"
case_ "diff in the file" 1 "unleash.diff is set: the release run covers everything" \
  "edit('.gremlins.yaml', '  timeout-coefficient: 10\n', '  timeout-coefficient: 10\n  diff: main\n')"
case_ "a package excluded without approval" 1 "leaves out internal/legacy/importer.go without an exclusion" \
  "edit('.gremlins.yaml', '    - \"^internal/test/\"\n', '    - \"^internal/test/\"\n    - \"^internal/legacy/\"\n')"
case_ "a package excluded with approval" 0 "^0 FAIL" \
  "edit('.gremlins.yaml', '    - \"^internal/test/\"\n', '    - \"^internal/test/\"\n    - \"^internal/legacy/\"\n'); put('mutation/exclusions.txt', 'internal/legacy/ | approved 2026-11-20 | frozen importer, retired next quarter\n')"
case_ "a package excluded while pending" 1 "leaves out internal/legacy/importer.go before the product owner approved it" \
  "edit('.gremlins.yaml', '    - \"^internal/test/\"\n', '    - \"^internal/test/\"\n    - \"^internal/legacy/\"\n'); put('mutation/exclusions.txt', 'internal/legacy/ | pending | frozen importer, retired next quarter\n')"
case_ "a generated file excluded by pattern" 0 "^0 FAIL" \
  "put('internal/firing/models.go', '// Code generated by sqlc. DO NOT EDIT.\n\npackage firing\n'); edit('.gremlins.yaml', '    - \"^internal/test/\"\n', '    - \"^internal/test/\"\n    - \"models\\\\\\\\.go$\"\n')"
case_ "a suppression comment (2.2.0)" 1 "schedule.go:3: Gremlins has no suppression comment" \
  "edit('internal/firing/schedule.go', 'func Next', '//gremlins:disable-next-line\nfunc Next')"
case_ "Gremlins @latest (2.2.0)" 1 "Gremlins installed as @latest" \
  "edit('Makefile', '@\$(GREMLINS_VERSION)', '@latest')"
case_ "an unpinned version variable" 1 "GREMLINS_VERSION is latest" \
  "edit('Makefile', 'GREMLINS_VERSION := v0.6.0', 'GREMLINS_VERSION := latest')"
case_ "Gremlins run directly (2.2.0)" 1 "Makefile:[0-9]+: Gremlins run directly" \
  "edit('Makefile', 'mutation-changed:\n', 'mutation-quick:\n\tgremlins unleash ./internal/domain/... ./internal/application/...\n\nmutation-changed:\n')"
case_ "a CLI threshold" 1 "mutation.yml:[0-9]+: Gremlins thresholds and --test-cpu are not used" \
  "edit('.github/workflows/mutation.yml', 'run: make mutation\n', 'run: make mutation ARGS=--threshold-efficacy=60\n')"
case_ "a percentage gate in a workflow" 1 "a percentage on a mutation line" \
  "edit('.github/workflows/mutation.yml', 'run: make mutation\n', 'run: make mutation # fails under 60% mutation score\n')"
case_ "a masked exit status" 1 "the exit status is masked" \
  "edit('.github/workflows/mutation.yml', 'run: make mutation\n', 'run: make mutation || true\n')"
case_ "release: published (2.2.0)" 1 "mutation.yml: a release trigger fires after the release is published" \
  "edit('.github/workflows/mutation.yml', '  workflow_dispatch:\n', '  workflow_dispatch:\n  release:\n    types: [published]\n')"
case_ "no schedule" 1 "no schedule: a scheduled run between releases" \
  "edit('.github/workflows/mutation.yml', '  schedule:\n    - cron: \"41 3 1 * *\"\n', '')"
case_ "less often than monthly" 1 "cron '41 3 1 \*/3 \*' runs less often than monthly" \
  "edit('.github/workflows/mutation.yml', '41 3 1 * *', '41 3 1 */3 *')"
case_ "weekly is allowed" 0 "^0 FAIL" \
  "edit('.github/workflows/mutation.yml', '41 3 1 * *', '41 3 * * 1')"
case_ "no workflow_call" 1 "no workflow_call" \
  "edit('.github/workflows/mutation.yml', '  workflow_call:\n    inputs:\n      scope:\n        type: string\n        default: full\n', '')"
case_ "publish does not wait for mutation" 1 "no publishing workflow runs the mutation workflow as a job its publish job needs" \
  "edit('.github/workflows/release.yml', 'needs: [mutation]', 'needs: [build]')"
case_ "continue-on-error" 1 "continue-on-error hides an INVALID run" \
  "edit('.github/workflows/mutation.yml', '    runs-on: ubuntu-26.04\n', '    runs-on: ubuntu-26.04\n    continue-on-error: true\n')"
case_ "pull request trigger warns" 0 "WARN: .*runs on pull requests" \
  "edit('.github/workflows/mutation.yml', '  workflow_dispatch:\n', '  workflow_dispatch:\n  pull_request:\n')"
case_ "shallow checkout warns" 0 "WARN: .*fetch-depth: 0" \
  "edit('.github/workflows/mutation.yml', '        with:\n          fetch-depth: 0\n', '')"
case_ "low timeout coefficient warns" 0 "WARN: .*timeout-coefficient under 10" \
  "edit('.gremlins.yaml', '  timeout-coefficient: 10\n', '')"
case_ "make mutation using --diff" 1 "make mutation uses --diff" \
  "edit('Makefile', '--gremlins-version \$(GREMLINS_VERSION) .', '--gremlins-version \$(GREMLINS_VERSION) --diff main .')"
case_ "make mutation not judged as a release" 1 "make mutation must run scripts/run-go-mutation.sh, then scripts/check-go-mutation.sh --mode release" \
  "edit('Makefile', '--mode release --commit', '--mode scheduled --commit')"
case_ "no make mutation" 1 "no mutation target" \
  "edit('Makefile', 'mutation:\n', 'mutation-full:\n')"
case_ "a malformed record line" 1 "mutant-record.txt:2: write <file>:<line>:<col>" \
  "edit('mutation/mutant-record.txt', '0123456789ab', 'TODO')"
case_ "a record without a reason" 1 "mutant-record.txt:2" \
  "edit('mutation/mutant-record.txt', 'no caller can observe the difference at this boundary', '<the reason, after checking>')"
case_ "runner not copied" 1 "scripts/run-go-mutation.sh: missing" \
  "os.remove(os.path.join(root, 'scripts/run-go-mutation.sh'))"
case_ "no config" 1 ".gremlins.yaml: missing" \
  "os.remove(os.path.join(root, '.gremlins.yaml'))"
case_ "run output not ignored warns" 0 "WARN: .gitignore" \
  "put('.gitignore', 'bin/\n')"
out="$(/bin/bash "$SCRIPT" "$TMP/none" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: usage"; else echo "FAIL: usage (exit $code)"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-go-mutation-setup"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
