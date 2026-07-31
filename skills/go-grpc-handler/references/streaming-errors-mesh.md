# Streaming Handlers, Status/Error Details, Deadlines, Health, and the Linkerd HTTP/2 Caveat

Worked server-side bodies for each of the four gRPC call types, the single domain-error → gRPC status writer with structured details, deadline/cancellation handling, the health service, and the operational config for running gRPC through Linkerd. Continues `server-and-interceptors.md`; same `DataAssetService` example.

---

## 1. Unary — request/response

Already shown in `server-and-interceptors.md` (`GetDataAsset`). Shape: validate → `tenantFromContext` → call application handler with incoming `ctx` → encode or `writeDomainError`.

---

## 2. Server streaming — one request, a stream of responses

The canonical data-estate case: a scan emits `DataAsset`s as it discovers them. Read the request once, then `stream.Send` each result. **Check `stream.Context().Err()` between sends** so a cancelled or timed-out client stops server work immediately.

```go
func (s *DataAssetServer) ScanDataAssets(req *dav1.ScanRequest, stream dav1.DataAssetService_ScanDataAssetsServer) error {
	ctx := stream.Context()
	tenant, err := tenantFromContext(ctx)
	if err != nil {
		return err
	}
	if req.GetSource() == "" {
		return status.Error(codes.InvalidArgument, "source is required")
	}

	assets, errs := s.scanner.Stream(ctx, tenant, req.GetSource())
	for {
		select {
		case <-ctx.Done(): // client cancelled or deadline exceeded — hard stop
			return status.FromContextError(ctx.Err()).Err()
		case err := <-errs:
			return writeDomainError(err)
		case a, ok := <-assets:
			if !ok {
				return nil // channel closed = scan complete
			}
			if err := stream.Send(toProtoDataAsset(a)); err != nil {
				return err // client hung up; err already a status
			}
		}
	}
}
```

---

## 3. Client streaming — a stream of requests, one response

Chunked document ingest: the client streams chunks, the server assembles and returns a single result. Loop on `stream.Recv()` until `io.EOF`, then `SendAndClose`.

```go
import "io"

func (s *DataAssetServer) IngestDocument(stream dav1.DataAssetService_IngestDocumentServer) error {
	ctx := stream.Context()
	tenant, err := tenantFromContext(ctx)
	if err != nil {
		return err
	}

	var buf []byte
	for {
		chunk, err := stream.Recv()
		if err == io.EOF {
			asset, err := s.ingest.Handle(ctx, tenant, buf)
			if err != nil {
				return writeDomainError(err)
			}
			return stream.SendAndClose(&dav1.IngestResponse{Id: asset.ID}) // one response, closes the stream
		}
		if err != nil {
			return err
		}
		if err := ctx.Err(); err != nil {
			return status.FromContextError(err).Err()
		}
		buf = append(buf, chunk.GetData()...)
	}
}
```

---

## 4. Bidirectional streaming — independent read and write streams

A live progress/control channel: the server reads commands and emits progress concurrently over one connection. Both directions share the one `stream`; run the send side in a goroutine keyed off `ctx`.

```go
func (s *DataAssetServer) Progress(stream dav1.DataAssetService_ProgressServer) error {
	ctx := stream.Context()
	tenant, err := tenantFromContext(ctx)
	if err != nil {
		return err
	}
	for {
		msg, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		update, err := s.progress.Apply(ctx, tenant, msg.GetCommand())
		if err != nil {
			return writeDomainError(err)
		}
		if err := stream.Send(&dav1.ProgressUpdate{Percent: update.Percent}); err != nil {
			return err
		}
	}
}
```

---

## 5. One status writer: domain error → gRPC code

Every method funnels errors through `writeDomainError`, exactly as the REST edge funnels through one HTTP error writer. Never return a bare Go `error` (it becomes an opaque `codes.Unknown`), never leak internal strings.

### Domain error → `codes` mapping

| Domain condition | gRPC `codes` | Why (vs the REST collapse to 4xx) |
|---|---|---|
| Missing/blank required field, malformed input | `InvalidArgument` | the request itself is wrong regardless of state |
| Entity not found | `NotFound` | — |
| Unique/duplicate conflict | `AlreadyExists` | distinct from a generic conflict |
| Precondition on current state fails (e.g. asset already classified) | `FailedPrecondition` | the request is valid but the system state forbids it — REST would collapse this and InvalidArgument both to 400 |
| Value out of the valid range | `OutOfRange` | a third case REST also collapses to 400 |
| No/invalid credentials | `Unauthenticated` | — |
| Authenticated but not allowed (wrong tenant) | `PermissionDenied` | — |
| Quota/rate limit hit | `ResourceExhausted` | — |
| Deadline passed / client cancelled | `DeadlineExceeded` / `Canceled` | from `ctx.Err()` via `status.FromContextError` |
| Downstream dependency down | `Unavailable` | retryable by the client |
| Genuine bug / unexpected | `Internal` | reserved — the only code that means "our fault, not yours" |

```go
package grpcserver

import (
	"errors"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/genproto/googleapis/rpc/errdetails"

	"example.com/estate/internal/domain"
)

func writeDomainError(err error) error {
	switch {
	case errors.Is(err, domain.ErrNotFound):
		return status.Error(codes.NotFound, "data asset not found")
	case errors.Is(err, domain.ErrAlreadyClassified):
		return status.Error(codes.FailedPrecondition, "asset already classified")
	case errors.Is(err, domain.ErrValidation):
		return withValidationDetails(err) // structured details, below
	case errors.Is(err, domain.ErrForbidden):
		return status.Error(codes.PermissionDenied, "not permitted for this tenant")
	default:
		// Reserve Internal for genuine bugs; log the real err server-side,
		// return an opaque message — never the internal string.
		return status.Error(codes.Internal, "internal error")
	}
}
```

### Structured, machine-readable details with `status.WithDetails`

Attach a `google.rpc.BadRequest` (from `google.golang.org/genproto/googleapis/rpc/errdetails`) rather than stuffing field errors into the message string. The client reads them back with `status.FromError(err).Details()`.

```go
func withValidationDetails(err error) error {
	st := status.New(codes.InvalidArgument, "validation failed")
	br := &errdetails.BadRequest{
		FieldViolations: []*errdetails.BadRequest_FieldViolation{
			{Field: "classification", Description: "must be one of PUBLIC, INTERNAL, RESTRICTED"},
		},
	}
	withDetails, dErr := st.WithDetails(br)
	if dErr != nil {
		return st.Err() // fall back to code+message if detail marshalling fails
	}
	return withDetails.Err()
}
```

---

## 6. Deadlines and cancellation

The deadline is an absolute time the client sets and the server honors — distinct from an ad-hoc client-local timeout. Server-side it arrives as the context deadline. Treat a done context as a **hard stop**.

```go
func (s *DataAssetServer) Classify(ctx context.Context, req *dav1.ClassifyRequest) (*dav1.ClassifyResponse, error) {
	// Fast-fail if the caller's deadline is already blown before we start work.
	if err := ctx.Err(); err != nil {
		return nil, status.FromContextError(err).Err() // -> DeadlineExceeded / Canceled
	}
	tenant, err := tenantFromContext(ctx)
	if err != nil {
		return nil, err
	}
	// Pass the SAME ctx down so cancellation propagates to pgx, downstream RPCs, etc.
	if err := s.classify.Handle(ctx, tenant, req.GetId(), req.GetLevel().String()); err != nil {
		return nil, writeDomainError(err)
	}
	return &dav1.ClassifyResponse{}, nil
}
```

`status.FromContextError` maps `context.DeadlineExceeded` → `codes.DeadlineExceeded` and `context.Canceled` → `codes.Canceled`. Always derive downstream contexts from the incoming one — do not create a fresh `context.Background()` inside a handler, or you sever cancellation propagation.

---

## 7. Health service

Register the standard `grpc_health_v1` service (shown in `server-and-interceptors.md` §3). It is the gRPC analog of an HTTP `/healthz`; Kubernetes probes it with `grpc_health_probe` (or a native gRPC liveness probe), and Linkerd uses it for readiness. Toggle per-service status as dependencies come and go:

```go
hs.SetServingStatus("dataasset.v1.DataAssetService", healthpb.HealthCheckResponse_NOT_SERVING) // e.g. DB unreachable
```

---

## 8. The Linkerd + gRPC HTTP/2 balancing caveat (operational gotcha, not a formality)

gRPC multiplexes **many requests over one long-lived HTTP/2 connection**. A plain Kubernetes `Service` (kube-proxy / iptables) and any L4/connection-level load balancer make their decision *once, at connect time*, then every subsequent request rides that same connection — so all of a client's traffic pins to the single backend pod it first hit. Load does not spread; scaling the Deployment up does nothing.

Linkerd's data-plane proxy does **per-request L7 balancing over HTTP/2** — it looks inside the connection and distributes individual requests across the available endpoints. This is precisely why the mesh matters for gRPC, and why bypassing it (or exposing gRPC through a plain Service without an L7-aware balancer) silently loses load distribution.

Practical rules:

- Ensure both client and server pods are **meshed** (the `linkerd.io/inject: enabled` annotation on the namespace or Deployment) so the proxy sits in the path and does the per-request balancing.
- Point the client at the **Kubernetes Service DNS name** (`dataasset.svc.cluster.local:PORT`); Linkerd resolves it to the endpoint set and balances per request. Do **not** pre-resolve to a single pod IP.
- **Verify, don't assume**: send sustained gRPC load and confirm traffic actually spreads across pods (e.g. `linkerd viz stat deploy` / per-pod request counts), rather than trusting that the Service distributes it — a plain Service will not.
- For gRPC-heavy paths, a client-side balancing policy (round-robin) is an alternative, but in this repo's meshed stack Linkerd's per-request L7 balancing is the intended mechanism.

Example Deployment annotation:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dataasset-service
  annotations:
    linkerd.io/inject: enabled   # proxy injected -> per-request HTTP/2 L7 balancing
spec:
  template:
    spec:
      containers:
        - name: dataasset
          ports:
            - name: grpc            # named port aids protocol detection
              containerPort: 8443
```
