# Tool Configuration and Targeting

Full grounding for `go-mutation-test`'s "Tool Configuration and Targeting" and "Budget and
Scheduling" sections: the exact Gremlins configuration, the package-glob targeting convention in
full, the scheduled CI workflow, and the cost-model arithmetic behind the periodic-not-per-PR
policy. Self-contained — restates the targeting rule and the threshold number below rather than
assuming the parent `SKILL.md` body is in context.

---

## Why Gremlins

Two Go mutation testers exist in practice: **Gremlins** (`go-gremlins/gremlins`) and the older,
less actively maintained `go-mutesting`. Gremlins is this repo's default because it is
open-source, Go-native (no JVM or external runtime dependency the way some polyglot mutation
tools require), and actively maintained — satisfying the Budget and Frugality constraint
(`CLAUDE.md`) without needing to evaluate or justify a paid alternative. No commercial mutation
testing SaaS is in scope; if one is ever proposed, it requires the same explicit
frugality-constraint approval `go-contract-test` requires before considering PactFlow over a
self-hosted Pact Broker.

---

## `.gremlins.yaml` in Full

```yaml
# .gremlins.yaml — committed at repo root. Scope, threshold, and named exclusions live here,
# never as ad hoc CLI flags that bypass this committed configuration.
unleash:
  tags: ""
  threshold-efficacy: 60      # mutation score (killed / (total - equivalent)) gate, see SKILL.md
  threshold-mcover: 0         # no separate mutant-coverage floor; efficacy is the only gate
  dry-run: false
  workers: 4                  # bounded parallelism; each worker reruns the full targeted suite

# Named, commented exclusions only — never a silent skip list. One entry per confirmed
# equivalent mutant, added during triage step 3's "No" branch, never pre-emptively.
excludes:
  # - internal/domain/pagination.go:42  # `>=`->`>` on totalItems clamp: clamped value identical
  #   at exact-equality input, no observable-output divergence exists. Triaged 2026-07-24.
```

`threshold-efficacy: 60` is the enforced gate — the same number `SKILL.md` states and justifies
against the equivalent-mutant rate. Raising it per `sdlc-config-management`'s override pattern for
a compliance-critical bounded context edits only this one line in that product's own
`.gremlins.yaml`; the mechanism does not change.

---

## CLI Invocation

```bash
# Run against the domain package only — the exact scope the scheduled CI job also uses.
gremlins unleash ./internal/domain/...

# Run against both targeted trees together (the scheduled job's actual invocation).
gremlins unleash ./internal/domain/... ./internal/application/...
```

Gremlins reads `.gremlins.yaml` from the repo root automatically; no flag duplicates what the
committed config already states. A developer investigating a single survivor locally scopes
further with `-w` (a single worker, easier to read sequential output) but never edits the
committed `threshold-efficacy` to make a local run pass — that value is the gate, not a suggestion.

---

## Package-Glob Targeting Convention, in Full

| Package glob | Mutated? | Why |
|---|---|---|
| `internal/domain/...` | **Yes, always** | Quadrant 1 in `go-unit-test`'s complexity heuristic — high domain significance, few collaborators. This is where a real bug is most expensive and a weak assertion most dangerous. |
| `internal/application/...` | **Yes, always** | Command/query handlers orchestrating domain logic — still quadrant-1-adjacent significance, thin enough on collaborators that mutation signal stays legible. |
| `internal/infrastructure/...` | **No** | Repositories and adapters are Humble Object (`go-repository-pattern`) — quadrant 3, correctness verified by `go-integration-test` against the real dependency. Mutating a SQL-adjacent line here tests wiring, not logic; the mutant tells you a query changed, not that a decision broke. |
| `internal/handlers/...` (chi handlers) | **No** | Also Humble Object (`go-chi-handler`) — quadrant 3, deserialize-and-delegate with no decision logic of its own. Same reasoning as infrastructure. |
| `cmd/**` | **No** | Composition roots wire dependencies and start the process; `go-project-structure` and `go-makefile`'s coverage standard both already exclude this by construction — no decision logic exists here to mutate. |
| `**/*_gen.go`, `**/*.pb.go`, `**/*_mock.go` | **No** | Generated code and test doubles — identical filename-pattern exclusion `go-makefile`'s `check-coverage.sh` already applies to the line-coverage profile, reused here rather than re-invented. |

**Why this exactly mirrors `go-unit-test`'s quadrant heuristic:** mutation testing is expensive
per the cost model below, so it must be spent where a survived mutant is actually informative —
quadrant-1/near-quadrant-1 code where the test suite's whole job is to encode business rules.
Spending the same budget on quadrant-3 Humble Object code would generate mutants whose survival
says "this wrapper doesn't re-implement its dependency's logic," which is true by design and not
a gap `go-integration-test`'s real-dependency tests haven't already covered better.

**Adding a new domain package to the target list:** because both globs are directory-recursive
(`internal/domain/...`, `internal/application/...`), a new package created inside either tree is
targeted automatically the next scheduled run — no `.gremlins.yaml` edit is needed. A new
top-level tree outside those two globs (which should be rare — `go-project-structure` defines the
layered structure this convention assumes) requires an explicit, reviewed addition to the
`unleash` invocation, not a silent broadening of scope.

---

## Scheduled CI Workflow, in Full

```yaml
# .github/workflows/mutation.yml
name: mutation-testing

on:
  schedule:
    - cron: "0 3 1 * *"       # 03:00 UTC on the 1st of each month — the monthly default cadence
  release:
    types: [published]         # mandatory pre-release run, in addition to the monthly schedule
  workflow_dispatch: {}        # manual trigger for investigating a specific survivor

jobs:
  mutate:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: install gremlins
        run: go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
      - name: unleash
        run: gremlins unleash ./internal/domain/... ./internal/application/...
      - name: upload report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: mutation-report
          path: gremlins.json
```

**Never on `pull_request`.** No trigger in this file fires on a PR event — that is the entire
point of the periodic policy below. A `workflow_dispatch` manual trigger exists for a developer
actively triaging a survivor who wants a fresh run without waiting for the schedule, which is a
deliberate, human-invoked exception, not a standing per-PR gate.

`mutation_test_cadence` (`sdlc-config-management`) overrides the `cron` line for a specific
product — e.g. `"weekly"` maps to `cron: "0 3 * * 1"` — without changing any other line in this
file or in `.gremlins.yaml`.

---

## The Cost-Model Arithmetic Behind "Periodic, Never Per-PR"

Mutation testing's cost is **not** one test-suite run — it is **one full targeted-suite run per
surviving-candidate mutant**, because Gremlins must rerun the suite against each mutated binary to
find out whether that specific mutant gets killed. A worked estimate:

- A domain package with 15 exported functions/methods, each generating on average 3–4 mutants
  (comparison flips, boundary shifts, operator swaps) → roughly 40–60 mutants for one
  medium-sized quadrant-1 package.
- The targeted suite (`internal/domain/...` plus `internal/application/...`) runs in ~3 seconds
  per pass on ordinary hardware.
- Total: 40–60 mutants × ~3s ≈ **2–3 minutes** for that one package. Scaled across every
  quadrant-1 and quadrant-1-adjacent package in a growing domain, the full targeted run commonly
  lands in the 10–20 minute range — before accounting for `workers: 4` parallelism, which reduces
  wall-clock but not total compute.

Run this on every PR and the multiplier compounds: a team merging even a modest handful of PRs a
day pays that 10–20 minutes **per PR**, on top of `make ci`'s existing gates — the exact "wrecks
the CI feedback loop" failure `SKILL.md`'s Anti-Patterns section names. A monthly schedule plus a
pre-release run pays the same total compute roughly once a month instead of dozens of times a day,
which is what makes the signal affordable at all under the frugality constraint.
