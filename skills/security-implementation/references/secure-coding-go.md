# Secure Coding in Go — Validation, Encoding, Headers, Secrets, Defaults

Full implementation reference for control categories 1 (input validation), 2 (output encoding), 5
(secrets), and 7 (secure defaults) of `security-implementation`, plus rate limiting and error handling.
Grounded in Janca (*Alice and Bob Learn Application Security*) and Adkins & Beyer (*Building Secure and
Reliable Systems*), applied to Go + chi + pgx + React + Redpanda.

---

## 1. Input Validation — Allowlist at Every Trust Boundary

**Allowlist over denylist, always.** A denylist (blocking known-bad characters) loses to any encoding it
missed; the only durable posture accepts exactly the known-good shape and rejects everything else.
Validate **type, length (min *and* max), range, format (an anchored `^...$` compiled regex), and set
membership** — never as a denylist of bad characters.

**Validate at every trust boundary, not just the HTTP handler.** A value from a Redpanda topic, from an
ingested Google Drive/S3 file's metadata, or from another service is equally untrusted and is
re-validated on entry. This is "parse, don't validate": turn an untrusted `string` into a validated
typed value **once**, at the edge, so downstream code receives only well-formed data.

```go
// internal/handlers/dto/classify_data_asset_request.go — HTTP boundary
type ClassifyDataAssetRequest struct {
    SensitivityLevel string `json:"sensitivityLevel"`
    ClassifiedBy     string `json:"classifiedBy"`
}

func (r ClassifyDataAssetRequest) Validate() []ValidationError {
    var errs []ValidationError
    // Set-membership allowlist, converted to a domain type in one step.
    level := domain.SensitivityLevel(r.SensitivityLevel)
    if !level.IsValid() { // IsValid enumerates the known-good set, not a bad-list
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

```go
// internal/messaging/consumer.go — Redpanda boundary: SAME allowlist discipline
func (c *ClassificationConsumer) handle(ctx context.Context, msg *kgo.Record) error {
    var evt IngestedFileEvent
    if err := json.Unmarshal(msg.Value, &evt); err != nil {
        return c.deadLetter(ctx, msg, "malformed payload") // reject, don't process
    }
    // A file name from an ingested document is untrusted here just as at the HTTP edge.
    name, err := domain.NewFileName(evt.FileName) // allowlist: length, charset, no path traversal
    if err != nil {
        return c.deadLetter(ctx, msg, "invalid file name")
    }
    // ... only well-formed, typed values proceed
}
```

**Rules:** validate at the boundary before anything else runs; return all field errors in one response,
not one at a time; never echo user input back in an error message without encoding it.

---

## 2. Output Encoding — Contextual, at the Sink

Output encoding is a **separate control from input validation** and neither substitutes for the other
(Janca). Injection is fundamentally an *output* problem: a value that was perfectly valid as input
becomes dangerous when interpolated into a different interpreter's syntax. The correct encoding depends
entirely on **where the value lands** — a single value ingested from an untrusted document can need three
different encodings on three different sinks.

| Sink | Encoding | Rule for this repo |
|---|---|---|
| **HTML / JS body (React)** | HTML-entity / JS-string escaping | Rely on React's default JSX escaping; **never** `dangerouslySetInnerHTML` on any ingested value (file names, document content, extracted-entity labels) |
| **SQL** | Parameterization | pgx `$N` always — never `fmt.Sprintf`; a fixed allowlist map for identifiers (table/column/ORDER BY) |
| **HTTP response header** | CR/LF stripping | Strip `\r`/`\n` from any value placed into a header (header-injection / response splitting) |
| **Log line** | Log-line encoding | Encode newlines/control chars so an ingested file name cannot forge a log line (log injection) |
| **URL / query param** | URL-encoding | `url.QueryEscape` for any value placed into a constructed URL |

```go
// CORRECT: parameterized query — the SQL sink
func (r *DataAssetRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    row := r.pool.QueryRow(ctx,
        `SELECT id, file_path, sensitivity_level, tenant_id, version
         FROM data_assets
         WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL`,
        id, tenantIDFromContext(ctx),
    )
    return scanDataAsset(row)
}

// WRONG — never: string concatenation makes the value part of the SQL syntax
// query := "SELECT * FROM data_assets WHERE id = '" + id.String() + "'"
```

Additional SQL rules: never `fmt.Sprintf` to build a query; use `pgx.Batch` for multiple statements —
no dynamic SQL; every query carries `tenant_id = $N` as the backstop for the ABAC check.

Treat ingested document content, file names, and extracted-entity labels as untrusted at **every** one
of these sinks simultaneously.

---

## 3. Security Headers Middleware

```go
// internal/handlers/middleware/security_headers.go
func SecurityHeaders(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("X-Frame-Options", "DENY")
        w.Header().Set("Content-Security-Policy", "default-src 'none'") // secure default: deny, opt into src
        w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
        w.Header().Set("Referrer-Policy", "no-referrer")
        w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
        w.Header().Del("X-Powered-By") // remove server fingerprinting
        w.Header().Del("Server")
        next.ServeHTTP(w, r)
    })
}
```

---

## 4. Rate Limiting

```go
// Per-user rate limiting using golang.org/x/time/rate.
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

Default limits: 100 req/min standard endpoints; 10 req/min write endpoints.

**Two hardening notes:**

- The `sync.Map` grows one entry per user forever — evict idle limiters on a timer (track last-seen,
  sweep entries older than ~10 minutes) or a slow enumeration attack becomes a memory leak.
- Unauthenticated endpoints (login, token refresh) cannot key on user ID — rate-limit those by client IP
  at the ingress, since they are exactly what credential-stuffing targets.

Rate limiting is also a **recovery** lever (BSRS): it slows an in-progress attack and buys detection
time, not just a throughput cap.

---

## 5. Error Handling That Does Not Leak

- Return a stable error code + a generic message to the client; the specific reason (which tenant, which
  claim, which SQL error) goes to the server log only.
- Verbose errors, stack traces, and framework/version strings are **off** in production responses.
- One `ErrForbidden` outward for every authorization denial — never distinguish "wrong tenant" vs
  "missing permission" vs "not found" to the caller (that difference is an enumeration oracle).

---

## 6. Secrets Handling

Secrets (DB passwords, API keys, signing keys) never live in source, in committed config, or in logs —
they come from a secrets manager or injected environment and are rotated (Janca). Construct the
redacting `Secret` type **at the point of read**, so an unwrapped secret `string` never flows through
application code (*Secure by Design* totality, applied one level earlier — see `secrets-management`):

```go
// internal/infrastructure/secrets/secret.go
// loadDatabaseURL returns Secret, NOT string — the redaction guarantee starts at read,
// not wherever a developer remembers to wrap it.
func loadDatabaseURL() (Secret, error) {
    raw, ok := os.LookupEnv("DATABASE_URL")
    if !ok {
        return Secret{}, errors.New("DATABASE_URL not set")
    }
    return NewSecret(raw), nil
}

// Secret redacts itself on every serialization path so it cannot reach a log even by mistake.
func (s Secret) String() string        { return "[REDACTED]" }
func (s Secret) GoString() string      { return "[REDACTED]" }
func (s Secret) LogValue() slog.Value  { return slog.StringValue("[REDACTED]") }
func (s Secret) MarshalJSON() ([]byte, error) { return []byte(`"[REDACTED]"`), nil }
```

---

## 7. Secure Defaults & Least-Privilege API Design

The out-of-the-box configuration is the safe one — an operator opts *into* risk, never out of exposure
(Janca). Adkins & Beyer sharpen this: hardening is a **secure-default posture a new service inherits**,
not a per-service checklist someone must remember.

**Secure-default posture a new service inherits (the template, not a checklist):**

- Deny-by-default ABAC middleware, in the load-bearing order `security headers → auth → rate limit →
  handler`.
- `Content-Security-Policy: default-src 'none'` and the full header set on by default.
- Least functionality: unused features/endpoints removed, verbose errors off, no default/sample creds.
- Least-privilege DB role per concern (the audit-log INSERT-only role is the model — see
  `references/audit-and-evidence.md`).
- Non-root `SecurityContext`, default-deny `NetworkPolicy`, mTLS enforced by Linkerd.
- Relaxation of any of the above is the **logged, reviewed exception**, not the default.

**Least-privilege API surface.** Expose narrow, intent-named operations (`ClassifyDataAsset`,
`ExtractEntities`) rather than a general-purpose `RunQuery`/`ExecuteJob`. The privilege a compromised
caller can wield is bounded by the surface it can reach; audit each service's public API for any
operation broad enough that holding it grants more authority than the caller's role needs.
