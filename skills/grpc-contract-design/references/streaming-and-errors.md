# Streaming Patterns, Status Codes, Deadlines & Metadata

Reference material for `grpc-contract-design`. Covers the four communication patterns with worked proto and a selection guide, the full gRPC status-code taxonomy, structured error details, and the deadline/metadata conventions with Go snippets.

---

## The Four Communication Patterns

gRPC exposes exactly four method shapes. The shape is chosen **per method** with the `stream` keyword on the request type, the response type, or both.

```protobuf
service EstateScanService {
  // 1. Unary — one request, one response.
  rpc GetScanStatus(GetScanStatusRequest) returns (ScanStatus);

  // 2. Server streaming — one request, a stream of responses.
  rpc StreamScanResults(StreamScanRequest) returns (stream DataAsset);

  // 3. Client streaming — a stream of requests, one response.
  rpc UploadDocument(stream DocumentChunk) returns (UploadReceipt);

  // 4. Bidirectional streaming — independent read and write streams.
  rpc ScanProgress(stream ProgressPing) returns (stream ProgressUpdate);
}
```

### Selection guide

| Pattern | Wire shape | Choose when | Data-estate example | Cost / caveat |
|---|---|---|---|---|
| **Unary** | 1 → 1 | Request/response commands and point reads. The default. | `GetDataAsset`, `ClassifyDataAsset` | None — start here |
| **Server streaming** | 1 → N | The response set is large or open-ended and the client benefits from results as they are produced | An estate scan emitting each `DataAsset` as it is discovered | Client must handle partial results and mid-stream errors |
| **Client streaming** | N → 1 | The request is large and assembled server-side; the client sends chunks then gets one summary | Chunked ingest of a large PDF/DOCX/XLSX document | Server holds partial state until the client half-closes |
| **Bidirectional** | N ↔ N | Both sides send independently over one long-lived connection; live/interactive | A live scan-progress control+telemetry channel | Hardest to load-balance and retry; needs explicit flow control |

**Rule of thumb:** default to unary. A method earns a streaming shape only when the data flow *is* a stream — an unbounded/large result set, a chunked upload, or a live channel. Streaming complicates retries (a half-consumed server stream cannot be blindly re-sent), load balancing (see the Linkerd caveat), and backpressure. Do not reach for bidirectional when a server stream plus periodic unary polls would do.

### Go server signatures (generated interface)

```go
// Unary
func (s *scanServer) GetScanStatus(ctx context.Context, req *scanv1.GetScanStatusRequest) (*scanv1.ScanStatus, error)

// Server streaming — push each result, return nil to end the stream.
func (s *scanServer) StreamScanResults(req *scanv1.StreamScanRequest, stream scanv1.EstateScanService_StreamScanResultsServer) error {
    for asset := range s.discover(stream.Context(), req.TenantId) {
        if err := stream.Send(asset); err != nil {
            return err // client went away or deadline passed
        }
    }
    return nil
}

// Client streaming — Recv until io.EOF, then SendAndClose one response.
func (s *scanServer) UploadDocument(stream scanv1.EstateScanService_UploadDocumentServer) error {
    var total int64
    for {
        chunk, err := stream.Recv()
        if err == io.EOF {
            return stream.SendAndClose(&scanv1.UploadReceipt{Bytes: total})
        }
        if err != nil {
            return err
        }
        total += int64(len(chunk.Data))
    }
}

// Bidirectional — interleave Recv and Send; both close independently.
func (s *scanServer) ScanProgress(stream scanv1.EstateScanService_ScanProgressServer) error {
    for {
        ping, err := stream.Recv()
        if err == io.EOF {
            return nil
        }
        if err != nil {
            return err
        }
        if err := stream.Send(&scanv1.ProgressUpdate{Seen: ping.Cursor}); err != nil {
            return err
        }
    }
}
```

---

## The gRPC Status-Code Model

Every call — unary or streaming — terminates with a status: a **code** (integer enum), a **message** string, and optional structured **details**. This is transport-independent and richer than HTTP status. In Go, statuses are built with the `google.golang.org/grpc/codes` and `.../status` packages.

### Full code taxonomy

| # | Code | Meaning | Retryable? |
|---|---|---|---|
| 0 | `OK` | Success | — |
| 1 | `CANCELLED` | Caller cancelled the operation | No |
| 2 | `UNKNOWN` | Unknown error (e.g. a panic surfaced without a code) | No |
| 3 | `INVALID_ARGUMENT` | Client sent a malformed argument, **independent of system state** | No |
| 4 | `DEADLINE_EXCEEDED` | Deadline elapsed before the operation completed | Maybe (idempotent only) |
| 5 | `NOT_FOUND` | Requested entity does not exist | No |
| 6 | `ALREADY_EXISTS` | Entity a client tried to create already exists | No |
| 7 | `PERMISSION_DENIED` | Authenticated but not authorized for this operation | No |
| 8 | `RESOURCE_EXHAUSTED` | Quota exhausted / rate limited | Maybe (with backoff) |
| 9 | `FAILED_PRECONDITION` | Operation rejected because the **system is not in the required state** | No (fix state first) |
| 10 | `ABORTED` | Concurrency conflict (e.g. optimistic-lock/transaction abort) | Yes (retry the whole txn) |
| 11 | `OUT_OF_RANGE` | Argument outside the valid range (distinct from `INVALID_ARGUMENT`) | No |
| 12 | `UNIMPLEMENTED` | Method not implemented / not supported | No |
| 13 | `INTERNAL` | Genuine internal bug — an invariant was broken | No |
| 14 | `UNAVAILABLE` | Transient — service is down/overloaded | Yes (with backoff) |
| 15 | `DATA_LOSS` | Unrecoverable data loss or corruption | No |
| 16 | `UNAUTHENTICATED` | Missing or invalid credentials | No |

### The `INVALID_ARGUMENT` vs `FAILED_PRECONDITION` vs `OUT_OF_RANGE` distinction

All three become `400` in REST, but here they are separate and load-bearing:

- **`INVALID_ARGUMENT`** — the request is wrong *regardless of state*. Retrying the identical request will always fail. E.g. `sensitivity_level` outside the enum.
- **`FAILED_PRECONDITION`** — the request would be fine, but the *system state* forbids it now. E.g. classifying an asset whose scan is not yet complete. The client can succeed later once state changes.
- **`OUT_OF_RANGE`** — a specific "past the valid range" case (e.g. reading beyond the end of a paged stream) that a client can detect and stop on, unlike a generic bad argument.

### One status writer

Map domain errors to codes in a single place, exactly as the REST edge funnels errors through one error writer. Never leak internal error strings across the boundary; reserve `INTERNAL` for genuine bugs.

```go
func toStatus(err error) error {
    switch {
    case errors.Is(err, domain.ErrDataAssetNotFound):
        return status.Error(codes.NotFound, "data asset not found")
    case errors.Is(err, domain.ErrScanIncomplete):
        return status.Error(codes.FailedPrecondition, "estate scan not complete")
    case errors.Is(err, domain.ErrForbidden):
        return status.Error(codes.PermissionDenied, "not permitted for tenant")
    case errors.As(err, &domain.ValidationError{}):
        return status.Error(codes.InvalidArgument, err.Error()) // safe, user-facing
    default:
        // A real bug — do not leak err.Error() to the client.
        log.Error("unhandled", "err", err)
        return status.Error(codes.Internal, "internal error")
    }
}
```

---

## Structured Error Details

Beyond code+message, gRPC carries machine-readable **details** using the `google.rpc.Status` message, whose `details` is a `repeated google.protobuf.Any`. The canonical detail payloads live in `google/rpc/error_details.proto`:

| Detail type | Carries |
|---|---|
| `ErrorInfo` | `reason` (a stable UPPER_SNAKE enum-like string), `domain`, and a `metadata` map — the primary machine-readable "why" |
| `BadRequest` | `field_violations[]` (`field`, `description`) — the analog of the REST `details` array of field errors |
| `PreconditionFailure` | `violations[]` (`type`, `subject`, `description`) — pairs with `FAILED_PRECONDITION` |
| `QuotaFailure` | `violations[]` (`subject`, `description`) — pairs with `RESOURCE_EXHAUSTED` |
| `RetryInfo` | `retry_delay` (a `Duration`) — how long a client should wait before retrying |
| `RequestInfo` | `request_id`, `serving_data` — correlation for support/tracing |

In Go, attach details with `status.New(code, msg).WithDetails(&errdetails.BadRequest{...})` and return `st.Err()`. Clients read them back with `status.Convert(err).Details()`. Prefer `ErrorInfo.reason` as the stable programmatic contract — the human `message` may change, the `reason` must not.

---

## Deadlines and Cancellation

A **deadline** is an absolute time the *client* sets and gRPC propagates to the server, distinct from an ad-hoc client-local timeout: the server actually observes it via its `context.Context` and can stop work.

```go
// Client — set a deadline on every call.
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()
asset, err := client.GetDataAsset(ctx, &assetv1.GetDataAssetRequest{...})
// If the deadline passes, err has status code DEADLINE_EXCEEDED.
```

Server-side rules:

- **Derive downstream contexts from the incoming one.** When you call pgx, Redpanda, or another gRPC service, pass the request's `ctx` so the deadline and cancellation flow through. A pgx query with the propagated context is cancelled server-side when the caller gives up.
- **Treat a done context as a hard stop, not advisory.** Check `ctx.Err()` in long loops and streaming sends; abandon work when it is non-nil.
- **Never start a new absolute timeout that outlives the incoming deadline** — that orphans work the client no longer awaits.
- A streaming `Send`/`Recv` returns an error once the deadline passes; return it upward rather than swallowing it.

---

## Metadata Conventions

**Metadata** is gRPC's key/value header/trailer channel — the analog of HTTP headers — carried on the call and read/written via context. It is where auth, tenancy, and tracing ride.

| Metadata key | Carries | Notes |
|---|---|---|
| `authorization` | `Bearer <jwt>` | Validated by an auth interceptor before the method runs; the method reads claims from context, never re-parses the token |
| `x-tenant-id` | The tenant claim | Extracted by a tenant interceptor; drives per-tenant physical isolation (schema/DB routing). Never trust a tenant id from the request body over the authenticated metadata value |
| `traceparent` / `tracestate` | W3C trace context | OpenTelemetry propagation; the gRPC OTel interceptor reads/writes these so spans stitch across services |
| `-bin` suffixed keys | Binary values | gRPC base64-encodes any metadata key ending in `-bin` on the wire |

```go
// Server — read the tenant claim from incoming metadata.
md, _ := metadata.FromIncomingContext(ctx)
if vals := md.Get("x-tenant-id"); len(vals) == 1 {
    tenantID = vals[0]
}

// Server — send response metadata (header) and trailers.
_ = grpc.SendHeader(ctx, metadata.Pairs("x-request-id", reqID))
grpc.SetTrailer(ctx, metadata.Pairs("x-rows-scanned", strconv.Itoa(n)))
```

Cross-cutting reads/writes of metadata belong in **interceptors** (the chi-middleware analog), keeping the generated method body thin: decode → validate → domain → encode. Auth-token validation, tenant extraction, trace propagation, logging, metrics, and panic recovery all live in a unary interceptor and a matching stream interceptor — the streaming variant wraps `ServerStream` to observe individual messages. Implementing those interceptors is the concern of `go-grpc-handler`; this skill only fixes the metadata contract they operate on.
