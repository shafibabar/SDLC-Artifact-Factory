# OWASP Top 10 → Go Control → STRIDE

The OWASP Top 10 is used here as a **control map, not a vulnerability list** (Janca, *Alice and Bob
Learn Application Security*): each category maps to the concrete line of Go code that neutralizes it in
this repo's stack, and to the STRIDE letter that control discharges (Shostack, *Threat Modeling*) so the
skill's scattered controls read as one coherent answer to a recognized threat set.

> Version note: the OWASP Top 10 has been re-grouped and re-numbered across editions (e.g. the 2021
> revision consolidated several 2017 categories). The **controls** below are stable and correct; the
> category names are the concept, not a version-pinned citation — verify numbering against the current
> OWASP Top 10 when producing an artifact. Category IDs shown follow the OWASP 2021 edition.

---

## The Map

| OWASP category | The threat, concretely, in this repo | Concrete Go control in this stack | STRIDE |
|---|---|---|---|
| **A01 Broken Access Control** | Reading/mutating another tenant's `DataAsset` by guessing `id` (IDOR/BOLA); authorization checked at the API edge only and bypassed by an internal path | Server-side ABAC `AccessPolicy.Evaluate` in the application layer, **deny by default**; per-object ownership check (load the resource, compare its real `tenant_id`); `tenant_id = $N` SQL backstop; standing IDOR test | **E**levation of privilege |
| **A02 Cryptographic Failures** | Sensitive data in transit or at rest without encryption; home-grown crypto | Linkerd automatic mTLS (transit, defense-in-depth); Postgres/volume Encryption at Rest; no bespoke crypto — standard library / vetted libs only | **I**nformation disclosure |
| **A03 Injection** | SQL injection via string-built queries; XSS via ingested file names/entity labels rendered in React; log injection via a newline in an ingested value; HTTP header injection | pgx `$N` parameterized queries (never `fmt.Sprintf`); React default JSX escaping + no `dangerouslySetInnerHTML` on ingested data; CR/LF stripped from header values; log-line encoding of user-controlled values | **T**ampering |
| **A04 Insecure Design** | A control designed only at one layer; no threat model behind the control set | STRIDE-per-element threat model as the upstream generator of controls; secure-default service template inherited by every service | **all** (design-level) |
| **A05 Security Misconfiguration** | Verbose errors leaking stack traces/versions; default credentials; unused endpoints exposed | Secure defaults: least functionality, no default/sample creds, security response headers on, errors that leak nothing to the client (see `references/secure-coding-go.md`) | **I**nformation disclosure |
| **A06 Vulnerable & Outdated Components** | A CVE in a transitive Go/JS dependency | `govulncheck` + dependency scanning in CI; pinned, reviewed dependencies (frugality: every dependency justified) | **T**ampering |
| **A07 Identification & Authentication Failures** | Weak session lifecycle; credential stuffing; missing MFA | JWT validated server-side against JWKS (`aud`/`iss`/`exp` required); cookie hardening (`HttpOnly; Secure; SameSite`); session-ID regeneration on auth; MFA + salted adaptive hashes stated as IdP constraints (see `references/authn-authz.md`) | **S**poofing |
| **A08 Software & Data Integrity Failures** | An unsigned CI artifact or untrusted build reaching production; tampered events | Signed pipeline attestations (SLSA/in-toto-style provenance); signed domain events; Transactional Outbox integrity (see `references/audit-and-evidence.md`) | **T**ampering |
| **A09 Security Logging & Monitoring Failures** | A security event never logged; a denial spike (credential stuffing/enumeration) never alerted; a secret/PII logged | Structured security-event logging (authN outcome, authZ denial, validation rejection, privilege change) through a redacting logger; alert on denial spikes; append-only hash-chained audit log (see `references/audit-and-evidence.md`) | **R**epudiation |
| **A10 Server-Side Request Forgery (SSRF)** | The ingestion worker fetching a URL controlled by an untrusted document/tenant | Allowlist of permitted egress hosts for ingestion; validate and canonicalize any fetched URL; block internal/metadata IP ranges | **I**nformation disclosure |

---

## Worked Controls for the Highest-Value Categories

The table is the index; these are the three categories that produce the most real findings in a
data-estate platform ingesting untrusted documents, with the concrete Go control spelled out.

### A01 Broken Access Control — the object-level ownership check

The most common real finding. Authentication is not authorization: a caller holding a valid token for
tenant A must still be denied tenant B's object. The control is a per-object ownership check *after*
loading the resource's real owner — never trusting a `tenant_id` the caller supplied alongside the ID:

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    sub, err := SubjectFromContext(ctx)
    if err != nil {
        return ErrUnauthenticated
    }
    asset, err := h.repo.FindByID(ctx, cmd.DataAssetID) // load to get the REAL tenant_id
    if err != nil {
        return err
    }
    res := Resource{Type: "data-asset", ID: cmd.DataAssetID, TenantID: asset.TenantID()}
    if err := h.policy.Evaluate(ctx, sub, res, Action{Operation: "classify-data-asset"}); err != nil {
        return err // ErrForbidden — 403/404 indistinguishable
    }
    return asset.Classify(cmd)
}
```

The standing regression guard is the IDOR test: authenticate as A, request B's object ID, assert
`403`/`404`. Full pattern in `references/authn-authz.md` §5.

### A03 Injection — one value, three sinks

Injection is an *output* problem, and one untrusted value ingested from a document can need three
different encodings depending on where it lands. A file name from a Google Drive upload is:

- **parameterized** (`$N`) when it reaches a pgx query — never `fmt.Sprintf`;
- **JSX-escaped** (React default; no `dangerouslySetInnerHTML`) when rendered in the frontend;
- **CR/LF-stripped** when placed into an HTTP response header, and **log-line-encoded** when written to a
  log so a newline cannot forge a log entry.

Input validation does *not* substitute for any of these — they are a separate control applied at the
sink. Full per-sink table in `references/secure-coding-go.md` §2.

### A10 SSRF — egress allowlist for the ingestion worker

The ingestion worker fetches content on behalf of untrusted documents/tenants, so it is a natural SSRF
sink: a crafted document can point it at an internal service or a cloud metadata endpoint. Control it
with an egress **allowlist** of permitted hosts, canonicalize the URL before fetching, and block
internal/link-local/metadata IP ranges (`169.254.0.0/16`, `10.0.0.0/8`, `127.0.0.0/8`, `::1`):

```go
func (f *DocumentFetcher) safeFetch(ctx context.Context, raw string) (*http.Response, error) {
    u, err := url.Parse(raw)
    if err != nil || !f.egressAllowlist[u.Hostname()] {
        return nil, ErrDisallowedEgressHost // allowlist, not denylist
    }
    if isPrivateOrMetadataIP(u.Hostname()) {
        return nil, ErrDisallowedEgressHost
    }
    return f.client.Do(requestWithContext(ctx, u))
}
```

### A09 Security Logging & Monitoring — the redacting event logger

A control that is never observed is a control that silently regressed. Emit a structured security event
for every authN outcome, authZ denial, and validation rejection — routed through a redacting logger so a
secret or PII value can never be serialized even by mistake, and log-encoded so an ingested value cannot
forge a line:

```go
func logAuthzDenial(ctx context.Context, sub Subject, res Resource, act Action) {
    // Structured fields only. The Subject's TenantID renders as an ID, never PII;
    // no raw file content, no token, no secret reaches this sink.
    slog.WarnContext(ctx, "authorization.denied",
        slog.String("actor_id", sub.ID.String()),
        slog.String("tenant_id", sub.TenantID.String()),
        slog.String("resource_type", res.Type),
        slog.String("action", act.Operation),
    )
}
```

Alert on denial spikes — a burst of `authorization.denied` or authentication failures is the signature
of credential stuffing or enumeration. Full logging dual-discipline (what to log, what never to log) and
the append-only hash-chained audit trail are in `references/audit-and-evidence.md`.

---

## How to Use the Map

**As a merge gate (per change).** Turn the Top 10 into a per-change checklist a reviewer or a hook can
run against any change that touches an endpoint (Janca's push-left gate):

1. Does this change **validate** all new inputs (allowlist, at every boundary)?
2. Does it **encode** all new outputs (contextually, at each sink)?
3. Does it enforce **server-side authorization** with a deny-by-default policy?
4. Does it avoid **IDOR** (object-level ownership check, not just authentication)?
5. Does it keep **secrets** out of code and logs?
6. Does it emit a **security-event log** for the security-relevant actions it adds?

A change that touches an endpoint and cannot answer these is not merge-ready.

**As audit evidence.** Each category names a *verifiable* artifact — parameterized queries (A03),
deny-by-default policy tests (A01), IDOR tests (A01), security-event logs (A09), cookie flags (A07),
signed attestations (A08). This is the audit-friendly control list `compliance-verification` consumes:
every SOC 2 access-control / integrity / logging criterion points at one of these concrete artifacts
rather than a design assertion.

---

## What This Repo's Platform Already Covers

Some categories are partly discharged by the platform, so treat them as **defense-in-depth
reinforcement**, not gaps to fill from scratch (Janca caveat):

- **A02 (transit crypto)** is largely handled by Linkerd's automatic mTLS — but the app still validates
  it is not the *only* layer, and at-rest encryption remains the app/infra's job.
- **A01 (cross-tenant)** is backstopped by physical per-tenant isolation — the ABAC check is
  defense-in-depth *within* that boundary, and the SQL `tenant_id` filter is a third independent layer.

The genuinely new material this map forces into the implementation is the **output-encoding** discipline
for A03 (XSS/log/header injection on ingested data, not just SQL), IDOR testing for A01, session/cookie
hardening for A07, SSRF egress controls for A10, and signed attestations for A08.
