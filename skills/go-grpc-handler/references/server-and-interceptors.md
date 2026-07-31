# gRPC Server and Interceptors — Full Go Implementation

Complete, copyable server setup for an internal gRPC service in this repo's stack (Go, per-tenant physical isolation, OpenTelemetry, Linkerd mesh). Assumes a `.proto` compiled with `protoc-gen-go` + `protoc-gen-go-grpc` (see `grpc-contract-design`). The service here is a `DataAssetService` for the data-estate product.

---

## 1. Regeneration (build step, run via the Bash tool)

```bash
# From the module root; requires protoc + the Go plugins on PATH, or use `buf generate`.
protoc \
  --go_out=. --go_opt=paths=source_relative \
  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
  proto/dataasset/v1/dataasset.proto
```

`protoc-gen-go` emits the message types and `dataasset.pb.go`; `protoc-gen-go-grpc` emits `dataasset_grpc.pb.go` containing the `DataAssetServiceServer` interface, the `UnimplementedDataAssetServiceServer` embed, and `RegisterDataAssetServiceServer`. The generated code is checked in (or built in CI) — a proto change that breaks compatibility surfaces as a Go compile break, not a production error.

---

## 2. The service implementation (the Humble Object)

The struct embeds `UnimplementedDataAssetServiceServer` so adding a new RPC to the proto does not break the build, and holds only application-layer dependencies — never a DB pool directly (that is injected one layer in).

```go
package grpcserver

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	dav1 "example.com/estate/proto/dataasset/v1"
	"example.com/estate/internal/app"
)

// DataAssetServer implements the generated dav1.DataAssetServiceServer.
// It is a thin adapter: validate -> call application layer -> encode/map error.
type DataAssetServer struct {
	dav1.UnimplementedDataAssetServiceServer
	classify app.ClassifyHandler // command handler from go-service-layer
	getByID  app.GetByIDHandler  // query handler
}

func NewDataAssetServer(classify app.ClassifyHandler, get app.GetByIDHandler) *DataAssetServer {
	return &DataAssetServer{classify: classify, getByID: get}
}

// GetDataAsset is a unary method: validate -> call -> encode / map error.
func (s *DataAssetServer) GetDataAsset(ctx context.Context, req *dav1.GetDataAssetRequest) (*dav1.DataAsset, error) {
	if req.GetId() == "" {
		return nil, status.Error(codes.InvalidArgument, "id is required")
	}
	tenant, err := tenantFromContext(ctx) // set by the auth interceptor
	if err != nil {
		return nil, err
	}
	asset, err := s.getByID.Handle(ctx, tenant, req.GetId())
	if err != nil {
		return nil, writeDomainError(err) // single status writer (see streaming-errors-mesh.md)
	}
	return toProtoDataAsset(asset), nil
}
```

---

## 3. Server construction and graceful shutdown

The composition root (`go-service-skeleton`) calls this, having already built `classify`/`get`. Interceptors are passed as `grpc.ServerOption`s; order in the chain is outermost-first.

```go
package grpcserver

import (
	"context"
	"net"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"

	dav1 "example.com/estate/proto/dataasset/v1"
)

func New(impl *DataAssetServer, tp TokenParser, log Logger) *grpc.Server {
	srv := grpc.NewServer(
		// Order matters: recovery OUTERMOST so it wraps everything below it,
		// then tracing, then auth, then logging closest to the handler.
		grpc.ChainUnaryInterceptor(
			RecoveryUnary(log),
			TracingUnary(),
			AuthUnary(tp),
			LoggingUnary(log),
		),
		grpc.ChainStreamInterceptor(
			RecoveryStream(log),
			TracingStream(),
			AuthStream(tp),
			LoggingStream(log),
		),
	)

	dav1.RegisterDataAssetServiceServer(srv, impl)

	// Standard gRPC health service — unauthenticated, probed by K8s and the mesh.
	hs := health.NewServer()
	healthpb.RegisterHealthServer(srv, hs)
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)

	return srv
}

func Serve(ctx context.Context, srv *grpc.Server, lis net.Listener) error {
	go func() {
		<-ctx.Done()
		srv.GracefulStop() // drains in-flight RPCs, then stops accepting
	}()
	return srv.Serve(lis)
}
```

---

## 4. Auth + tenant-extraction interceptor (first real concern after recovery/tracing)

Reads the bearer token and tenant ID from **metadata**, never from the request body — a tenancy-isolation requirement under per-tenant physical isolation.

```go
package grpcserver

import (
	"context"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type ctxKey string

const tenantKey ctxKey = "tenant"

// AuthUnary validates the token and injects the tenant into ctx.
func AuthUnary(tp TokenParser) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		newCtx, err := authenticate(ctx, tp)
		if err != nil {
			return nil, err
		}
		return handler(newCtx, req)
	}
}

func AuthStream(tp TokenParser) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		newCtx, err := authenticate(ss.Context(), tp)
		if err != nil {
			return err
		}
		return handler(srv, &wrappedServerStream{ServerStream: ss, ctx: newCtx})
	}
}

func authenticate(ctx context.Context, tp TokenParser) (context.Context, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}
	auth := md.Get("authorization")
	if len(auth) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization token")
	}
	claims, err := tp.Parse(auth[0])
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid token")
	}
	return context.WithValue(ctx, tenantKey, claims.TenantID), nil
}

func tenantFromContext(ctx context.Context) (string, error) {
	t, ok := ctx.Value(tenantKey).(string)
	if !ok || t == "" {
		return "", status.Error(codes.PermissionDenied, "no tenant in context")
	}
	return t, nil
}
```

---

## 5. Panic-recovery interceptor (registered OUTERMOST)

A panic in a method must never kill the HTTP/2 connection or leak a stack trace. Recovery is outermost so it wraps every other interceptor and the handler.

```go
func RecoveryUnary(log Logger) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
		defer func() {
			if r := recover(); r != nil {
				log.Error("panic recovered", "method", info.FullMethod, "panic", r)
				err = status.Error(codes.Internal, "internal error") // no stack leaked to client
			}
		}()
		return handler(ctx, req)
	}
}

func RecoveryStream(log Logger) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
		defer func() {
			if r := recover(); r != nil {
				log.Error("panic recovered", "method", info.FullMethod, "panic", r)
				err = status.Error(codes.Internal, "internal error")
			}
		}()
		return handler(srv, ss)
	}
}
```

---

## 6. Logging interceptor (records method, code, latency)

```go
import (
	"time"

	"google.golang.org/grpc/status"
)

func LoggingUnary(log Logger) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		start := time.Now()
		resp, err := handler(ctx, req)
		log.Info("unary call",
			"method", info.FullMethod,
			"code", status.Code(err).String(), // gRPC code, not HTTP status
			"duration_ms", time.Since(start).Milliseconds(),
		)
		return resp, err
	}
}
```

---

## 7. OpenTelemetry tracing interceptor

Extract the propagated trace context from metadata, start a server span, put the span context back on `ctx`. In practice prefer the community `otelgrpc` `StatsHandler`, but the hand-rolled shape shows the mechanism.

```go
import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
)

func TracingUnary() grpc.UnaryServerInterceptor {
	prop := otel.GetTextMapPropagator()
	tracer := otel.Tracer("grpc-server")
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		md, _ := metadata.FromIncomingContext(ctx)
		ctx = prop.Extract(ctx, metadataCarrier(md)) // trace context rides in metadata
		ctx, span := tracer.Start(ctx, info.FullMethod)
		defer span.End()
		return handler(ctx, req)
	}
}

// metadataCarrier adapts grpc metadata.MD to propagation.TextMapCarrier.
type metadataCarrier metadata.MD

func (c metadataCarrier) Get(k string) string {
	if v := metadata.MD(c).Get(k); len(v) > 0 {
		return v[0]
	}
	return ""
}
func (c metadataCarrier) Set(k, v string) { metadata.MD(c).Set(k, v) }
func (c metadataCarrier) Keys() []string {
	out := make([]string, 0, len(c))
	for k := range c {
		out = append(out, k)
	}
	return out
}
```

---

## 8. wrappedServerStream — overriding Context on a stream

A stream interceptor cannot mutate the incoming `context.Context` directly (it is reached via `ss.Context()`), so to inject the authenticated tenant/trace context into a streaming method you wrap `grpc.ServerStream` and override `Context()`. The same wrapper is where you would override `SendMsg`/`RecvMsg` to observe individual messages.

```go
type wrappedServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedServerStream) Context() context.Context { return w.ctx }
```

---

The four call-type handler bodies, the domain-error → `codes` mapping table, `status.WithDetails`, deadline handling, and the Linkerd HTTP/2 balancing config live in `streaming-errors-mesh.md`.
