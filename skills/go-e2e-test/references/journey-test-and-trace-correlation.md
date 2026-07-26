# Worked Journey Test and Trace Correlation

A complete API-level e2e journey test, the condition-based wait pattern that replaces every `time.Sleep`, and the trace-correlation helper that ties a failing journey to one connected OpenTelemetry trace.

---

## Two Surfaces, One Journey

| Surface | Tool | Use for |
|---|---|---|
| **UI e2e** | Playwright (`react-e2e-testing`) | True full-stack journeys through the browser |
| **API e2e** | Go HTTP client against the deployed API (`kind` cluster or, for the `smoke` subset, a real environment) | Backend-centric journeys — faster, no browser, less flaky |

The same Gherkin journey scenario (`bdd-feature-file`) can bind to either surface. Choose UI e2e for genuinely user-facing flows the browser itself is part of proving (navigation, rendering, accessibility of the flow); choose API e2e for everything else a journey needs to prove about the backend chain.

---

## A Complete API-Level Journey Test

```go
// tests/e2e/journeys/classify_test.go
func TestJourney_ClassifyThenAppearsInReport(t *testing.T) {
    runID := t.Name() + "-" + uuid.NewString()
    ctx := withTestTrace(context.Background(), runID)   // one trace, browser-free

    tenantID := seedTenant(ctx, dbForKindCluster(t), runID)
    t.Cleanup(func() { teardownTenant(ctx, dbForKindCluster(t), tenantID) })

    token := signInAsSteward(t, ctx, tenantID)
    assetID := connectSourceAndWaitForAsset(t, ctx, token) // through the real pipeline
    classify(t, ctx, token, assetID, "Restricted")

    // Eventually consistent: the projection updates after the event is processed —
    // this is asserted with a poll, never a fixed sleep. See below.
    report := awaitGapReportReflects(t, ctx, token, assetID, 10*time.Second)
    require.Contains(t, report.RestrictedAssets, assetID)
}
```

Every line above is an HTTP call to the deployed API running as a real Pod in the `kind` cluster (`environment-provisioning-standard.md`) — nothing in this function imports another service's package, which is precisely what makes it e2e rather than an elaborate integration test (`SKILL.md`'s Scope Boundary).

---

## Condition-Based Waits — Never `time.Sleep`

Arbitrary `time.Sleep` is the cardinal sin of e2e: too short and it's flaky, too long and the suite crawls. Wait for a condition, not a duration:

| Instead of | Do |
|---|---|
| `time.Sleep(3 * time.Second)` | Poll for the expected state with a deadline |
| Sleeping for the pipeline | Poll until the projection reflects the event (Eventual Consistency, by design — `data-pipeline-design`) |
| Sleeping for the UI | Playwright's own auto-waiting on element/network-idle state |

```go
// Condition-based wait with a deadline — as fast as the system allows, never flaky-fast.
func awaitGapReportReflects(t *testing.T, ctx context.Context, tok string, id uuid.UUID, d time.Duration) Report {
    t.Helper()
    deadline := time.Now().Add(d)
    for time.Now().Before(deadline) {
        r := getGapReport(ctx, tok)
        if contains(r.RestrictedAssets, id) {
            return r
        }
        time.Sleep(100 * time.Millisecond) // a poll interval, not a guess at completion time
    }
    t.Fatalf("gap report did not reflect %s within %s", id, d)
    return Report{}
}
```

The 100ms `time.Sleep` inside the poll loop is not the anti-pattern — it is a poll interval bounded by an explicit deadline that fails loudly and immediately when breached. The anti-pattern is a sleep used *as* the synchronization mechanism, with no condition checked and no deadline stated.

---

## Test-Trace Correlation

Every request a journey test makes carries a unique test id propagated as trace headers, so a failing journey's activity across every service it touched is one connected OpenTelemetry trace (`distributed-tracing-design`) rather than a scattered set of per-service logs that have to be manually correlated by timestamp:

```go
func withTestTrace(ctx context.Context, testName string) context.Context {
    tracer := otel.Tracer("go-e2e-test")
    ctx, span := tracer.Start(ctx, testName)
    _ = span // the span id/trace id now propagate via the context's traceparent
    return ctx
}
```

Every HTTP helper (`signInAsSteward`, `connectSourceAndWaitForAsset`, `classify`, `getGapReport`) injects the `traceparent` header from `ctx` on every outbound call. When a journey fails, its trace id (logged alongside the failure — the same trace id `flakiness-budget-and-quarantine-standard.md`'s detection record captures) leads straight to the exact span that broke, across every service the journey crossed — root-cause without re-running under a debugger.
