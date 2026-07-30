# Error-Mapping and Retry/Backoff Standard

Self-contained reference for `react-api-client`. Maps the backend's exact
`ErrorResponse` envelope (`go-chi-handler`) into a typed frontend
discriminated union, then defines which failures are worth an automatic
retry and which never are.

---

## The Envelope, Verified Against `go-chi-handler`

`go-chi-handler`'s `SKILL.md` defines the envelope every error response
uses, verbatim:

```go
type ErrorResponse struct {
    Error struct {
        Code    string            `json:"code"`
        Message string            `json:"message"`
        Fields  []ValidationError `json:"fields,omitempty"`
        TraceID string            `json:"traceId,omitempty"` // for support correlation
    } `json:"error"`
}
```

Which serializes to this exact JSON shape:

```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "not permitted",
    "fields": [{ "field": "sensitivityLevel", "message": "must be one of: Public, Internal, Confidential, Restricted" }],
    "traceId": "4bf92f3577b34da6a3ce929d0e0e4736"
  }
}
```

Two notes on fidelity, stated explicitly rather than assumed silently:

- **Outer keys are exact** (`code`, `message`, `fields`, `traceId`, all
  nested one level under `error`) — taken directly from `go-chi-handler`'s
  struct tags, not inferred.
- **`fields` items' own casing (`field`/`message`) is this client's
  documented convention**, not a tag `go-chi-handler`'s `SKILL.md` shows
  explicitly on `ValidationError` — it is inferred from the rest of the
  wire contract's camelCase convention (`sensitivityLevel`, `classifiedBy`,
  `traceId` are all camelCase) and from `api-contract-design`'s own
  `details[].field`/`.message` item shape, which uses the same casing for
  the analogous per-field array. If a future `go-chi-handler` revision
  states `ValidationError`'s JSON tags explicitly and they differ, this
  file's `fields` item type must be updated to match — the backend's
  actual tags always win.

`code` values observed in `go-chi-handler`'s single mapping point
(`writeDomainError`): `NOT_FOUND` (404), `AUTHENTICATION_REQUIRED` (401),
`FORBIDDEN` (403), `CONFLICT` (409), `UNPROCESSABLE` (422), `INTERNAL`
(500) — plus `RATE_LIMIT_EXCEEDED` (429) and `REVISION_MISMATCH` (409,
see `typed-client-generation.md`) from `api-contract-design`'s broader
status table. Treat this as an open, extensible set — a new backend code
should be a compile error to leave unhandled (Exhaustiveness Checking
below), not a runtime surprise.

---

## `AppError`: A Discriminated Union, Never a Catch-All `Error`

Three fundamentally different failure kinds reach client code, and
conflating them into one `Error` object loses the information needed to
render the right UI. Modeled with a `kind` discriminant, the same pattern
`typescript-types` teaches for any multi-shape state:

```ts
export type FieldError = { field: string; message: string };

export type AppError =
  | {
      kind: "api";                 // the server responded with the standard envelope
      status: number;              // HTTP status, for logging/telemetry only — never switched on in UI code
      code: string;                 // "FORBIDDEN" | "CONFLICT" | "UNPROCESSABLE" | … — switch on this
      message: string;
      fields: FieldError[];
      traceId?: string;
    }
  | { kind: "network"; message: string }  // fetch threw before any response existed (offline, DNS, timeout)
  | { kind: "aborted" };                   // cancelled — see cancellation-standard.md; never shown to the user

export function toAppError(raw: unknown, status: number): AppError {
  const envelope = raw as { error: { code: string; message: string; fields?: FieldError[]; traceId?: string } };
  return {
    kind: "api",
    status,
    code: envelope.error.code,
    message: envelope.error.message,
    fields: envelope.error.fields ?? [],
    traceId: envelope.error.traceId,
  };
}
```

UI code switches exhaustively on `code` within the `"api"` branch, using
the `never`-based exhaustiveness guard `typescript-types` defines — a new
backend error code becomes a compile error to leave unhandled, not a
silent fallthrough to a generic message:

```ts
function messageFor(err: Extract<AppError, { kind: "api" }>): string {
  switch (err.code) {
    case "NOT_FOUND":        return "This item no longer exists.";
    case "FORBIDDEN":        return "You don't have permission to do this.";
    case "CONFLICT":         return "This was changed by someone else. Refresh and try again.";
    case "REVISION_MISMATCH":return "This was changed since you loaded it. Refresh and try again.";
    case "UNPROCESSABLE":    return err.fields.map(f => f.message).join(" ") || err.message;
    case "RATE_LIMIT_EXCEEDED": return "Too many requests — please wait a moment.";
    case "AUTHENTICATION_REQUIRED": return "Please sign in again.";
    case "INTERNAL":         return `Something went wrong. Reference: ${err.traceId ?? "n/a"}`;
    default:                 return assertNever(err.code as never); // forces a case for every new code
  }
}
```

`traceId` is surfaced in the error UI verbatim, unmodified — it is the
same identifier `go-chi-handler`'s `slog.ErrorContext` logs server-side,
so a user quoting it to support resolves directly to one trace.

---

## Retry and Backoff for Transient Failures

Not every failure is worth retrying, and retrying the wrong ones causes
real damage (a non-idempotent write applied twice, a client hammering an
already-overloaded server). The rule:

| Failure | Retry? | Why |
|---|---|---|
| `kind: "network"` (no response reached the server) | **Yes** | Transient — a dropped connection, DNS blip, or timeout says nothing about whether the request itself was bad. |
| `5xx` (`INTERNAL`, or any 500-599) | **Yes** | Server-side and usually transient (a pod restarting, a downstream dependency degraded) — same failure class `go-error-handling`'s "downstream DB is down → wrapped error, retry/circuit-break" row describes on the backend; the frontend's retry is the client-side half of that same philosophy. |
| `429` (`RATE_LIMIT_EXCEEDED`) | **Yes, but honor `Retry-After`** | The server is explicitly asking for a delay; a fixed backoff that ignores a present `Retry-After` header retries too soon. |
| Any other `4xx` (`400`, `403`, `404`, `409`/`REVISION_MISMATCH`, `422`) | **Never automatically** | The request itself was rejected on its merits — a validation failure, a permission gap, a stale revision. Retrying unchanged input reproduces the identical failure; the fix is a different request (corrected input, a fresh read), not another attempt. |
| `401` | **Handled by the auth flow's single refresh-and-retry-once, not the generic retry policy** | See `auth-token-standard.md` — a distinct, capped mechanism, not exponential backoff. |
| `kind: "aborted"` | **Never** | The caller withdrew interest; retrying an intentionally-cancelled request wastes bandwidth and can race a component that already unmounted. |

**Idempotency-safety gate**: retrying a `GET` is always safe. Retrying a
mutation (`PATCH`/`PUT`/`DELETE`) is safe only when it carries an
`Idempotency-Key` — a mutation issued with no key must not be
automatically retried by this layer, full stop; a duplicate non-idempotent
write is a worse outcome than a surfaced transient error.

### Backoff Parameters

Exponential backoff with jitter, capped attempts — concrete defaults:

```ts
const RETRY_BASE_MS = 250;
const RETRY_FACTOR = 2;
const RETRY_MAX_MS = 4_000;
const RETRY_MAX_ATTEMPTS = 3;

function backoffDelay(attempt: number, retryAfterHeader?: string | null): number {
  if (retryAfterHeader) return Number(retryAfterHeader) * 1000; // server said exactly how long
  const exp = Math.min(RETRY_BASE_MS * RETRY_FACTOR ** attempt, RETRY_MAX_MS);
  return exp / 2 + Math.random() * (exp / 2); // full jitter within [exp/2, exp] — avoids synchronized retry storms
}
```

**This policy plugs into TanStack Query's own `retry`/`retryDelay` query
options — it does not compete with them.** `react-state-management` owns
the query's cache/invalidation behavior; this table and `backoffDelay`
are the values that library's `retry: (failureCount, error) => …` and
`retryDelay: (attempt) => …` callbacks should implement, evaluated against
the `AppError` this file produces. A second, hand-rolled retry loop
wrapping the same call would race TanStack Query's own retry and double
the effective attempt count.
