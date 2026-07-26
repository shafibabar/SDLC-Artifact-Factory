# Test-Data Seeding and Teardown Standard

E2E flakiness most often comes from data assumptions, not from the system under test. This standard covers two disciplines that fail independently: seeding data that survives a retry without duplicating or erroring, and guaranteeing cleanup runs even when the test run itself does not exit cleanly.

---

## Idempotent Seeding

Even though the full journey suite gets a fresh `kind` cluster per run (`environment-provisioning-standard.md`), the **seed step within a run** can still retry on its own — a flaky network call to the running services, a CI step-level retry action, or a developer re-invoking the seed script against an already-provisioned cluster while debugging locally. A seed script that is not idempotent turns any of these into a second class of flake layered on top of the one the environment standard already eliminated.

The rule: every seeded row is reached by **upsert**, keyed on an ID derived deterministically from the run id — never a blind `INSERT` that errors or duplicates on a second invocation.

```go
// tests/e2e/seed.go
func seedTenant(ctx context.Context, db *pgxpool.Pool, runID string) (tenantID uuid.UUID, err error) {
    // Deterministic, not random: the same runID always yields the same tenantID,
    // so re-running this function against the same cluster is a no-op the second time.
    tenantID = uuid.NewSHA1(seedNamespace, []byte("tenant:"+runID))

    _, err = db.Exec(ctx, `
        INSERT INTO tenants (id, name, created_at)
        VALUES ($1, $2, now())
        ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name`,
        tenantID, "e2e-"+runID)
    return tenantID, err
}
```

Every downstream seed function (users, sources, sample documents) derives its own ID the same way — `uuid.NewSHA1(seedNamespace, []byte("asset:"+runID+":"+n))` — so the whole seeded world is reproducible from `runID` alone and safe to rerun in place.

---

## Guaranteed Teardown — Three Layers

A cleanup step that only runs on the success path is not a cleanup step; it is a happy-path convenience that fails exactly when it matters most — when the run has already gone wrong. Guaranteed teardown means the same teardown call fires on every exit path, enforced by three independent layers, because any single layer has a gap the next one closes:

| Layer | Mechanism | Catches | Gap it has alone |
|---|---|---|---|
| 1 — In-runner trap | `trap cleanup EXIT` in the provisioning script | Test failures, script errors, normal exit | Does not fire on `SIGKILL` (a hard job timeout) |
| 2 — Workflow `always()` | A dedicated `if: always()` step in the GitHub Actions job | Job timeout, a step the trap's own process never reached, runner-level cancellation | Does not fire if the runner itself crashes or is force-terminated by the platform |
| 3 — Orphan janitor | A separate, low-frequency scheduled job that deletes any `e2e-*` `kind` cluster/cloud resource older than a threshold | The rare case both layers 1 and 2 fail to run | Not real-time — a safety net, not the primary mechanism |

```yaml
# .github/workflows/e2e-nightly.yml (excerpt — full trigger set in ci-placement-and-trigger-standard.md)
jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4
      - name: Provision and run journeys
        run: ./tests/e2e/provision-kind.sh && go test ./tests/e2e/journeys/... -v
      - name: Teardown (always runs — layer 2)
        if: always()
        run: kind delete cluster --name "e2e-${{ github.run_id }}" || true
```

Layer 2 exists precisely because layer 1 has a known gap: a bash `trap` only fires if the process is still alive to run its exit handler. GitHub Actions' `timeout-minutes` enforcement sends a termination signal that does not guarantee the trap executes — so the workflow-level `always()` step, which GitHub Actions itself guarantees runs regardless of prior step outcome (including timeout), is the real backstop, not the trap. The trap is still worth keeping: it is faster (no round-trip through the workflow engine) and covers local/manual runs where there is no surrounding workflow at all.

```bash
#!/usr/bin/env bash
# A scheduled janitor — layer 3, runs independently of any specific e2e run
set -euo pipefail
kind get clusters | grep '^e2e-' | while read -r cluster; do
  created=$(kind get kubeconfig --name "$cluster" | grep -oP '(?<=created-at: ")[^"]+' || echo "")
  # delete anything older than 6 hours — no legitimate run takes that long
  [ -n "$created" ] && python3 -c "
import sys, datetime
age = datetime.datetime.utcnow() - datetime.datetime.fromisoformat('$created'.replace('Z',''))
sys.exit(0 if age.total_seconds() > 21600 else 1)
" && kind delete cluster --name "$cluster"
done
```

---

## What "Happy-Path-Only" Looks Like — and the Fix

```go
// WRONG — teardown only reached if the journey assertions never fail
func TestJourney_Classify(t *testing.T) {
    tenantID := seedTenant(ctx, db, runID)
    // ... assertions that can call t.Fatalf ...
    teardownTenant(ctx, db, tenantID)   // never reached on failure
}
```

```go
// RIGHT — t.Cleanup runs on every exit path, pass or fail, exactly like the
// workflow-level `if: always()` step does one layer up
func TestJourney_Classify(t *testing.T) {
    tenantID := seedTenant(ctx, db, runID)
    t.Cleanup(func() { teardownTenant(ctx, db, tenantID) })
    // ... assertions ...
}
```

`t.Cleanup` handles the *within-process* failure path (a failed assertion); the workflow's `if: always()` step handles the *whole-process* failure path (the binary itself crashing, the job timing out). Both are needed — one does not substitute for the other, exactly as the three-layer table above states for the cluster-level teardown.
