# Feature Flag Design — Implementation Patterns

Reference material for `feature-flag-design/SKILL.md`. Self-contained — usable without the parent
skill in context. Covers: flag YAML schemas, entitlement placement, CI flag matrix, kill-switch Go
pattern, and the canary-scoped release flag worked example.

---

## Release Flag YAML Schema

Every release flag is a standalone YAML file under `flags/release/`. Four fields are non-optional;
the CI inventory check script (below) fails the build if any are absent or if `removal_date` has
passed.

```yaml
# flags/release/extractor-v2-enabled.yaml
key: extractor.v2.enabled
kind: release
owner: platform-engineer          # accountable person for flag removal, not a team name
created: 2026-07-20
removal_date: 2026-08-10          # ≤ 3 weeks from created — hard default; extend only with an ADR
removal_issue: PLAT-482           # GitHub/Linear issue that closes when the flag is deleted
default: false                    # what the code does when no flag value is present
description: >
  Routes document extraction to the v2 model when true. Canary-tenant only
  until PLAT-482 evaluation completes; see canary-deployment worked example
  for the accompanying traffic wave.
```

**Removal means deletion, not pinning to `true`.** When the rollout is complete, delete the flag
file and delete the `if flags.Bool(ctx, key, ...)` branch from code — the losing branch is removed,
the winning branch becomes unconditional. A flag that is permanently `true` is an untested branch
waiting to be corrupted by the next engineer who doesn't know it matters.

---

## Entitlement Flag YAML Placement

Entitlement flags are not in `flags/`. They live in the per-tenant values layer of the environment
repo — `environment-config`'s difference-class table, row "flags". Their lifetime is the tenant's
contract, not a rollout window.

```yaml
# deploy/clusters/tenants/tenant-acme/compliance-engine-values.yaml (extract)
flags:
  entitlement.advanced-classification: true    # acme's contracted tier — set at onboarding
  entitlement.export-to-siem: false             # not on acme's plan as of 2026-07-20
  entitlement.multi-tenant-isolation: true      # physical isolation — always true for enterprise
```

```yaml
# deploy/clusters/tenants/tenant-startup/compliance-engine-values.yaml (extract)
flags:
  entitlement.advanced-classification: false   # starter plan — does not include advanced
  entitlement.export-to-siem: false
  entitlement.multi-tenant-isolation: false     # shared-cluster tenant
```

Entitlement flags never appear in `flags/release/` or `flags/experiment/`. Running them through the
CI inventory check would flag them as missing a `removal_date`, which is correct — they should not
have one. Keep the two populations separate by directory.

Server-side enforcement pattern (Go):

```go
// access-control-model's ABAC boundary applies here too — client hint, server gate
func (h *ClassificationHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    tenantID := auth.TenantIDFromContext(r.Context())
    if !h.flags.Bool(r.Context(), "entitlement.advanced-classification", false) {
        http.Error(w, "feature not available on your plan", http.StatusForbidden)
        return
    }
    // ... proceed with advanced classification
}
```

---

## CI Flag Matrix — Full YAML and Inventory Check Script

### GitHub Actions matrix job

The matrix job doubles the test count for each active flag — once with the flag `true`, once with
`false`. Tag the test with `flagmatrix` so CI can run the matrix job independently of the main
test suite on the longer nightly schedule if needed, or on every PR if the suite stays fast.

```yaml
# .github/workflows/ci.yml (extract — flag matrix job)
jobs:
  flag-matrix:
    strategy:
      matrix:
        extractor_v2_enabled: [true, false]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true
      - name: Run flag matrix tests
        env:
          FLAG_EXTRACTOR_V2_ENABLED: ${{ matrix.extractor_v2_enabled }}
        run: |
          go test ./... -run TestExtractorPipeline -tags flagmatrix -count=1
```

In Go, the flag value is read from the environment in the test setup, overriding whatever the
ConfigMap provides — this is the only place where a flag value is injected without a ConfigMap:

```go
//go:build flagmatrix

package extractor_test

import (
    "os"
    "strconv"
    "testing"
)

func TestExtractorPipeline(t *testing.T) {
    v2Enabled, _ := strconv.ParseBool(os.Getenv("FLAG_EXTRACTOR_V2_ENABLED"))
    // inject flag value into the test's flag provider
    flags := flagtest.NewStub(map[string]bool{
        "extractor.v2.enabled": v2Enabled,
    })
    // ... rest of the test, exercising both code paths deterministically
}
```

### Flag inventory check script

Runs on every PR that touches `flags/`. Fails the build if any release or experiment flag is past
its `removal_date` or is missing an `owner`. Ops and entitlement flags are not checked for
expiry — they are expected to persist.

```bash
#!/usr/bin/env bash
# check-flag-inventory.sh — CI gate on every PR touching flags/
# Usage: run as a step in a GitHub Actions job; exits non-zero on any violation.
set -euo pipefail

fail=0
today=$(date +%F)

for f in flags/release/*.yaml flags/experiment/*.yaml 2>/dev/null; do
  [[ -f "$f" ]] || continue

  removal=$(yq '.removal_date // ""' "$f")
  owner=$(yq '.owner // ""' "$f")
  key=$(yq '.key // ""' "$f")

  if [[ -z "$owner" || "$owner" == "null" ]]; then
    echo "FLAG DEBT: $f (key: $key) has no owner" >&2
    fail=1
  fi

  if [[ -z "$removal" || "$removal" == "null" ]]; then
    echo "FLAG DEBT: $f (key: $key) has no removal_date" >&2
    fail=1
  elif [[ "$removal" < "$today" ]]; then
    echo "FLAG DEBT: $f (key: $key) is past its removal_date ($removal) — delete the flag" >&2
    fail=1
  fi
done

# Ops and entitlement flags: must still have an owner (for incident lookup), no expiry check
for f in flags/ops/*.yaml flags/entitlement/*.yaml 2>/dev/null; do
  [[ -f "$f" ]] || continue
  owner=$(yq '.owner // ""' "$f")
  key=$(yq '.key // ""' "$f")
  if [[ -z "$owner" || "$owner" == "null" ]]; then
    echo "FLAG DEBT: $f (key: $key) has no owner — incident responders need this" >&2
    fail=1
  fi
done

exit $fail
```

---

## Kill-Switch Go Consumer Loop Pattern

The canonical ops flag pattern: a Redpanda consumer loop that checks the kill-switch flag on each
poll interval. The flag value is read from the ConfigMap-mounted flag file; the file-watch reload
(SIGHUP or `inotify`) propagates the change within one poll cycle — sub-10 seconds in practice.

```go
// internal/pipeline/consumer.go

const (
    flagConsumerPaused  = "pipeline.entity-extractor.consumer.paused"
    pauseCheckInterval  = 5 * time.Second
)

// Run is the main consumer loop. It exits when ctx is cancelled.
func (c *Consumer) Run(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }

        if c.flags.Bool(ctx, flagConsumerPaused, false) {
            c.metrics.ConsumerPaused.Set(1)
            select {
            case <-time.After(pauseCheckInterval):
            case <-ctx.Done():
                return ctx.Err()
            }
            continue
        }

        c.metrics.ConsumerPaused.Set(0)
        if err := c.processBatch(ctx); err != nil {
            c.metrics.ProcessingErrors.Inc()
            c.logger.Error("batch processing failed", zap.Error(err))
            // do not exit — next poll will retry; DLQ handles poison messages
        }
    }
}
```

**Break-glass procedure** (incident cannot wait for a reconciliation interval):

```bash
# break-glass: flip the kill-switch without waiting for GitOps reconciliation
kubectl patch configmap entity-extractor-flags \
  -n production \
  --patch '{"data":{"pipeline.entity-extractor.consumer.paused":"true"}}'

# the consumer reloads within one pauseCheckInterval (5s)
# IMMEDIATELY open a PR to the environment repo with the same change:
# deploy/clusters/production/entity-extractor-values.yaml:
#   flags:
#     pipeline.entity-extractor.consumer.paused: "true"
# Git must catch up to reality within the hour — drift is alerted by cd-pipeline
```

The drift alert fires as soon as the reconciler detects the ConfigMap differs from the environment
repo. The alert is expected during the incident window; do not silence it — the alert resolving on
PR merge is the confirmation that GitOps reality is restored.

---

## Worked Example — Canary-Scoped Release Flag for a New Extractor Model

`entity-extractor` is getting a new entity-extraction model (v2). The rollout combines a **release
flag** (behavioural: which model runs) with `canary-deployment`'s **tenant wave** (deployment: which
tenants run the new binary at all). Two different axes, composed deliberately:

- The tenant wave controls *whether* a tenant sees the new binary.
- The release flag controls *which code path* runs inside that binary.
- Flipping the flag reverts the model without a redeploy — seconds, not pipeline minutes.

### Flag definition

```yaml
# flags/release/extractor-v2-enabled.yaml
key: extractor.v2.enabled
kind: release
owner: platform-engineer
created: 2026-07-20
removal_date: 2026-08-10
removal_issue: PLAT-482
default: false
description: >
  Routes document extraction to the v2 model when true. Canary-tenant only
  until PLAT-482 evaluation completes; see canary-deployment worked example
  for the accompanying traffic wave.
```

### Per-tenant flag values

```yaml
# deploy/clusters/tenants/tenant-canary/entity-extractor-values.yaml
flags:
  extractor.v2.enabled: "true"      # canary tenant runs v2 behaviour
```

```yaml
# deploy/clusters/tenants/tenant-acme/entity-extractor-values.yaml
flags:
  extractor.v2.enabled: "false"     # unaffected until PLAT-482 promotes the wave
```

Both tenants run the **same image digest** — `environment-config`'s parity rule is intact; only the
flag value differs. If v2 regresses extraction accuracy (caught by the correctness SLI from
`slo-definition`), the fix is a values PR flipping the flag back to `"false"` for the canary tenant
— no rollback, no redeploy, seconds not minutes.

### Go code path

```go
// internal/extractor/router.go

func (r *Router) Extract(ctx context.Context, doc Document) (Entities, error) {
    if r.flags.Bool(ctx, "extractor.v2.enabled", false) {
        return r.v2.Extract(ctx, doc)
    }
    return r.v1.Extract(ctx, doc)
}
```

When the model is proven and rolled to the full fleet, `extractor.v2.enabled` is deleted from the
flag file, from every tenant's values, and from the `Router.Extract` method — the `if` collapses to
an unconditional call to `r.v2.Extract`. PLAT-482 closes on the same PR.

### Timeline

| Date | Action |
|---|---|
| 2026-07-20 | Flag created; v2 code merged to `main` dark (flag `false` everywhere) |
| 2026-07-21 | Canary tenant values flipped to `true`; v2 active for one tenant |
| 2026-07-28 | Correctness SLI passes; PLAT-482 evaluation complete |
| 2026-08-05 | Flag flipped `true` for full fleet via values PRs across all tenants |
| 2026-08-10 | Flag deleted from code and all values; PLAT-482 closed; `removal_date` honoured |

Note that 2026-08-10 is within 3 weeks of 2026-07-20 — the hard `removal_date` default is met.
If the evaluation had not completed by 2026-08-10, the owner would have filed an ADR to extend the
deadline (maximum one extension without a re-evaluation gate) rather than silently letting the date
pass.
