# Security Audit Log & Pipeline Attestations

Full implementation reference for control category 6 (security logging) and the audit/attestation
*deliverables* of `security-implementation`. The audit log and the signed CI attestations are code this
skill produces — they feed the evidence ledger `compliance-verification` consumes. Grounded in Janca
(*Alice and Bob Learn Application Security*, the log dual-discipline), Adkins & Beyer (*Building Secure
and Reliable Systems*, recovery + integrity), and Shostack (*Threat Modeling*, Repudiation).

---

## 1. What to Log — and What Never To

Logging has a dual nature: it is both a detection tool and, if mishandled, a fresh disclosure sink
(Janca).

**DO log — security-relevant events, with enough context to investigate:**

- Authentication outcome (success **and** failure)
- Authorization denials (every `ErrForbidden`, with the deciding attributes)
- Input-validation rejections
- Privilege changes and breakglass activation
- Every ABAC allow *and* deny (Zero Trust: the control-plane decision must be observable)

**NEVER log:**

- Secrets, signing keys, the `Authorization` header, or the raw JWT — a leaked log becomes a replayable
  credential store until every token expires
- Session tokens
- **PII or raw file content.** This platform extracts PII entities but persists only entity *types* and
  *counts* — raw file contents are NEVER persisted, and that constraint extends to logs. A debug log
  that captures raw extracted text is a disclosure sink that bypasses the storage restriction
  (cross-reference `privacy-design`).

**Encode user-controlled values before they hit a log** — a newline in an ingested file name must not
forge a log line (log injection). Route security events through a **redacting logger** (the `Secret`
type pattern) so a token or PII value can never be serialized into a log even by mistake. Alert on
denial spikes (credential stuffing, enumeration).

---

## 2. The Append-Only, Hash-Chained Audit Log (Non-Repudiation)

Repudiation (STRIDE) is discharged by an immutable audit trail. Each entry links to the previous one via
a hash chain, so a deleted or altered entry breaks the chain and is detectable.

```go
// internal/infrastructure/audit/log.go
type AuditEntry struct {
    ID                 uuid.UUID `db:"id"`
    Seq                int64     `db:"seq"`          // monotonic BIGSERIAL — the chain order
    EventType          string    `db:"event_type"`
    AggregateID        uuid.UUID `db:"aggregate_id"`
    AggregateType      string    `db:"aggregate_type"`
    ActorID            uuid.UUID `db:"actor_id"`
    TenantID           uuid.UUID `db:"tenant_id"`
    OccurredAt         time.Time `db:"occurred_at"`
    Payload            []byte    `db:"payload"`      // structured fields — NEVER PII/secrets
    NonRepudiationHash string    `db:"non_repudiation_hash"` // SHA-256(prev hash + this payload)
}

func (r *AuditRepository) Append(ctx context.Context, entry AuditEntry) error {
    tx, err := r.pool.Begin(ctx)
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    // Serialise appends per tenant so two concurrent appends can't read the same
    // previous hash and fork the chain.
    if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext($1::text))`,
        entry.TenantID.String()); err != nil {
        return fmt.Errorf("acquiring per-tenant audit lock: %w", err)
    }

    var prevHash string
    err = tx.QueryRow(ctx,
        `SELECT non_repudiation_hash FROM audit_log
         WHERE tenant_id = $1 ORDER BY seq DESC LIMIT 1`, // order by seq, NOT occurred_at
        entry.TenantID,
    ).Scan(&prevHash)
    if err != nil && !errors.Is(err, pgx.ErrNoRows) {
        return fmt.Errorf("getting previous hash: %w", err)
    }

    h := sha256.New()
    h.Write([]byte(prevHash))
    h.Write(entry.Payload)
    entry.NonRepudiationHash = hex.EncodeToString(h.Sum(nil))

    // Append-only insert — no UPDATE or DELETE on this table.
    if _, err := tx.Exec(ctx,
        `INSERT INTO audit_log (id, event_type, aggregate_id, aggregate_type,
            actor_id, tenant_id, occurred_at, payload, non_repudiation_hash)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        entry.ID, entry.EventType, entry.AggregateID, entry.AggregateType,
        entry.ActorID, entry.TenantID, entry.OccurredAt, entry.Payload, entry.NonRepudiationHash,
    ); err != nil {
        return err
    }
    return tx.Commit(ctx)
}
```

**Two invariants that make it real:**

- **Dedicated INSERT-only Postgres role.** The audit-log role has `INSERT` privilege only — no `UPDATE`,
  no `DELETE`. Even a fully compromised service account cannot delete or alter audit entries.
- **Audit commits in the same transaction as the state change** it records — a fire-and-forget audit
  write that can silently fail leaves gaps in the chain. Either the audit insert and the state change
  both commit, or neither does. (This is why `BreakglassService.Activate` in
  `references/authn-authz.md` refuses to grant if it cannot audit.)

**Hash-chain concurrency:** order the chain by the monotonic `BIGSERIAL` `seq`, not by `occurred_at`
(timestamps can tie or arrive out of order), and take the per-tenant advisory lock before reading the
previous hash so honest concurrent appends cannot fork the chain and cause verification to fail for
non-malicious reasons.

**Verification** walks the chain in `seq` order, recomputing `SHA-256(prev_hash + payload)` for each
entry and asserting it equals the stored hash — a mismatch localizes the tampered or missing entry.

---

## 3. Pipeline Attestations — Signed Provenance from CI (A08)

Software & Data Integrity Failures (OWASP A08, STRIDE Tampering) are discharged by proving *what was
built, from what source, by which pipeline*. Emit a **signed attestation** (SLSA / in-toto-style
provenance — real, public supply-chain standards) from GitHub Actions as an implementation deliverable
that feeds the evidence ledger:

```yaml
# .github/workflows/attest.yml (excerpt)
permissions:
  id-token: write        # OIDC identity for keyless signing
  attestations: write
  contents: read
jobs:
  build-and-attest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t "$IMAGE" .
      - name: Generate signed provenance attestation
        uses: actions/attest-build-provenance@v1
        with:
          subject-name: "$IMAGE"
          subject-digest: "${{ steps.build.outputs.digest }}"
          # Produces an in-toto provenance statement, keyless-signed via Sigstore/OIDC.
```

The attestation records the source commit, the builder identity, and the artifact digest, signed with a
short-lived OIDC-derived key (no long-lived signing secret to leak — consistent with the zero-trust
short-credential posture). A deploy gate verifies the attestation before admitting the image, so an
unsigned or provenance-mismatched artifact cannot reach production.

---

## 4. Evidence for compliance-verification

Both artifacts above are *verifiable* SOC 2 evidence, not design assertions — the point Adkins & Beyer
make about auditing that privileged access flowed only through the designed, logged path:

| Control | Verifiable artifact | SOC 2 relevance |
|---|---|---|
| Non-repudiation | Hash-chained, INSERT-only audit log; chain verifies | Logging & monitoring; integrity of the audit record |
| Breakglass discipline | Every emergency-access event traces to a breakglass audit entry | Restricted/privileged access is auditable, not ambient |
| Per-request authorization | OTel spans recording subject, workload identity, resource, action, trust signals | Access control enforced *continuously*, not point-in-time config |
| Build integrity | Signed SLSA/in-toto provenance per artifact, verified at deploy | Change management; only trusted builds reach production |

"Every emergency-access event traces to a breakglass audit entry" is a stronger control than "admin
access is restricted," and "the audit chain verifies" is stronger than "we keep logs" — each names a
mechanical check `compliance-verification` can run, not a claim it must take on trust.
