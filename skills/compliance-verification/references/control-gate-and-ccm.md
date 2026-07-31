# Control Gate and Continuous Control Monitoring

Reference for `compliance-verification`. Covers the explicit control-gate pipeline
stage (consumes and signature-verifies the required attestation set before
promotion, blocks on missing/invalid) and Continuous Control Monitoring wired onto
Prometheus / OpenTelemetry (a control expressed as a monitored SLI; drift raises an
alert and a fresh attestation), plus the point-in-time vs. continuous distinction
and why SOC 2 Type II needs continuous.

Grounded in the DevOps Automated Governance Reference Architecture (*Investments
Unlimited*) applied to this repo's GitHub Actions CI/CD and
OpenTelemetry + Prometheus + Tempo + Grafana observability stack. Standard names
only — no invented control IDs or clauses.

---

## Part 1 — The explicit control-gate stage

### Why an explicit gate, not scattered asserts

The tempting anti-pattern is `--exit-code 1` on trivy, an `assert` in a Go test, a
`deny` rule in OPA — each failing its own job. There is then no single place that
knows the *full required set* of controls for a promotion. A skipped or renamed
check silently drops out of coverage and nobody notices until an auditor asks.

A **control gate** is one dedicated pipeline stage — a single, auditable go/no-go
decision point. It does not re-run checks. It *consumes evidence*: it queries the
ledger for the required attestation set for this exact artifact digest, verifies
signatures, and decides. Its own verdict is then attested.

That is the distinction from a generic "CI gate": a CI gate re-runs a check; a
control gate reads and verifies attestations that other stages already produced.

### What the gate does, in order

```
1. Resolve the required control set for this change.
     ← the codified, version-controlled control list from compliance-design,
       filtered to enforcementMode == "gate".
2. For each required control:
     a. Query the ledger for an attestation with this artifact digest + control id.
     b. MISSING  → block (no evidence the control ran).
     c. Verify the DSSE signature against the expected CI signing identity.
        INVALID  → block (evidence not trustworthy).
     d. Read the predicate result.
        FAIL     → block, UNLESS a signed, dated accepted-risk exception exists.
3. All required controls PASS (or exception) → permit promotion.
4. Emit a gate-verdict attestation (itself signed, pinned to the same digest).
```

Three block conditions, all fail-closed: **missing**, **invalid signature**, and
**FAIL result without a signed exception**. "No attestation found" is a block, not
a pass — absence of evidence is not evidence of compliance.

### Go implementation

```go
// Gate consumes the required attestation set for one artifact digest and decides
// promotion. It re-runs nothing; it verifies evidence others produced.
type Gate struct {
    ledger        Ledger
    signerIdentity string // expected CI OIDC identity
    required      []ControlSpec // from the version-controlled control set (mode==gate)
    exceptions    ExceptionStore
}

type Decision struct {
    Promote bool
    Blocks  []string // human-readable reasons, one per blocked control
}

func (g *Gate) Evaluate(ctx context.Context, digest string) (Decision, error) {
    var blocks []string
    for _, spec := range g.required {
        env, found := g.ledger.Get(ctx, digest, spec.ControlID)
        if !found {
            blocks = append(blocks, fmt.Sprintf("%s: no attestation for digest %s", spec.ControlID, digest))
            continue
        }
        stmt, err := attest.Verify(ctx, env, digest, g.signerIdentity)
        if err != nil {
            blocks = append(blocks, fmt.Sprintf("%s: attestation invalid: %v", spec.ControlID, err))
            continue
        }
        if stmt.Predicate.Result != "PASS" {
            if !g.exceptions.HasSignedException(ctx, digest, spec.ControlID) {
                blocks = append(blocks, fmt.Sprintf("%s: result=%s and no signed exception", spec.ControlID, stmt.Predicate.Result))
            }
        }
    }
    d := Decision{Promote: len(blocks) == 0, Blocks: blocks}
    // The gate's own verdict is attested, pinned to the same digest.
    _ = g.attestVerdict(ctx, digest, d)
    return d, nil
}
```

### GitHub Actions wiring

The gate is a required job that `deploy` depends on. `needs.build.outputs.digest`
threads the exact promoted digest through so the gate verifies attestations for the
artifact actually being promoted — not an approximation via commit SHA.

```yaml
jobs:
  control-gate:
    runs-on: ubuntu-latest
    needs: [build, compliance-tests, iac-scan, vuln-scan]
    permissions:
      id-token: write   # to sign the gate-verdict attestation
      contents: read
    steps:
      - uses: actions/checkout@v4
      - name: Control gate — verify required attestation set
        run: go run ./cmd/control-gate -digest "${{ needs.build.outputs.digest }}"
        # exits non-zero (fails the job, blocks deploy) if any required control
        # is missing, unsigned/invalid, or FAIL without a signed exception.
  deploy:
    needs: [control-gate]   # cannot run unless the gate permits
    runs-on: ubuntu-latest
    steps:
      - run: echo "promoting ${{ needs.build.outputs.digest }}"
```

### Separation of Duties is a gate control too

The classic change-management control — the author of a change cannot be the person
who approves its release — becomes real only when the gate enforces it. Add a
control whose test reads the PR author and the approving reviewer identity and FAILs
when they are equal (or when no independent approval exists), emitting an SoD
attestation. In policy form it is honor-system; as a `gate`-mode attested control it
is mechanically enforced against this repo's `feature/<n>-…` → PR → `main` flow.

---

## Part 2 — Continuous Control Monitoring (CCM)

### Point-in-time vs. continuous

The control gate proves a control passed **at deploy**. It says nothing about the
120 days after deploy. Encryption-at-rest can be turned off, an mTLS policy can be
dropped, a query can start crossing tenants — all *between* deploys, invisibly to a
gate that only fires on promotion.

| | Point-in-time (control gate) | Continuous Control Monitoring |
|---|---|---|
| Fires | On every deploy | Continuously in production |
| Answers | "Did the control pass at deploy?" | "Does the control still hold right now?" |
| Mechanism | Go test / OPA policy / attestation verify | Prometheus rule over OTel signals |
| On failure | Blocks promotion | Alert + fresh drift attestation |
| Evidence | Deploy-time attestation | Continuous stream of monitored-state attestations |

**Why SOC 2 Type II needs continuous.** A Type I report attests a control was
*designed* and existed at a point in time. A Type II report attests the control
**operated effectively over a period** (typically 6–12 months). A stack of
point-in-time deploy attestations with month-long gaps between them does not
demonstrate the control held *throughout*. CCM fills the gaps with continuous
evidence, so the ledger can show the control operated across the entire period —
which is precisely what a Type II auditor assesses.

### A control expressed as a monitored SLI

CCM reuses the observability stack the product already runs. A subset of controls
maps cleanly onto Prometheus rules over OpenTelemetry signals:

| Control | SLI (Prometheus) | Drift condition |
|---|---|---|
| Encryption-at-rest still on | `min(pg_storage_encrypted) == 1` | drops below 1 |
| mTLS coverage complete | `linkerd_tls_connections / linkerd_total_connections` | < 1.0 for 5m |
| No untenanted queries | `rate(db_queries_without_tenant_filter_total[5m])` | > 0 |
| Retention window honored | `max(data_asset_age_seconds) <= retention_limit` | exceeds limit |
| Raw file contents never persisted | `rate(raw_content_bytes_written_total[5m])` | > 0 (must always be 0) |

The last row is the product's core privacy invariant: only entity types and counts
are stored, never raw file contents. CCM makes that a continuously monitored,
attested control rather than a one-time design claim.

### Prometheus alert rules

```yaml
# ccm-rules.yaml — Continuous Control Monitoring expressed as alerting rules.
groups:
  - name: continuous-control-monitoring
    rules:
      - alert: EncryptionAtRestDrift          # SOC 2 CC6.1 / GDPR Art.32
        expr: min(pg_storage_encrypted) < 1
        for: 1m
        labels: {severity: critical, control_id: "CC6.1", enforcement_mode: monitor}
        annotations:
          summary: "Encryption-at-rest disabled on a store — control CC6.1 no longer holds"

      - alert: MTLSCoverageDrift               # transport identity via Linkerd
        expr: (sum(rate(linkerd_tls_connections_total[5m]))
               / sum(rate(linkerd_connections_total[5m]))) < 1
        for: 5m
        labels: {severity: high, control_id: "CC6.6", enforcement_mode: monitor}
        annotations:
          summary: "mTLS coverage below 100% — some traffic is unauthenticated at transport"

      - alert: UntenantedQueryDrift            # SOC 2 CC6.3 tenant isolation
        expr: rate(db_queries_without_tenant_filter_total[5m]) > 0
        for: 0m
        labels: {severity: critical, control_id: "CC6.3", enforcement_mode: monitor}
        annotations:
          summary: "A query executed without a tenant filter — isolation control drifting"

      - alert: RawContentPersistedDrift        # product privacy invariant
        expr: rate(raw_content_bytes_written_total[5m]) > 0
        for: 0m
        labels: {severity: critical, control_id: "PRIV-RAW", enforcement_mode: monitor}
        annotations:
          summary: "Raw file content bytes written — only entity types+counts may persist"
```

### The drift → alert → fresh attestation loop

A CCM alert does two things, not one. It pages, **and** it writes a fresh drift
attestation to the same immutable ledger — so the operating-effectiveness story is
recorded continuously, drift and recovery included.

```go
// Alertmanager webhook handler: on a firing CCM alert, emit a FAIL drift
// attestation; on resolution, emit a PASS recovery attestation. Both land in the
// ledger, giving the Type II auditor a continuous record with the remediation arc.
func handleCCMAlert(ctx context.Context, a Alert) error {
    result := "FAIL"
    if a.Status == "resolved" {
        result = "PASS"
    }
    stmt := attest.Statement{
        Type:    "https://in-toto.io/Statement/v1",
        Subject: []attest.Subject{{Name: a.Labels["service"], Digest: currentDigest(a.Labels["service"])}},
        Predicate: attest.ControlPredicate{
            ControlID:       a.Labels["control_id"],
            EnforcementMode: "monitor",
            Result:          result,
            Details:         a.Annotations["summary"],
            Producer:        attest.Producer{Stage: "ccm", Identity: ccmSigningIdentity()},
            Timestamp:       time.Now().UTC(),
            Environment:     "production",
        },
    }
    return attest.Emit(ctx, stmt) // signed + appended to the same ledger as deploy-time attestations
}
```

Because drift attestations pin the currently-running artifact digest and share the
ledger with deploy-time attestations, the release chain (see
`references/attestation-and-evidence.md`) extends past the deploy boundary into
production — closing the gap between "passed at deploy" and "still holds today."

---

## Checklist

- [ ] Exactly one control-gate stage; no scattered `--exit-code 1` as the only enforcement.
- [ ] The gate consumes+verifies attestations for the promoted **digest**; it re-runs nothing.
- [ ] Gate fails closed on missing, invalid-signature, and unexcepted-FAIL controls.
- [ ] A signed accepted-risk exception is the only way a FAIL control passes the gate.
- [ ] The gate emits its own verdict as an attestation.
- [ ] SoD (author ≠ approver) is a `gate`-mode attested control, not a policy convention.
- [ ] `gate`/`monitor` controls have Prometheus rules over OTel signals.
- [ ] CCM alerts both page and emit a fresh drift/recovery attestation to the ledger.
- [ ] Retention windows and "raw content never persisted" are continuously monitored controls.
