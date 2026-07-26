# CI-Placement and Trigger Standard

The full journey suite runs less often than unit or integration tests. This is not a convenience shortcut — it is a deliberate placement decision forced by two compounding costs that the unit and integration layers do not carry, worked through explicitly below, followed by the exact trigger configuration and the separate, more frequent placement of the tagged `smoke` subset.

---

## The Cost-Model Arithmetic

| Layer | Setup cost per run | Who pays it |
|---|---|---|
| Unit (`go-unit-test`) | Microseconds — in-memory fakes | Every `go test ./...` invocation |
| Integration (`go-integration-test`) | ~1–3s Postgres, ~3–5s Redpanda — shared per package via `TestMain` | Every `make ci` run, every PR |
| **E2E (this skill)** | `kind create cluster` plus a multi-service Helm install — minutes, not seconds, per `environment-provisioning-standard.md` | Whoever triggers it |

`go-mutation-test` already establishes the reasoning pattern this standard reuses: multiply a per-run cost that is small in isolation by a realistic per-day PR volume, and a cost that looks affordable once becomes the dominant cost in the entire pipeline if it runs on every PR. A `kind` cluster running every service a journey touches costs low-single-digit minutes to provision, install, and tear down — call it comparable to or larger than the rest of `make ci` combined. Paid once nightly, that is an affordable, predictable cost. Paid on every PR across a normal day's PR volume, it would multiply into the majority of the CI budget for a signal that changes far more slowly than the code changes that would be triggering it.

The second cost is **trust**, not compute: e2e's real network/timing dependencies give it a non-zero false-failure rate even after the one-retry policy (`flakiness-budget-and-quarantine-standard.md`). A required PR gate with a meaningfully non-zero false-failure rate trains engineers to reflexively re-run red builds — which is precisely the failure mode `flakiness-budget-and-quarantine-standard.md` names as worse than no test at all. Keeping the full suite off the PR gate keeps that failure mode off the PR gate too.

---

## Three Triggers for the Full Suite — Never `pull_request`

```yaml
# .github/workflows/e2e-nightly.yml
name: e2e-journeys
on:
  schedule:
    - cron: "0 2 * * *"        # 02:00 UTC nightly — the steady-state cadence
  release:
    types: [published]          # mandatory pre-release run, in addition to nightly
  workflow_dispatch: {}         # manual trigger — verify one fix without waiting for 02:00

jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - run: ./tests/e2e/provision-kind.sh
      - run: go test ./tests/e2e/journeys/... -v -json > run1.json || \
             go test ./tests/e2e/journeys/... -v -json -run "$(jq -r 'select(.Action=="fail" and .Test) | .Test' run1.json | paste -sd '|')" > run2.json
      - if: always()
        run: kind delete cluster --name "e2e-${{ github.run_id }}" || true
```

| Trigger | What it does | Grounding |
|---|---|---|
| **Nightly** (`schedule`) | Runs the full journey suite once a day | `ci-pipeline`'s trigger table already names "Nightly schedule → e2e (`go-e2e-test`) ... against a kind/staging environment"; `environment-config` already names "nightly e2e/load suites" as part of `staging`'s stated purpose. This skill fulfills the cadence those two skills already assume exists, rather than inventing a new one. |
| **Pre-release** (`release: types: [published]`) | Runs the full suite again at release time | Mirrors `go-mutation-test`'s dual "periodic plus pre-release" cadence — a release must not ship on a nightly result that is already a day or more stale. |
| **On-demand** (`workflow_dispatch`) | A developer triggers a fresh run manually | Same design as `go-mutation-test`'s manual trigger for a developer actively triaging a specific failure, without waiting for the schedule. |

**Never `pull_request`.** No trigger above fires on a PR event — this is the entire point of the cost-model argument above, and it mirrors `go-mutation-test`'s identical "never on every PR" placement for the same underlying reason (a full-fidelity, expensive signal that changes slowly does not belong on the fast inner loop).

A nightly failure does not page anyone at 2 a.m. — per `ci-pipeline`'s existing policy for this exact trigger, it opens an issue and blocks the next `dev`→`staging` promotion (`cd-pipeline`) until the suite is green again.

---

## `e2e_test_cadence` — the Product-Specific Override

`sdlc-config-management` already documents this exact override pattern for `go-mutation-test` (`mutation_test_cadence`) as "the narrow set of factory-wide tuning parameters individual skills define." This skill defines its own parameter the same way:

```json
{ "methodology_overrides": { "e2e_test_cadence": "twice-daily" } }
```

A product whose compliance-critical journeys warrant tighter e2e coverage sets this once; the nightly `cron` line in `.github/workflows/e2e-nightly.yml` is the only line that changes — nothing else in this standard, in `.gremlins.yaml`'s sibling for e2e, or in the trigger table changes shape.

---

## The Tagged `smoke` Subset Runs Separately, and More Often

The full suite above is not the only thing `go-e2e-test` produces. A small, non-destructive, `smoke`-tagged slice of the same journey test files runs on a **different, more frequent** trigger — directly against real, persistent environments, as part of infrastructure three other skills already describe and depend on existing:

| Consumer | When the smoke subset runs | Invocation |
|---|---|---|
| `cd-pipeline` | Post-deploy verification, every promotion (dev, staging, each tenant wave) | `go test ./tests/e2e/... -tags smoke -tenant=<id>` |
| `blue-green-deployment` | Pre-cutover gate, directly against green's Service before the live selector ever points at it | Same invocation, targeted at green's temporary debug Service |
| `disaster-recovery-plan` | Post-restore verification, confirming a restored stamp actually works | `go test ./e2e/... -tags smoke -tenant=acme-drill` |

This standard's obligation to those three consumers: mark a journey `smoke`-eligible (`//go:build smoke`) only if it is safe to run repeatedly, on every promotion, against a real environment carrying real tenant data — non-destructive, idempotent per this file's seeding rules, and fast (seconds, not minutes). The full suite's freedom to seed and tear down an entire disposable `kind` cluster does not extend to the smoke subset; a smoke test that mutates state it cannot cleanly undo does not belong in the `smoke` build tag.
