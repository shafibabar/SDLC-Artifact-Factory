---
name: structured-logging-design
description: >
  Teaches high-performance structured logging in Go — slog as the default (zerolog/
  zap when profile-justified), JSON output in production, binding TraceID and SpanID
  to every log line from the active context, consistent levels and keys, low
  allocation on the hot path, and the strict no-secrets/no-PII rule. Logs are the
  third observability signal and must correlate with traces and metrics. Used by
  the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, observability, logging, slog, json, trace-correlation, structured]
---

# Structured Logging Design

## Purpose

Logs are the narrative signal — the per-event detail that explains what happened. To be useful at scale they must be **structured** (machine-parseable key/value, not free text), **correlated** (every line carries the trace and span id so a log links to its trace and metrics), and **cheap** (logging must not dominate the hot path). Unstructured `fmt.Printf` logging is unsearchable, uncorrelated, and forbidden in production code.

This skill standardises on `log/slog` and the rules that make logs a first-class observability signal alongside OTel traces and metrics.

---

## slog as the Default

`log/slog` is the standard-library structured logger — frugal (no dependency), fast, and JSON-capable. It is the default. `zerolog` or `zap` are acceptable **only** when a benchmark shows logging is a measured hot-path cost that slog cannot meet — a profile-justified exception, not a default preference.

```go
// internal/infrastructure/telemetry/logging.go
package telemetry

func InitLogging(cfg Config) *slog.Logger {
    var handler slog.Handler
    opts := &slog.HandlerOptions{Level: cfg.Level}
    if cfg.Env == "production" {
        handler = slog.NewJSONHandler(os.Stdout, opts) // JSON in prod — always
    } else {
        handler = slog.NewTextHandler(os.Stdout, opts) // human-readable locally
    }
    logger := slog.New(&traceHandler{Handler: handler}) // wrap to inject trace ids (below)
    slog.SetDefault(logger)
    return logger
}
```

**JSON in production, always.** JSON is what the log pipeline (Fluent Bit → Elasticsearch — see the platform observability stack) parses and indexes. Text logs in production are a dead end.

---

## Trace Correlation — Every Line Carries TraceID/SpanID

This is the link that turns three separate signals into one. A custom handler pulls the active span's `TraceID` and `SpanID` from the context and adds them to every record, so any log line can be pivoted to its full trace.

```go
type traceHandler struct{ slog.Handler }

func (h *traceHandler) Handle(ctx context.Context, r slog.Record) error {
    if sc := trace.SpanContextFromContext(ctx); sc.IsValid() {
        r.AddAttrs(
            slog.String("trace_id", sc.TraceID().String()),
            slog.String("span_id", sc.SpanID().String()),
        )
    }
    return h.Handler.Handle(ctx, r)
}

// WithAttrs/WithGroup MUST re-wrap. The embedded handler's versions return the INNER
// handler, so a logger derived via slog.With(...) would silently stop injecting trace ids
// — the classic slog-wrapper bug.
func (h *traceHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
    return &traceHandler{Handler: h.Handler.WithAttrs(attrs)}
}
func (h *traceHandler) WithGroup(name string) slog.Handler {
    return &traceHandler{Handler: h.Handler.WithGroup(name)}
}
```

Because correlation comes from context, **always use the context-aware logging methods** so the active span is in scope:

```go
slog.InfoContext(ctx, "data asset classified",
    slog.String("data_asset_id", id.String()),
    slog.String("sensitivity", string(level)),
)
// → {"time":...,"level":"INFO","msg":"data asset classified",
//    "data_asset_id":"a1b2...","sensitivity":"Confidential",
//    "trace_id":"4bf92f...","span_id":"00f067..."}
```

`slog.Info` (without context) loses the correlation — prefer `InfoContext`/`ErrorContext` everywhere a context is available.

---

## Levels — Used Consistently

| Level | Use for | Example |
|---|---|---|
| `Error` | A failure needing attention; always paired with the error and trace id | outbox publish failed after retries |
| `Warn` | Recoverable anomaly worth noticing | transient retry succeeded; Dead Letter Queue (DLQ) depth rising |
| `Info` | Significant business/lifecycle events | service started; asset classified; consumer drained |
| `Debug` | Detailed developer diagnostics; off in production | per-record processing detail |

Rules: production runs at `Info` (or `Warn`); `Debug` is opt-in. Don't log the same event at multiple layers — log it once, where it's most meaningful. Errors are logged at the boundary that handles them (the HTTP recoverer, the consumer DLQ path), not re-logged at every wrap.

---

## Consistent Keys

Use the same attribute keys across every service so logs are queryable uniformly. Define them once.

| Key | Meaning |
|---|---|
| `trace_id`, `span_id` | Correlation (auto-injected) |
| `tenant_id` | Tenant scope (never the tenant *name*) |
| `data_asset_id`, `event_id` | Domain identifiers |
| `error` | The error string (on Error level) |
| `http.route`, `http.status_code` | Request context |

Keys are `snake_case`, stable, and documented. `slog.With` binds common attributes once (e.g., per-request `tenant_id`) so they aren't repeated at every call.

---

## Performance on the Hot Path

The blueprint calls for low-allocation logging. slog is allocation-light when used correctly:

- Prefer **typed attribute constructors** (`slog.String`, `slog.Int`) over `slog.Any` — `Any` boxes into an interface and may allocate.
- **Guard expensive Debug logs**: don't build a costly string if the level is disabled — `if logger.Enabled(ctx, slog.LevelDebug) { … }`.
- Bind repeated fields with `With` once rather than passing them on every call.
- Never log inside the tightest inner loops on a hot path; log at the boundary with a summary (count, duration) instead.

---

## The No-Secrets / No-PII Rule

Logs are stored and widely readable — they are a prime exfiltration target. Therefore (security `privacy-design`, `secrets-management`):

- **Never log secrets** — tokens, passwords, keys, connection strings. Wrap secret-bearing types so their `String()`/`LogValue()` returns `[REDACTED]`.
- **Never log PII or file content** — log the `data_asset_id`, never the extracted entity value; log the `tenant_id`, never the user's email.
- Use `slog.LogValuer` to control how a sensitive type renders:

```go
func (Secret) LogValue() slog.Value { return slog.StringValue("[REDACTED]") }
```

A single logged JWT or SSN is a reportable incident — redaction is designed in, not hoped for.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Structured | Key/value via slog | `fmt.Printf`/free-text logs |
| JSON in prod | JSON handler in production | Text logs in production |
| Trace-correlated | Every line has trace_id/span_id; `…Context` methods used | Logs with no correlation; `slog.Info` losing context |
| Consistent levels/keys | Documented levels and snake_case keys reused | Ad-hoc levels; inconsistent keys |
| Low allocation | Typed attrs; guarded debug; bound common fields | `slog.Any` everywhere; building disabled debug strings |
| No secrets/PII | Redacted via LogValuer; ids not values | Secrets/PII/file content in logs |
| Logged once | Each event logged at one meaningful layer | Same error re-logged at every wrap |

---

## Anti-Patterns

- **`fmt.Printf` / `log.Printf` narration** — free text with interpolated values is unsearchable, unindexable, and uncorrelatable. If it matters enough to print, it matters enough to structure.
- **A handler wrapper without `WithAttrs`/`WithGroup`** — the derived logger from `slog.With(...)` silently bypasses the wrapper, and trace correlation vanishes exactly on the pre-bound loggers that log the most.
- **`slog.Info` where a context exists** — dropping `ctx` discards the very trace ids the pipeline pivots on. `InfoContext`/`ErrorContext` wherever a context is in scope.
- **Log-line PII "just for debugging"** — the email logged in a debug line ships to the same indexed, retained store as everything else. Redaction is a type (`LogValuer`), not a code-review hope.
- **Logging in the hot inner loop** — one line per record in a 10k-record batch is 10k allocations and an I/O storm; log the batch summary (count, duration, failures) at the boundary.
- **Same failure logged at every layer** — repo logs it, handler logs it, middleware logs it: three entries, one incident, and triage now dedups by hand. Log where handled, wrap elsewhere.
- **Levels as emphasis** — `Error` for "this is important to me" (a normal cache miss) trains responders to ignore `Error`. Levels encode required action, not enthusiasm.

---

## Output Format

Produces Go source plus tests asserting redaction and correlation:

```
internal/infrastructure/telemetry/logging.go      (slog init, traceHandler)
internal/infrastructure/telemetry/redact.go        (LogValuer secret types)
internal/infrastructure/telemetry/logging_test.go  (asserts no-PII + trace ids present)
```
