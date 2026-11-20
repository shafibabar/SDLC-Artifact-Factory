---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It declines gRPC between Scheduling and Reminders: on the lean profile they are two modules of one deployable, so there is no service boundary inside it and nothing for gRPC to cross; the modules talk through an in-process interface (D047-6; `grpc-up-and-running.md`, Caveats, "gRPC is not a REST replacement... adopted per-boundary where its typing/streaming earns its cost").
2. It declines gRPC for the browser app: browsers cannot speak native gRPC without a gRPC-Web proxy, and the public or browser-facing API stays REST described by OpenAPI (`grpc-up-and-running.md`, Actionable Techniques, "Reserve gRPC for internal service-to-service traffic; keep REST for public and browser-facing APIs").
3. It does not accept "faster" as the reason: it says gRPC is chosen per boundary for a named reason (strict typed contract, streaming, throughput between services), and that no throughput claim is made without measuring (`grpc-up-and-running.md`, Caveats, "No invented numbers or benchmarks"; Applies To, `api-contract-design` row, REST remains the default).
4. It says what would change the answer: if Reminders were later split into its own deployable, that new boundary is where an internal gRPC contract could be designed, written proto-first (`grpc-up-and-running.md`, Core Concepts, "Contract-first with Protocol Buffers"; D047-6).
5. It points the user to the REST and OpenAPI contract (the api-contract-design skill) for the browser-facing API instead of leaving them without a contract, rather than producing a full proto service for either request.
6. It does not assume per-tenant physical isolation or a tenant metadata key, since the request does not say PocketVet is multi-tenant (D047-7).
7. The reply contains no Go, Python or other implementation code. `.proto` fragments and example status codes are the contract and are allowed, and are not counted as code (D047-10).
Fail if any of the 7 is missing.
