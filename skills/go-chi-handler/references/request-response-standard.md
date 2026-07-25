# Request/Response Standard

Full standard referenced from `SKILL.md`'s "Request Decoding Standard", "Response Encoding Standard", "Structural Validation at the Boundary", and "Error Response Standard" sections — the exact `json.Decoder` configuration and its complete failure-mode-to-status mapping, the header-ordering footgun, the canonical error envelope, and the message-content rules. This pattern (a body size cap composed with a decode-error switch that turns every `encoding/json` failure into an actionable client message) is Alex Edwards' `readJSON` idiom from *Let's Go Further* — this file is the plugin's adaptation of it to the `ErrorResponse`/error-code vocabulary the rest of this skill roster uses.

---

## `decodeJSON`: the Complete Implementation

```go
// internal/handlers/http/decode.go

const maxRequestBodyBytes = 1 << 20 // 1 MiB — see Quality Criteria for how this is chosen per route

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
    // Content-Type enforcement — reject anything that isn't a JSON body before
    // spending a single byte of the read budget parsing it.
    if ct := r.Header.Get("Content-Type"); ct != "" && !strings.HasPrefix(ct, "application/json") {
        return errUnsupportedMediaType
    }

    // Size limiting — MaxBytesReader wraps the body so the decoder itself
    // aborts once the cap is exceeded, instead of trusting a caller-declared
    // Content-Length or reading an attacker-supplied body to exhaustion.
    r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)

    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields() // reject typos and stale-client fields instead of silently ignoring them

    if err := dec.Decode(dst); err != nil {
        return classifyDecodeError(err)
    }

    // A second Decode call into a throwaway value detects trailing data —
    // a client that concatenated two JSON documents into one body. io.EOF
    // means "nothing left," which is the only success outcome here.
    if err := dec.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
        return errMultipleJSONValues
    }
    return nil
}
```

`classifyDecodeError` is the single place every `encoding/json` failure mode is named and turned into a stable sentinel/typed error — never inlined per handler:

```go
func classifyDecodeError(err error) error {
    var syntaxErr *json.SyntaxError
    var typeErr *json.UnmarshalTypeError
    var maxBytesErr *http.MaxBytesError
    var invalidErr *json.InvalidUnmarshalError

    switch {
    case errors.As(err, &syntaxErr):
        return fmt.Errorf("%w: badly-formed JSON (at character %d)", errMalformedJSON, syntaxErr.Offset)
    case errors.Is(err, io.ErrUnexpectedEOF):
        return fmt.Errorf("%w: badly-formed JSON", errMalformedJSON)
    case errors.As(err, &typeErr):
        if typeErr.Field != "" {
            return fmt.Errorf("%w: field %q", errInvalidFieldType, typeErr.Field)
        }
        return fmt.Errorf("%w: at character %d", errInvalidFieldType, typeErr.Offset)
    case errors.Is(err, io.EOF):
        return errEmptyBody
    case strings.HasPrefix(err.Error(), "json: unknown field "):
        return fmt.Errorf("%w: %s", errUnknownField, strings.TrimPrefix(err.Error(), "json: unknown field "))
    case errors.As(err, &maxBytesErr):
        return fmt.Errorf("%w: limit is %d bytes", errBodyTooLarge, maxBytesErr.Limit)
    case errors.As(err, &invalidErr):
        // dst was not a non-nil pointer — a programmer error, not a client
        // error. Panic: this can never legitimately happen in production
        // code where every call site passes &req. See go-error-handling's
        // panic/recover boundary — this is exactly the "invariant that
        // can't happen" case, caught by go-middleware's Recoverer.
        panic(fmt.Errorf("decodeJSON: %w", err))
    default:
        return fmt.Errorf("%w: %v", errMalformedJSON, err)
    }
}
```

`errMalformedJSON`, `errInvalidFieldType`, `errEmptyBody`, `errUnknownField`, `errBodyTooLarge`, `errUnsupportedMediaType`, `errMultipleJSONValues` are package-level sentinels in `internal/handlers/http/errors.go` — `writeDecodeError` (below) switches on them with `errors.Is`, the same single-mapping-point discipline `writeDomainError` already applies to domain errors (see `SKILL.md`'s "One Error Mapping Point").

---

## The Decode-Error-to-HTTP-Status Mapping Table

Every failure mode `encoding/json`, `http.MaxBytesReader`, or this skill's own trailing-data check can produce, mapped exactly once:

| Failure mode | Go signal | HTTP status | Error code | Message shown to the client |
|---|---|---|---|---|
| Malformed JSON syntax | `*json.SyntaxError` | 400 | `MALFORMED_JSON` | `"body contains badly-formed JSON (at character N)"` |
| Truncated body mid-token | `io.ErrUnexpectedEOF` | 400 | `MALFORMED_JSON` | `"body contains badly-formed JSON"` |
| Wrong JSON type for a Go field | `*json.UnmarshalTypeError` | 400 | `INVALID_FIELD_TYPE` | `"body contains incorrect JSON type for field \"X\""` |
| Empty body | `io.EOF` on first `Decode` | 400 | `EMPTY_BODY` | `"body must not be empty"` |
| Field not present on `dst` | `"json: unknown field ..."` string (no typed error exists for this case) | 400 | `UNKNOWN_FIELD` | `"body contains unknown key \"X\""` |
| Body exceeds the cap | `*http.MaxBytesError` | 413 | `BODY_TOO_LARGE` | `"body must not be larger than N bytes"` |
| Trailing data after a valid document | second `Decode` returns non-`io.EOF` | 400 | `MULTIPLE_JSON_VALUES` | `"body must only contain a single JSON value"` |
| Wrong `Content-Type` | checked before decoding | 415 | `UNSUPPORTED_MEDIA_TYPE` | `"Content-Type must be application/json"` |
| `dst` not a non-nil pointer | `*json.InvalidUnmarshalError` | — (panic, 500 via `Recoverer`) | `INTERNAL` | opaque — this is a programmer bug, never a client-input problem |

Every row but the last is a 4xx: the client sent something the handler can name precisely, so the response says exactly what was wrong instead of a bare `400 Bad Request`. The last row is deliberately different in kind — `*json.InvalidUnmarshalError` cannot be triggered by any request body, only by a handler passing the decoder a non-pointer or nil `dst`, so it is not routed through the 4xx vocabulary at all.

`writeDecodeError` performs the table's mapping in one function, the request-decoding sibling of `writeDomainError`:

```go
func writeDecodeError(w http.ResponseWriter, r *http.Request, err error) {
    switch {
    case errors.Is(err, errBodyTooLarge):
        writeError(w, r, http.StatusRequestEntityTooLarge, "BODY_TOO_LARGE", err.Error())
    case errors.Is(err, errUnsupportedMediaType):
        writeError(w, r, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA_TYPE", err.Error())
    case errors.Is(err, errMalformedJSON), errors.Is(err, errInvalidFieldType),
        errors.Is(err, errEmptyBody), errors.Is(err, errUnknownField), errors.Is(err, errMultipleJSONValues):
        writeError(w, r, http.StatusBadRequest, "MALFORMED_REQUEST", err.Error())
    default:
        writeError(w, r, http.StatusBadRequest, "MALFORMED_REQUEST", "the request body could not be understood")
    }
}
```

---

## Response Encoding: Header Ordering Relative to `WriteHeader`

`http.ResponseWriter.WriteHeader(status)` sends the status line **and** flushes the accumulated header map in one step; any `w.Header().Set(...)` call made *after* `WriteHeader` has already run has no effect on the response actually sent to the client — Go does not error, it silently drops the change (and a second `WriteHeader` call logs `http: superfluous response.WriteHeader call`, which is the visible symptom when this is gotten wrong). The rule is unconditional: **every header mutation happens before the single `WriteHeader` call, in every response-writing function, with no exceptions.**

```go
// CORRECT — Content-Type is set, then the status line is written, then the body.
func writeJSON(w http.ResponseWriter, r *http.Request, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    if err := json.NewEncoder(w).Encode(v); err != nil {
        slog.ErrorContext(r.Context(), "encoding response", "err", err) // body is already partially sent — cannot recover, only log
    }
}
```

```go
// WRONG — Content-Type never reaches the client. WriteHeader already sent the
// header block; the Set call below mutates a map nobody reads again.
func writeJSONBroken(w http.ResponseWriter, status int, v any) {
    w.WriteHeader(status)
    w.Header().Set("Content-Type", "application/json") // too late — silently discarded
    json.NewEncoder(w).Encode(v)
}
```

`json.NewEncoder(w).Encode(v)` writes directly to the wire; once it runs, no further header or status change is possible even in principle — the response is committed byte-by-byte as `Encode` streams. This is why a partial-encode failure (the `slog.ErrorContext` line above) can only be logged, never turned into a different status code: the 200 header block is already on the wire by the time `Encode` might fail mid-object.

---

## The Canonical `ErrorResponse` Envelope

```go
type ErrorResponse struct {
    Error struct {
        Code    string            `json:"code"`              // stable, machine-matchable: SCREAMING_SNAKE_CASE
        Message string            `json:"message"`           // human-readable, safe to show a user or log verbatim
        Fields  []ValidationError `json:"fields,omitempty"`  // present only for structural-validation failures
        TraceID string            `json:"traceId,omitempty"` // correlates to go-middleware's RequestID/span
    } `json:"error"`
}

type ValidationError struct {
    Field   string `json:"field"`
    Message string `json:"message"`
}
```

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "the request failed validation",
    "fields": [
      {"field": "sensitivityLevel", "message": "must be one of: Public, Internal, Confidential, Restricted"}
    ],
    "traceId": "4b8f1e2a-9c3d-4a11-8e77-2f6a1d0c9b44"
  }
}
```

Every error response — decode failure, validation failure, domain error, unmapped 500 — uses this exact shape. A client (or a support engineer reading a bug report) never has to guess which of several error JSON shapes came back; there is exactly one.

---

## Error Message Standards

These rules govern the `message` field's *content*, not just its presence — a message that technically exists but leaks a stack trace or a driver string is still a defect:

- **`code` is machine-matchable, `message` is human-readable — never conflate them.** A client integration matches on `code` (`"NOT_FOUND"`), never on parsing `message` text; `message` is free to be reworded without breaking any caller, `code` is not.
- **`message` names the problem the client can act on, in plain language.** `"sensitivityLevel must be one of: Public, Internal, Confidential, Restricted"` is actionable; `"validation failed"` alone is not — the client already knew that from the status code.
- **Never echo internal detail in a 5xx `message`.** SQL fragments, stack traces, file paths, driver error strings (`"pq: duplicate key value violates unique constraint"`), and Go type names are for the log line (with `traceId`), never for the response body. The 5xx `message` is always the same opaque sentence: `"an unexpected error occurred"`.
- **4xx messages may be specific because the client caused them** — a malformed-JSON offset, a field name, an enum's valid values are all safe to return: they describe the client's own request, not the server's internals.
- **`fields` is populated only for structural-validation failures**, and always carries *every* failing field from one validation pass — never a single field with more following in a second round trip (see "Structural Validation at the Boundary" below).
- **`traceId` is always populated when available, on both 4xx and 5xx.** It costs nothing (already resolved by `go-middleware`'s `RequestID`/`Telemetry` middleware and read from `r.Context()`), and it is the one field that turns "the API is returning an error" into a specific, greppable incident a support engineer or on-call engineer can pull from logs/traces in one query.
- **Never invent a new top-level shape for a "special" error.** A rate-limit 429, a 413 body-too-large, and a 404 all use the identical `ErrorResponse` envelope — only `code`/`message`/`status` vary. A bespoke shape for one error type is the first crack in "exactly one shape."

---

## Structural Validation at the Boundary: the Precise Line

| | Structural (the handler validates) | Domain (the Aggregate validates) |
|---|---|---|
| **Question it answers** | "Is this request well-formed?" | "Is this request allowed, given the system's current state?" |
| **Inputs it needs** | Only the request body/path/query itself | The aggregate's current state, possibly other aggregates, possibly the actor's permissions |
| **Examples** | Required field missing; wrong type; string not a UUID; enum value not one of the allowed set; string exceeds a length bound; number outside a declared range | "cannot downgrade sensitivity without explicit reclassification"; "cannot classify a retired asset"; "cannot exceed the tenant's quota" |
| **Where it lives** | `internal/handlers/http/<name>.go`'s `validate()` method on the request DTO | `internal/domain`'s Aggregate method (`DataAsset.Classify(...)`) |
| **Failure status** | 400, `VALIDATION_FAILED`, all failing fields in one `fields` array | Whatever `writeDomainError`'s switch maps the specific sentinel to (409, 422, 403, …) — never a bare 400 |
| **Cardinality** | All violations returned together, one round trip | One error per call — a business rule either holds or it doesn't; there is no "list every business rule that would also have failed" |

**The rule of thumb:** if answering the question requires nothing beyond the bytes already in the request, it is structural and belongs in the handler. The moment answering it requires reading the aggregate's current state, another aggregate, or the caller's permissions, it is domain and belongs behind `r.Context()` in the application/domain layers — the handler must not reach into a repository "just to check" before calling the command handler; that duplicates logic the Aggregate already owns and creates two places a business rule can drift out of sync.

---

## Domain-Error-Category → HTTP Status (canonical table)

The full `writeDomainError` switch is in `references/worked-handler-examples.md`; this is the category-level standard it implements — **one status per category, never per handler**:

| Domain error category | HTTP status | Error code |
|---|---|---|
| Resource not found | 404 | `NOT_FOUND` |
| Unauthenticated | 401 | `AUTHENTICATION_REQUIRED` |
| Forbidden (authenticated, not permitted) | 403 | `FORBIDDEN` |
| Concurrent modification / optimistic-lock conflict | 409 | `CONFLICT` |
| Business rule violation (semantically well-formed, not permitted by domain state) | 422 | `UNPROCESSABLE` |
| Structural validation failure | 400 | `VALIDATION_FAILED` |
| Unmapped / unexpected error | 500 | `INTERNAL` |

A new domain sentinel error is added to exactly one `case` in `writeDomainError`, mapped to exactly one row above — never given its own ad hoc status chosen per call site.
