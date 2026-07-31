# Authentication & Authorization — Go Patterns

Full implementation reference for control categories 3 (authentication & sessions) and 4
(authorization) of `security-implementation`. Grounded in Janca (*Alice and Bob Learn Application
Security*), Gilman & Barth (*Zero Trust Networks*), Adkins & Beyer (*Building Secure and Reliable
Systems*), and Johnsson/Deogun/Sawano (*Secure by Design*), applied to this repo's Go + chi + pgx +
Linkerd stack.

---

## 1. JWT Validation Middleware (chi)

The IdP mints RS256 JWTs carrying `sub`, `tenant_id`, `roles`, and `permissions`. The service validates
them against the IdP's published JWKS. Algorithm is pinned by the *server's* keys, never by the token's
`alg` header.

```go
// internal/handlers/middleware/auth.go
import (
    "github.com/lestrrat-go/jwx/v2/jwk"
    "github.com/lestrrat-go/jwx/v2/jwt"
)

type AuthMiddleware struct {
    keySet   jwk.Set
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
    // Prime the cache so a bad URL fails at startup, not on the first request.
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
            jwt.WithAcceptableSkew(2*time.Minute), // no more, or "short-lived" stops meaning short-lived
        )
        if err != nil {
            writeError(w, http.StatusUnauthorized, "AUTHENTICATION_REQUIRED", "Valid authentication token required")
            return
        }
        ctx := context.WithValue(r.Context(), ctxKeyToken, tok)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

**Library:** `github.com/lestrrat-go/jwx/v2` — RS256, JWKS caching with background refresh for key
rotation.

**Validation pitfalls this middleware must not fall into:**

- **Algorithm pinning.** The accepted algorithm comes from the server's JWKS keys, never the token's
  `alg`. Publishing only RSA keys with `alg: RS256` prevents `alg: none` and RS256→HS256 confusion.
- **`aud` / `iss` are mandatory.** A token minted for another service in the same identity domain
  validates against the same JWKS — only `aud`/`iss` checks stop cross-service token replay.
- **Require `exp`.** A token with no expiry is rejected, not treated as never-expiring.
- **Clock skew ≤ 2 minutes.** More, and short-lived tokens quietly stop being short-lived.

---

## 2. One Constructor for the Subject, Not Two

The middleware above stores the validated `jwt.Token`. Turning that token into a domain `Subject` is a
**single** construction path shared with `access-control-model`'s `SubjectFromContext(ctx)` — **one
constructor, not two** independent parses of the same claims. Two parsers that can drift on how a token
becomes a `Subject` are a latent authorization bug (*Secure by Design* — totality: validity is a *type*
guarantee established once, at the boundary; downstream code never re-checks).

The `Subject` is built from Domain Primitives (`TenantID`, `Permission`) so a malformed tenant ID or an
off-shape permission cannot exist once constructed:

```go
// internal/domain/subject.go — THE single claims→Subject path.
// access-control-model's SubjectFromContext calls this; the middleware does not
// build a Subject a second, different way.
func SubjectFromContext(ctx context.Context) (Subject, error) {
    tok, ok := ctx.Value(ctxKeyToken).(jwt.Token)
    if !ok {
        return Subject{}, ErrNoSubjectInContext
    }
    // Every claim is checked: a validly-signed token with a missing or malformed
    // claim returns an error, never panics. No MustParse, no bare type assertions
    // on token data — a panic here is an attacker-triggerable denial of service.
    userID, err := uuid.Parse(tok.Subject())
    if err != nil {
        return Subject{}, ErrMalformedToken
    }
    rawTenant, ok := tok.PrivateClaims()["tenant_id"].(string)
    if !ok {
        return Subject{}, ErrMalformedToken
    }
    tenantID, err := NewTenantID(rawTenant) // Domain Primitive constructor — the totality guarantee
    if err != nil {
        return Subject{}, ErrMalformedToken
    }
    perms, err := toPermissions(tok.PrivateClaims()["permissions"]) // []Permission, each validated
    if err != nil {
        return Subject{}, ErrMalformedToken
    }
    return Subject{ID: userID, TenantID: tenantID, Permissions: perms}, nil
}
```

Discarding the constructor error (`tid, _ := NewTenantID(raw)`) silently reintroduces the illegal-state
risk the pattern exists to prevent — Go has no automatic exception propagation, so a discarded error is
a *sharper* failure mode here than in the book's Java examples, not a weaker one.

---

## 3. Session & Cookie Hardening (A07)

Even in a JWT/JWKS architecture, session-lifecycle reasoning applies to refresh tokens and any
browser-held cookie (Janca):

- **Cookie flags.** Any cookie this platform sets (refresh token, CSRF token) gets
  `HttpOnly; Secure; SameSite=Strict` (or `Lax` where cross-site navigation is required) so client
  script cannot read it and it never traverses plaintext.
- **Session-fixation defence.** Regenerate the session identifier / rotate the refresh token *on*
  authentication and *on* privilege change — never continue a pre-auth identifier.
- **Timeouts.** Enforce both an idle timeout and an absolute timeout; a refresh token has an absolute
  expiry and is revocable server-side.
- **Logout invalidates server-side state**, not merely the client cookie.

Password storage and MFA are the IdP's responsibility, but state them as constraints on whatever IdP
mints these JWTs: passwords stored only as salted adaptive hashes (bcrypt/argon2/scrypt — never fast
hashes, never encryption, never plaintext); MFA offered and treated as the highest-leverage control
against credential stuffing.

---

## 4. Server-Side ABAC Enforcement — Deny by Default

Authorization decisions live in the application layer (control plane), re-checked on **every** request,
defaulting to **deny** — the absence of an explicit grant is a denial, never a fallthrough allow.

```go
// internal/domain/policy.go
type AccessPolicy interface {
    Evaluate(ctx context.Context, sub Subject, res Resource, act Action) error
}

type ABACPolicy struct{ assetRepo DataAssetRepository }

func (p *ABACPolicy) Evaluate(ctx context.Context, sub Subject, res Resource, act Action) error {
    // Rule 1: Tenant isolation — always first, always non-negotiable.
    // TenantID.Equal is total: an invalid TenantID cannot exist by construction.
    if !sub.TenantID.Equal(res.TenantID) {
        return ErrForbidden // never distinguish "wrong tenant" from "no permission"
    }
    // Rule 2: Permission check.
    if !sub.HasPermission(act.RequiredPermission()) {
        return ErrForbidden
    }
    // Rule 3: Environment / trust-engine signals (see §6).
    if err := p.evaluateEnvironment(ctx, sub); err != nil {
        return ErrForbidden
    }
    return nil
}
```

The policy is evaluated inside the command/query handler, not only at the API edge — an API-only check
is bypassable by any other entry path (a Redpanda consumer, an internal call).

---

## 5. IDOR / BOLA Prevention

IDOR (Insecure Direct Object Reference) is the concrete face of Broken Access Control (A01): reading or
mutating object `id=124` because you can guess it. Every request that names a resource by ID verifies
the caller is entitled to *that specific object*, not merely authenticated:

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    sub, err := SubjectFromContext(ctx)
    if err != nil {
        return ErrUnauthenticated
    }
    // Load the resource to obtain its real tenant_id — never trust a tenant_id
    // supplied by the caller alongside the object ID.
    asset, err := h.repo.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return err
    }
    res := Resource{Type: "data-asset", ID: cmd.DataAssetID, TenantID: asset.TenantID()}
    if err := h.policy.Evaluate(ctx, sub, res, Action{Operation: "classify-data-asset"}); err != nil {
        return err // ErrForbidden — do not reveal why
    }
    return asset.Classify(cmd)
}
```

**Standing IDOR test.** For every endpoint accepting a resource ID, authenticate as tenant/subject A
and request tenant/subject B's object ID, asserting `403`/`404` (indistinguishable). This is the
regression guard for A01 and complements the repository's `tenant_id = $N` SQL filter (the backstop
when the policy layer has a bug — defense in depth inside the repository too).

---

## 6. mTLS Answers *Who*, ABAC Answers *What* (Zero Trust)

The network is always assumed hostile: a compromised pod on the same namespace is a hostile participant
(Gilman & Barth). Separate the two planes and validate both identity axes:

- **Data plane — Linkerd mTLS:** transport-layer identity + encryption. A meshed connection succeeding
  proves *who* connected. It is an identity fact, **never** a permission grant.
- **Control plane — the ABAC engine:** owns every `allow/deny`, re-evaluated per request.

For any server-to-server call require **both** a verified workload identity (the Linkerd cert — "which
service is calling") **and** a re-validated propagated user `Subject` (the JWT — "on whose behalf"). The
receiving service re-derives the `Subject` from the token via the single `SubjectFromContext` path — it
never lets a trusted workload identity launder an unvalidated or over-broad user claim from an upstream
service.

**Trust-engine signals feed ABAC `Environment`.** Authentication is not a one-time binary gate.
Authentication freshness (token age), device posture, source-IP reputation, and anomaly flags are
first-class inputs alongside `Subject`/`Resource`/`Action`, so a structurally-valid request from a
low-trust context can still be denied (the trust engine vs. policy engine decomposition).

Audit every allow **and** deny with the deciding attributes as an OpenTelemetry span (subject, workload
identity, resource, action, trust signals) so "why was this allowed?" is answerable in Tempo/Grafana.

---

## 7. Breakglass — a Designed, Audited Path (BSRS)

Tight least-privilege creates an incentive to leave a permanent backdoor; breakglass removes it. Model
emergency elevated access as an explicit, time-boxed, justification-gated capability that emits a
high-priority audit event into the **same non-repudiation hash chain** the audit log already builds
(see `references/audit-and-evidence.md`) — never a standing admin credential:

```go
type BreakglassGrant struct {
    Subject     Subject
    Reason      string        // recorded justification, required
    ApprovedBy  uuid.UUID     // second party
    GrantedAt   time.Time
    ExpiresAt   time.Time     // auto-expiring, time-boxed
}

func (s *BreakglassService) Activate(ctx context.Context, req BreakglassRequest) (BreakglassGrant, error) {
    if req.Reason == "" || req.ApprovedBy == uuid.Nil {
        return BreakglassGrant{}, ErrBreakglassRequiresJustificationAndApprover
    }
    grant := newTimeBoxedGrant(req) // e.g. 30-minute expiry
    // High-priority audit event into the non-repudiation hash chain.
    if err := s.audit.Append(ctx, breakglassEntry(grant)); err != nil {
        return BreakglassGrant{}, err // if it can't be audited, it can't be granted
    }
    return grant, nil
}
```

---

## 8. Fail Secure & Revocation

- **Fail secure, per subsystem.** When a security dependency is unavailable (JWKS unreachable, policy
  store times out), the default is **never** allow. Decide and document each subsystem's behaviour; the
  availability-vs-confidentiality tension is resolved explicitly in the error path.
- **Revocation is a tested capability.** "The token will expire" is incomplete. Document and test the
  emergency path that invalidates a leaked JWT, Linkerd cert, or customer Google Drive/S3 OAuth grant
  *before* `exp`, with a stated maximum propagation time. Short-lived credentials bound the worst case;
  an actual revocation path shortens it.
- **Least-privilege API surface.** Expose narrow, intent-named operations (`ClassifyDataAsset`,
  `ExtractEntities`) rather than a general `RunQuery` — the authority a compromised caller wields is
  bounded by the surface it can reach.

---

## Middleware Order (load-bearing)

`security headers → auth → rate limit → handler`. Rate limiting keyed on user ID placed *before* auth
reads an empty subject and collapses all anonymous traffic into one bucket. Order it explicitly.
