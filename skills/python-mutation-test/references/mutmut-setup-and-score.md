# mutmut Setup, Scoring, and the Periodic CI Gate

Full grounding for `python-mutation-test`'s "Tool Choice", "Mutation-Score Threshold", and "Budget
and Scheduling" sections: the exact mutmut configuration, the run commands, how the mutation score
is computed and gated in CI (the piece Python does not give you for free), the cosmic-ray
alternative, and the scheduled workflow behind the periodic-not-per-PR policy. Self-contained —
restates the targeting rule and the 60% threshold below rather than assuming the parent `SKILL.md`
body is in context.

---

## Why mutmut

Two maintained Python mutation testers matter in practice: **mutmut** and **cosmic-ray**. mutmut
is this repo's default because it is open-source, pytest-native (it drives your existing `pytest`
runner directly), and configured in a single committed `pyproject.toml` block — satisfying the
Budget and Frugality constraint (`CLAUDE.md`) without evaluating a paid alternative. No commercial
mutation-testing SaaS is in scope; if one is ever proposed it requires the same explicit
frugality-constraint approval `python-contract-test` requires before considering a hosted broker
over schema files.

cosmic-ray is the sanctioned alternative for two concrete reasons, both covered below: it
distributes mutant execution across processes/machines (mutmut runs them serially, and Python's
per-run interpreter import makes serial execution the dominant cost), and it ships `cr-rate`, a
metrics command that gates a build on the survival rate directly — closing the native-gate gap
mutmut leaves open.

---

## `[tool.mutmut]` in Full

mutmut (>= 2.5) reads its configuration from the `[tool.mutmut]` table in `pyproject.toml`,
committed at the repo root. Scope, runner, and the tests directory live here — never as ad hoc CLI
flags that bypass the committed configuration.

```toml
# pyproject.toml — committed at repo root.
[tool.mutmut]
# Scope: domain + service_layer ONLY. Adapters and entrypoints are Humble Object
# (verified by python-integration-test against a real dependency), so mutating them
# tests wiring, not logic, and buries the domain-layer survivors that matter.
paths_to_mutate = "src/classification/domain/,src/classification/service_layer/"
tests_dir = "tests/unit/"
# Drive the existing pytest suite; -x stops at the first failure, which is all a
# mutant needs to be declared "killed" — faster than running the whole suite per mutant.
runner = "python -m pytest -x -q"
# Do not leave .bak files strewn through the tree; mutmut restores source itself.
backup = false
```

`paths_to_mutate` is the exact mechanism that enforces the domain/service-layer targeting rule:
adapters (`src/classification/adapters/`) and entrypoints (`src/classification/entrypoints/`) are
simply never listed, so no mutant is ever generated inside them. A new domain module added under
either listed directory is picked up automatically on the next run — the paths are directory
prefixes, not an explicit file list.

**Equivalent-mutant exclusion is inline, not central.** Unlike a Gremlins `excludes:` list, mutmut
excludes an individual mutation with a `# pragma: no mutate` comment on the source line itself,
added during triage step 3's "No" branch with a dated reason:

```python
# src/classification/domain/pagination.py
DEFAULT_PAGE_SIZE = 50  # pragma: no mutate  (constant bump is behaviourally equivalent; the
                        #   value is re-validated at the FastAPI boundary. Triaged 2026-07-31.)
```

---

## Run Commands

```bash
# Generate and test every mutant in the configured scope. Serial by construction.
mutmut run

# List survivors (and every other status). This is what triage reads.
mutmut results

# Show the exact original-vs-mutant diff for one survivor id — triage step 1.
mutmut show 7

# Emit JUnit XML (survived mutants become <failure> entries) for CI to parse.
mutmut junitxml > mutmut-report.xml

# Human-browsable HTML report, uploaded as the scheduled job's build artifact.
mutmut html
```

**The honest gap the score wrapper closes.** `mutmut run`'s own exit code is a bitfield —
non-zero if *any* mutant survived (bit 0), timed out (bit 2), or is suspicious (bit 3). That is
strictly binary: it fails the build on a single survivor and has **no notion of a percentage
threshold**, so it cannot express "60% kill floor with headroom for equivalent mutants." Gremlins,
by contrast, bakes `threshold-efficacy: 60` into `.gremlins.yaml` and fails natively at that
percentage. In Python you compute the score yourself and gate on it — the next section is that
missing piece.

---

## Computing and Gating the Mutation Score (the mutmut Wrapper)

```bash
#!/usr/bin/env bash
# scripts/mutation-gate.sh — computes the mutation score from mutmut's own counts and
# fails the build below the 60% floor. This is the step mutmut does not provide natively.
set -euo pipefail
THRESHOLD=60

mutmut run || true   # non-zero on any survivor; we gate on the PERCENTAGE, not that bit.

# `mutmut results` groups mutant ids by status. Count killed vs survived; equivalents
# carrying `# pragma: no mutate` were never generated, so they are correctly out of the total.
KILLED=$(mutmut results | grep -c '^Killed' || true)
SURVIVED=$(mutmut results | grep -c '^Survived' || true)
TOTAL=$(( KILLED + SURVIVED ))
if [[ "$TOTAL" -eq 0 ]]; then echo "No mutants generated — check paths_to_mutate."; exit 1; fi

SCORE=$(( 100 * KILLED / TOTAL ))
echo "Mutation score: ${SCORE}% (killed ${KILLED} / ${TOTAL}); floor ${THRESHOLD}%"
if [[ "$SCORE" -lt "$THRESHOLD" ]]; then
  echo "FAIL: mutation score ${SCORE}% is below the ${THRESHOLD}% floor. Triage survivors:"
  mutmut results
  exit 1
fi
echo "PASS: mutation score meets the floor."
```

60% is the floor — the same number the parent `SKILL.md` justifies against the equivalent-mutant
rate — enforced on the `domain`/`service_layer` scope only. Raising it for a compliance-critical
product edits the single `THRESHOLD` line (or the `sdlc-config-management` override key below),
not the policy.

---

## The cosmic-ray Alternative — Native Rate Gating and Distribution

When a domain grows large enough that serial mutmut runs blow the CI time budget, switch to
cosmic-ray, which distributes execution and gates the rate natively so no wrapper script is needed:

```toml
# cosmic-ray.toml
[cosmic-ray]
module-path = "src/classification/domain"
timeout = 20.0
test-command = "python -m pytest -x -q tests/unit/"

[cosmic-ray.distributor]
name = "http"   # farm mutants out to worker processes; "local" runs serially like mutmut.
```

```bash
# Initialise the session (enumerate mutants), then execute them.
cosmic-ray init cosmic-ray.toml session.sqlite
cosmic-ray exec cosmic-ray.toml session.sqlite

# Human report of survivors.
cr-report session.sqlite

# Gate CI natively: cr-rate prints the SURVIVAL rate (survived / total; lower is better) and
# fails when it goes OVER the bound. A 60% kill floor is a 40% survival ceiling, so:
cr-rate session.sqlite --fail-over 40
```

`cr-rate --fail-over 40` is cosmic-ray's native equivalent of Gremlins' `threshold-efficacy: 60`
— it fails the build when the survival rate exceeds 40% (equivalently, the kill rate falls below
60%), no wrapper arithmetic required. This native rate gate is the second reason cosmic-ray is the
sanctioned scale-up alternative; mutmut needs `scripts/mutation-gate.sh` above to reach the same
outcome.

---

## Scheduled CI Workflow, in Full

```yaml
# .github/workflows/mutation.yml
name: mutation-testing

on:
  schedule:
    - cron: "0 3 * * 1"        # 03:00 UTC every Monday — the weekly default cadence.
  release:
    types: [published]         # mandatory pre-release run, in addition to the schedule.
  workflow_dispatch: {}        # manual trigger for investigating a specific survivor.

jobs:
  mutate:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version-file: pyproject.toml
      - name: install
        run: pip install -e ".[dev]" mutmut
      - name: mutation gate
        run: bash scripts/mutation-gate.sh   # computes the score, fails below 60%.
      - name: upload report
        if: always()
        run: mutmut html
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: mutation-report
          path: html/
```

**Never on `pull_request`.** No trigger in this file fires on a PR event — that is the entire
point of the periodic policy. The cost model is unforgiving: mutmut reruns the whole targeted
`pytest` suite once per surviving-candidate mutant, and because it re-imports the interpreter each
run and executes serially, a 40-mutant domain package with a 3-second suite lands around two
minutes per pass — and typically *worse* wall-clock than the Go sibling for the same mutant count,
which is precisely why the schedule is weekly-plus-pre-release rather than monthly like Gremlins.
A `workflow_dispatch` manual trigger exists for a developer actively triaging a survivor, a
deliberate human-invoked exception, not a standing per-PR gate.

`mutation_test_cadence` (`sdlc-config-management`) overrides the `cron` line for a specific product
— e.g. `"nightly"` maps to `cron: "0 3 * * *"` for a compliance-critical rule engine — without
changing any other line in this file.

---

## Worked Run

```
$ bash scripts/mutation-gate.sh
1. Generating mutants
2. Checking mutants
⠹ 41/41  🎉 34  ⏰ 0  🤔 0  🙁 7  🔇 0
Mutation score: 82% (killed 34 / 41); floor 60%
PASS: mutation score meets the floor.

$ mutmut results
Survived 🙁 (7)
---- src/classification/domain/pagination.py (1) ----
7
---- src/classification/service_layer/handlers.py (6) ----
12, 13, 18, 19, 24, 31

$ mutmut show 7
--- src/classification/domain/pagination.py
+++ src/classification/domain/pagination.py
@@ -4,1 +4,1 @@
-    return (page + 1) * page_size >= total_items
+    return (page + 1) * page_size > total_items
```

Mutant `7` is a survivor: the `>=`→`>` boundary flip on the last-page calculation was not caught by
any test. Whether it is a real gap (add a boundary `parametrize` row) or a genuine equivalent
mutant (annotate `# pragma: no mutate`) is decided by the triage question in
`references/interpreting-survivors.md`, worked in full there.
