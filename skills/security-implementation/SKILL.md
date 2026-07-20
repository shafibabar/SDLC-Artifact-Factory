---
name: security-implementation
description: >
  Teaches the security-engineer how to implement security controls in Go services
  — covering JWT middleware implementation, ABAC policy enforcement in Go,
  parameterised queries to prevent SQL injection, input sanitisation, secure
  HTTP headers, rate limiting, audit log implementation with Non-Repudiation,
  and the Go security libraries to use (and avoid). This skill translates
  security-architect designs into working, auditable Go code. Used by the
  security-engineer agent during the Implement phase.
version: 1.1.0
phase: implement
owner: security-engineer
created: 2026-06-25
tags: [implement, security, go, jwt, abac, sql-injection, audit-log, rate-limiting]
---

# Security Implementation

## Purpose

Security implementation translates the security architecture designs into working Go code. Every control defined in the `security-architecture` skill has a corresponding implementation pattern in this skill. Security controls are not reviewed after the fact — they are built correctly the first time, tested, and verified as part of the implementation.

---

## JWT Middleware (Go)

```go
// internal/handlers/middleware/auth.go

import (
    "github.com/lestrrat-go/jwx/v2/jwk"
    "github.com/lestrrat-go/jwx/v2/jwt"
)

type AuthMiddleware struct {
    keySet jwk.Set
    audience string
    issuer   string
}

func NewAuthMiddleware(ctx context.Context, jwksURL, audience, issuer string) (*AuthMiddleware, error) {
    // jwk.Cache re-fetches the JWKS in the background, so signing-key rotation
    // needs no restart. A one-shot jwk.Fetch would pin the keys forever.
    cache := jwk.NewCache(ctx)
    if err := cache.Register(jwksURL, jwk.WithMinRefreshInterval(15*time.Minute)); err != nil {
        return nil, fmt.Errorf("registering JWKS URL: %w", err)
    }
    // Prime the cache so a bad URL fails at startup, not on the first request
    if _, err := cache.Refresh(ctx, jwksURL); err != nil {
        return nil, fmt.Errorf("fetching JWKS: %w", err)
    }
    return &AuthMiddleware{keySet: jwk.NewCachedSet(cache, jwksURL), audience: audience, issuer: issuer}, nil
}

func (m *AuthMiddleware) Handler(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        tok, err := jwt.ParseRequest(r,
            jwt.WithKeySet(m.keySet),
            jwt.WithAudience(m.audience),
            jwt.WithIssuer(m.issuer),
            jwt.WithValidate(true),
        )
        if err != nil {
            writeError(w, http.StatusUnauthorized, "AUTHENTICATION_REQUIRED", "Valid authentication token required")
            return
        }
        ctx := context.WithValue(r.Context(), ctxKeyToken, tok)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

// Extract subject from context — called in handlers.
// Every claim is checked: a validly-signed token with a missing or malformed
// claim must produce an error, never a panic (no MustParse, no bare type
// assertions — a panic here is an attacker-triggerable denial of service).
func SubjectFromContext(ctx context.Context) (domain.Subject, error) {
    tok, ok := ctx.Value(ctxKeyToken).(jwt.Token)
    if !ok {
        return domain.Subject{}, ErrNoSubjectInContext
    }
    userID, err := uuid.Parse(tok.Subject())
    if err != nil {
        return domain.Subject{}, ErrMalformedToken
    }
    rawTenant, ok := tok.PrivateClaims()["tenant_id"].(string)
    if !ok {
        return domain.Subject{}, ErrMalformedToken
    }
    tenantID, err := uuid.Parse(rawTenant)
    if err != nil {
        return domain.Subject{}, ErrMalformedToken
    }
    permissions, err := toStringSlice(tok.PrivateClaims()["permissions"])
    if err != nil {
        return domain.Subject{}, ErrMalformedToken
    }
    return domain.Subject{
        ID:          userID,
        TenantID:    tenantID,
        Permissions: permissions,
    }, nil
}
```

**Library:** `github.com/lestrrat-go/jwx/v2` — supports RS256, JWKS caching with background refresh for key rotation.

**JWT validation pitfalls this middleware must not fall into:**
- **Algorithm pinning:** the accepted algorithm comes from the server's JWKS keys, never from the token's `alg` header. Publishing only RSA keys with `alg: RS256` in the JWKS prevents `alg: none` and RS256→HS256 confusion attacks.
- **Audience and issuer are mandatory.** A token minted for another service in the same identity domain validates against the same JWKS — only `aud`/`iss` checks stop cross-service token replay.
- **Require `exp`.** A token without an expiry claim must be rejected, not treated as never-expiring.
- **Clock skew:** allow a small acceptance skew (≤ 2 minutes, `jwt.WithAcceptableSkew`) — no more, or "short-lived" tokens quietly stop being short-lived.

---

## ABAC Policy Enforcement (Go)

```go
// internal/domain/policy.go

type AccessPolicy interface {
    Evaluate(ctx context.Context, sub Subject, res Resource, act Action) error
}

type ABACPolicy struct {
    assetRepo DataAssetRepository
}

func (p *ABACPolicy) Evaluate(ctx context.Context, sub Subject, res Resource, act Action) error {
    // Rule 1: Tenant isolation — always first, always non-negotiable
    if sub.TenantID != res.TenantID {
        return ErrForbidden // never distinguish "wrong tenant" from "no permission"
    }

    // Rule 2: Permission check
    requiredPerm := act.RequiredPermission()
    if !sub.HasPermission(requiredPerm) {
        return ErrForbidden
    }

    return nil
}

// internal/application/commands/classify_data_asset.go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return ErrUnauthenticated
    }

    // Load resource to get its tenant_id for policy evaluation
    asset, err := h.repo.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return err
    }

    resource := domain.Resource{
        Type:     "data-asset",
        ID:       cmd.DataAssetID,
        TenantID: asset.TenantID(),
    }
    action := domain.Action{Operation: "classify-data-asset"}

    if err := h.policy.Evaluate(ctx, sub, resource, action); err != nil {
        return err // ErrForbidden — do not reveal why
    }

    // Proceed with the command
    return asset.Classify(cmd)
}
```

---

## SQL Injection Prevention

All database queries use parameterised queries via pgx. String concatenation in SQL is prohibited.

```go
// CORRECT: parameterised query
func (r *DataAssetRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    row := r.pool.QueryRow(ctx,
        `SELECT id, file_path, sensitivity_level, tenant_id, version
         FROM data_assets
         WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL`,
        id, tenantIDFromContext(ctx),
    )
    return scanDataAsset(row)
}

// WRONG: string concatenation — never do this
query := "SELECT * FROM data_assets WHERE id = '" + id.String() + "'"
```

**Additional rules:**
- Never use `fmt.Sprintf` to build SQL queries
- Use `pgx.Batch` for multiple queries in a transaction — no dynamic SQL
- All queries specify the `tenant_id` parameter — the parameterised tenant filter is the backstop for the ABAC check

---

## Input Validation

Two-layer validation (structural then business — see `command-catalog` skill). The structural validation layer:

```go
// internal/handlers/dto/classify_data_asset_request.go

type ClassifyDataAssetRequest struct {
    SensitivityLevel string `json:"sensitivityLevel"`
    ClassifiedBy     string `json:"classifiedBy"`
}

func (r ClassifyDataAssetRequest) Validate() []ValidationError {
    var errs []ValidationError
    level := domain.SensitivityLevel(r.SensitivityLevel)
    if !level.IsValid() {
        errs = append(errs, ValidationError{
            Field:   "sensitivityLevel",
            Message: "must be one of: Public, Internal, Confidential, Restricted",
        })
    }
    if _, err := uuid.Parse(r.ClassifiedBy); err != nil {
        errs = append(errs, ValidationError{Field: "classifiedBy", Message: "must be a valid UUID"})
    }
    return errs
}
```

**Rules:**
- Validate at the boundary — handler only, before anything else runs
- Reject on the first invalid field batch — return all errors in one response, not one at a time
- Never trust client-provided data: validate type, range, format, and length
- Never echo user input back in error messages without sanitisation

---

## Secure HTTP Headers

```go
// internal/handlers/middleware/security_headers.go

func SecurityHeaders(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("X-Frame-Options", "DENY")
        w.Header().Set("Content-Security-Policy", "default-src 'none'")
        w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
        w.Header().Set("Referrer-Policy", "no-referrer")
        w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
        // Remove server fingerprinting
        w.Header().Del("X-Powered-By")
        w.Header().Del("Server")
        next.ServeHTTP(w, r)
    })
}
```

---

## Rate Limiting

```go
// Per-user rate limiting using golang.org/x/time/rate
// Applied at the API Gateway level and at individual sensitive endpoints

import "golang.org/x/time/rate"

type RateLimiter struct {
    limiters sync.Map // map[string]*rate.Limiter
    rate     rate.Limit
    burst    int
}

func (rl *RateLimiter) getLimiter(userID string) *rate.Limiter {
    v, _ := rl.limiters.LoadOrStore(userID, rate.NewLimiter(rl.rate, rl.burst))
    return v.(*rate.Limiter)
}

func (rl *RateLimiter) Middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        userID := SubjectIDFromContext(r.Context())
        if !rl.getLimiter(userID.String()).Allow() {
            writeError(w, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED",
                "Too many requests. Please retry after a moment.")
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

Default rate limits: 100 requests/minute for standard endpoints; 10 requests/minute for write endpoints.

**Two hardening notes:**
- The `sync.Map` of limiters grows one entry per user forever — evict idle limiters on a timer (track last-seen and sweep entries older than ~10 minutes), or a slow enumeration attack becomes a memory leak.
- Unauthenticated endpoints (login, token refresh) cannot key on user ID — rate-limit those by client IP at the ingress, since they are exactly the endpoints credential-stuffing targets.

---

## Audit Log Implementation with Non-Repudiation

```go
// internal/infrastructure/audit/log.go

type AuditEntry struct {
    ID                 uuid.UUID  `db:"id"`
    EventType          string     `db:"event_type"`
    AggregateID        uuid.UUID  `db:"aggregate_id"`
    AggregateType      string     `db:"aggregate_type"`
    ActorID            uuid.UUID  `db:"actor_id"`
    TenantID           uuid.UUID  `db:"tenant_id"`
    OccurredAt         time.Time  `db:"occurred_at"`
    Payload            []byte     `db:"payload"`
    NonRepudiationHash string     `db:"non_repudiation_hash"` // SHA-256 of previous entry hash + this entry's payload
}

func (r *AuditRepository) Append(ctx context.Context, entry AuditEntry) error {
    // Get the hash of the previous entry (for hash chain)
    var prevHash string
    err := r.pool.QueryRow(ctx,
        `SELECT non_repudiation_hash FROM audit_log
         WHERE tenant_id = $1 ORDER BY occurred_at DESC LIMIT 1`,
        entry.TenantID,
    ).Scan(&prevHash)
    if err != nil && !errors.Is(err, pgx.ErrNoRows) {
        return fmt.Errorf("getting previous hash: %w", err)
    }

    // Compute the hash chain link
    h := sha256.New()
    h.Write([]byte(prevHash))
    h.Write(entry.Payload)
    entry.NonRepudiationHash = hex.EncodeToString(h.Sum(nil))

    // Append-only insert — no UPDATE or DELETE allowed on this table
    _, err = r.pool.Exec(ctx,
        `INSERT INTO audit_log (id, event_type, aggregate_id, aggregate_type,
            actor_id, tenant_id, occurred_at, payload, non_repudiation_hash)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        entry.ID, entry.EventType, entry.AggregateID, entry.AggregateType,
        entry.ActorID, entry.TenantID, entry.OccurredAt, entry.Payload, entry.NonRepudiationHash,
    )
    return err
}
```

**Audit log database role:** A dedicated PostgreSQL role for the audit log table has `INSERT` privilege only — no `UPDATE` or `DELETE`. Even a fully compromised service account cannot delete audit entries.

**Hash-chain concurrency:** two concurrent appends that read the same previous hash fork the chain, and verification then fails for honest reasons. Serialise appends per tenant inside the insert transaction — `SELECT pg_advisory_xact_lock(hashtext($1::text))` on the tenant ID before reading the previous hash — and order the chain by a monotonic `BIGSERIAL` sequence column, not by `occurred_at` (timestamps can tie or arrive out of order).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| JWT middleware uses RS256 | `jwt.WithKeySet` with RSA keys; HS256 not used | HS256 or no algorithm constraint |
| ABAC in Application layer | Policy evaluated in command/query handlers | Policy only at API layer (bypassable) |
| Parameterised queries only | All pgx queries use `$N` parameters | Any `fmt.Sprintf` or string concatenation in SQL |
| Security headers set | All headers from the list applied | Missing HSTS, CSP, or X-Content-Type-Options |
| Audit log append-only | PostgreSQL role has INSERT only; no UPDATE/DELETE | Audit table modified by the application role |
| Rate limiting applied | All write endpoints have rate limiting | Write endpoints with no rate limiting |
| No panics on malformed input | Claim extraction returns errors; no `MustParse` or bare type assertions on token data | Attacker-controlled data can panic a handler |
| JWKS refresh | Key set cached with background refresh | One-shot JWKS fetch pinned for process lifetime |

---

## Anti-Patterns

- **Trusting the token's `alg` header.** Letting the token declare its own algorithm enables `alg: none` and RS256→HS256 key-confusion attacks. The server decides the algorithm via its JWKS.
- **`MustParse` on claim data.** Any `Must*` or unchecked type assertion on values an attacker can put in a token is a remote panic waiting to happen.
- **Distinguishing denial reasons.** Returning "wrong tenant" vs "missing permission" vs "resource not found" as different errors from the policy. One `ErrForbidden` outward; the specific reason goes to the server log only.
- **`fmt.Sprintf` SQL "just this once".** Dynamic table names, ORDER BY columns built from user input, or IN-lists assembled by string join. pgx `$N` parameters for values; a fixed allowlist map for identifiers — never interpolated input.
- **Tenant filter only in the policy.** Queries without `tenant_id = $N` in the WHERE clause rely on a single control. The SQL filter is the backstop when the policy layer has a bug — defence in depth applies inside the repository too.
- **Logging the token.** Writing the Authorization header, the raw JWT, or decoded claims into request logs. A leaked log becomes a replayable credential store until every token expires.
- **Security middleware ordering by accident.** Rate limiting keyed on user ID placed before authentication reads an empty subject and collapses all anonymous traffic into one bucket. Order explicitly: security headers → auth → rate limit → handler.
- **Audit write after response.** Fire-and-forget audit logging that can silently fail leaves gaps in the Non-Repudiation chain. The audit insert commits in the same transaction as the state change, or the state change does not happen.

---

## Output Format

This skill produces the actual Go code files, not a design document. Implementation outputs are:

```
internal/handlers/middleware/auth.go
internal/handlers/middleware/security_headers.go
internal/handlers/middleware/rate_limiter.go
internal/domain/policy.go
internal/infrastructure/audit/log.go
tests/security/auth_test.go
tests/security/abac_test.go
tests/security/sql_injection_test.go
```
