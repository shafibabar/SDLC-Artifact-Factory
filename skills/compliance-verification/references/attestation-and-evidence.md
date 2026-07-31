# Attestation and Evidence Ledger

Reference for `compliance-verification`. Covers the attestation primitive (what it
pins and why), how attestations compose into a per-release evidence chain, the
immutable append-only ledger, and Go / CI emission with signature verification.

Grounded in the DevOps Automated Governance Reference Architecture (*Investments
Unlimited*) and the in-toto / SLSA attestation standards, applied to this repo's
Go + chi + pgx + Redpanda stack with per-tenant physical isolation and S3 object
lock. No control IDs, CVEs, or statistics are invented here; SOC 2 controls are
cited by their real CC-series names and GDPR by real article numbers only where a
control is illustrative.

---

## Why an attestation, not a flat evidence record

A flat evidence record is a test-pass boolean with some metadata bolted on:

```go
// The OLD shape — a result, not an attestation.
type EvidenceRecord struct {
    ControlID   string    `json:"controlId"`
    Framework   string    `json:"framework"`
    Result      string    `json:"result"`   // PASS / FAIL
    TestedAt    time.Time `json:"testedAt"`
    BuildID     string    `json:"buildId"`
    CommitSHA   string    `json:"commitSha"`
    Environment string    `json:"environment"`
}
```

Its weaknesses: any field can be written by anyone (no signature), it is not pinned
to the exact artifact it describes (a `CommitSHA` string, not a content digest), and
it is an isolated file — an auditor reads hundreds of them one by one with no way to
know they belong to the same release, and no way to verify they were not edited.

An **attestation** fixes all three. It is a *signed, machine-generated, composable
statement* — "control X was satisfied for artifact Y (pinned by digest) at time T by
process P" — whose provenance is intrinsic, not bolted on. It follows the in-toto
statement shape: a `subject` (what it is about, pinned by digest), a `predicate`
(what was checked and the result), and a signature envelope.

---

## What an attestation pins

Four things are intrinsic and non-negotiable. These are exactly what an auditor needs
to trust the record without trusting whoever produced it.

| Pin | Field | Why it matters |
|---|---|---|
| **Artifact digest** | `subject[].digest.sha256` | Binds the attestation to the *exact* bytes (image / build artifact). A commit string can be reused across builds; a content digest cannot. This is the join key that lets stages compose. |
| **Control id** | `predicate.controlId` | Traces the attestation back to a control in `compliance-design`. No control id ⇒ no coverage traceability. |
| **Signing identity** | DSSE envelope signature / Cosign identity | Makes the record verifiable and non-repudiable. Anyone can write JSON; only the pipeline's keyless-signing identity can sign it. |
| **Timestamp** | `predicate.timestamp` | Establishes *when* the control operated — the axis SOC 2 Type II assesses over a period. |

---

## Attestation shape (in-toto / SLSA-style)

```go
// Package attest emits in-toto-style, DSSE-signed control attestations.
package attest

import "time"

// Subject is what the attestation is ABOUT, pinned by content digest.
type Subject struct {
    Name   string            `json:"name"`   // e.g. "ghcr.io/acme/classifier"
    Digest map[string]string `json:"digest"` // {"sha256": "9f86d0…"}
}

// ControlPredicate is the in-toto predicate body for a compliance control.
type ControlPredicate struct {
    PredicateType string    `json:"predicateType"` // "https://compliance/control/v1"
    ControlID     string    `json:"controlId"`     // "CC6.3"
    Framework     string    `json:"framework"`     // "SOC 2"
    EnforcementMode string  `json:"enforcementMode"` // gate | monitor | record
    Result        string    `json:"result"`        // PASS | FAIL
    Details       string    `json:"details"`
    Producer      Producer  `json:"producer"`      // pipeline stage + identity
    Timestamp     time.Time `json:"timestamp"`
    CommitSHA     string    `json:"commitSha"`
    Environment   string    `json:"environment"`
}

type Producer struct {
    Stage    string `json:"stage"`    // "compliance-test" | "iac-scan" | "ccm"
    Identity string `json:"identity"` // OIDC subject of the CI signing identity
    RunURL   string `json:"runUrl"`   // link back to the CI run
}

// Statement is the in-toto envelope: one or more subjects + one predicate.
type Statement struct {
    Type          string           `json:"_type"`   // "https://in-toto.io/Statement/v1"
    Subject       []Subject        `json:"subject"`
    PredicateType string           `json:"predicateType"`
    Predicate     ControlPredicate `json:"predicate"`
}
```

The `FAIL` result is a first-class value, not an error to suppress. A FAIL
attestation followed by a remediation and a PASS re-run *is* the operating-effectiveness
narrative; both stay in the ledger.

---

## Emitting and signing in CI (Go + GitHub Actions)

Emission happens as a step in each pipeline stage. Signing uses Cosign keyless
(OIDC) so the signing identity is the workflow itself — no long-lived key to steal.

```go
// emit writes a signed attestation to the ledger. Called at the end of each
// compliance test / scan step.
func emit(ctx context.Context, s Statement) error {
    payload, err := json.Marshal(s)
    if err != nil {
        return fmt.Errorf("marshal statement: %w", err)
    }
    // Sign with Cosign keyless: the DSSE envelope is signed by the CI OIDC
    // identity (github.com/acme/.github/workflows/verify.yml@refs/heads/main).
    env, err := cosign.SignDSSE(ctx, payload)
    if err != nil {
        return fmt.Errorf("sign attestation: %w", err)
    }
    // Append to the immutable ledger (see below). Object key includes the
    // subject digest so the gate can query by digest.
    return ledger.Append(ctx, s.Subject[0].Digest["sha256"], s.Predicate.ControlID, env)
}
```

```yaml
# .github/workflows/verify.yml — attestation emission has id-token: write so the
# job can obtain the OIDC token Cosign keyless signing needs.
permissions:
  id-token: write   # keyless signing identity
  contents: read
jobs:
  compliance-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run compliance tests (emit attestations)
        run: go test ./tests/compliance/... -run TestCC -v
        env:
          IMAGE_DIGEST: ${{ needs.build.outputs.digest }}
          LEDGER_BUCKET: ${{ vars.EVIDENCE_LEDGER_BUCKET }}
```

---

## The control tests behind the attestations

Each control test executes the control, then calls `emit`. Three representative
tests for this repo's product:

```go
// SOC 2 CC6.1 — every endpoint requires authentication.
func TestCC61_AllEndpointsRequireAuth(t *testing.T) {
    for _, ep := range loadEndpointRegistry() { // from openapi.yaml; /healthz,/readyz excluded
        resp := executeRequest(t, buildRequest(ep.Method, ep.Path, nil)) // no Authorization header
        result := "PASS"
        if resp.StatusCode != http.StatusUnauthorized {
            result = "FAIL"
        }
        emitControl(t, "CC6.1", "SOC 2", "gate", result, ep.Method+" "+ep.Path)
    }
}

// SOC 2 CC6.3 — tenant isolation. Cross-tenant access must be 404, never 403.
func TestCC63_CrossTenantAccessDenied(t *testing.T) {
    assetID := createDataAsset(t, tenantA)
    req := buildRequest("GET", "/v1/data-assets/"+assetID.String(), nil)
    req.Header.Set("Authorization", "Bearer "+tenantBToken)
    resp := executeRequest(t, req)
    result := "PASS"
    if resp.StatusCode != http.StatusNotFound { // 404, not 403 — do not confirm existence
        result = "FAIL"
    }
    emitControl(t, "CC6.3", "SOC 2", "gate", result, "cross-tenant-access")
}

// GDPR Article 30 — every write operation produces an audit entry.
func TestGDPRArt30_AllWriteOperationsAudited(t *testing.T) {
    for _, op := range []func(){classifyDataAsset, connectStorageSource, generateReport} {
        before := countAuditEntries(t)
        op()
        result := "PASS"
        if countAuditEntries(t) <= before {
            result = "FAIL"
        }
        emitControl(t, "GDPR-Art30", "GDPR", "gate", result, "audit-completeness")
    }
}
```

Note the physical per-tenant isolation of this repo: CC6.3 is defended at the
infrastructure layer *and* re-verified here at the application layer — belt and
suspenders, both attested.

---

## How attestations compose into a per-release chain

The digest pin is the join key. A single image digest accumulates attestations from
every stage; together they form one verifiable governance narrative for that release.

```
subject digest sha256:9f86d0…  ← the promoted image
   ├── build-provenance      (SLSA provenance: how it was built)
   ├── CC6.1  auth           (compliance-test stage)     PASS
   ├── CC6.3  tenant-isolation(compliance-test stage)    PASS
   ├── GDPR-Art30 audit      (compliance-test stage)     PASS
   ├── encryption-at-rest    (iac-scan stage / OPA)      PASS
   ├── vuln-scan HIGH/CRIT   (trivy stage)               PASS
   └── SoD author≠approver   (change-mgmt stage)         PASS
```

An auditor (or the control gate) queries the ledger for *this digest* and traverses
the chain, rather than reading isolated JSON files and guessing which release they
belong to. Evidence assembly becomes a query, not a multi-week scramble.

---

## The immutable evidence ledger

The substrate is append-only S3 with **object lock in compliance mode** (WORM):
once written, an attestation cannot be overwritten or deleted, even by an
administrator, for the retention period. This is what makes the ledger a
tamper-evident audit deliverable rather than mutable storage someone can quietly
rewrite before an assessment.

```go
// Append is write-once: the object key encodes digest + control + timestamp, and
// the bucket enforces object lock, so a second write to the same key is rejected
// rather than overwriting. FAIL attestations are retained alongside PASS.
func (l *S3Ledger) Append(ctx context.Context, digest, controlID string, env []byte) error {
    key := fmt.Sprintf("attestations/%s/%s/%d.dsse.json", digest, controlID, time.Now().UnixNano())
    _, err := l.s3.PutObject(ctx, &s3.PutObjectInput{
        Bucket:                    &l.bucket,
        Key:                       &key,
        Body:                      bytes.NewReader(env),
        ObjectLockMode:            types.ObjectLockModeCompliance,
        ObjectLockRetainUntilDate: aws.Time(time.Now().AddDate(1, 0, 0)), // ≥ audit period
    })
    return err
}
```

Retention must meet or exceed the SOC 2 Type II audit period (typically 6–12 months)
so the ledger can show a control operated continuously across the whole period.

---

## Signature verification

Any consumer — the control gate, an auditor tool, a customer's security team —
verifies an attestation before trusting it. Verification checks the signature
against the *expected* CI signing identity, not merely that *some* signature exists.

```go
// Verify fails closed: an unsigned attestation, a signature from an unexpected
// identity, or a digest mismatch all return an error. The gate treats any error
// as "control not satisfied".
func Verify(ctx context.Context, env []byte, wantDigest, wantIdentity string) (*Statement, error) {
    stmt, id, err := cosign.VerifyDSSE(ctx, env) // checks signature + certificate identity
    if err != nil {
        return nil, fmt.Errorf("signature verification failed: %w", err)
    }
    if id != wantIdentity {
        return nil, fmt.Errorf("unexpected signer %q (want %q)", id, wantIdentity)
    }
    if stmt.Subject[0].Digest["sha256"] != wantDigest {
        return nil, fmt.Errorf("attestation subject digest does not match promoted artifact")
    }
    return stmt, nil
}
```

The verification result is itself attested by the control gate — see
`references/control-gate-and-ccm.md`.

---

## Checklist

- [ ] Every control test emits a signed attestation, not a flat JSON result.
- [ ] Each attestation pins the artifact **digest**, control id, signing identity, and timestamp.
- [ ] Signing is Cosign keyless (CI OIDC identity), no long-lived key.
- [ ] The ledger is append-only S3 with object lock in compliance mode; retention ≥ audit period.
- [ ] FAIL attestations are retained alongside PASS (the remediation story).
- [ ] Attestations from all stages share the release's image digest so they compose into one chain.
- [ ] Verification checks the signer *identity* and the subject digest, and fails closed.
