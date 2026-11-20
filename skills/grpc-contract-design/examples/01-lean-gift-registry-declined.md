# Example 1 — Lean: Two Modules of One Deployable Asking for gRPC

Self-contained. **Giftlist** is a gift registry app for a small wedding-shop chain. **Lean** profile, one deployable (a modular monolith) with one database and three modules: **Registries**, **Contributions** and **Reminders**. The storefront is a web app in the browser.

## Input

> **User:** "Let's use gRPC between the modules, it's faster, and for the storefront too so everything is one style."

## Working it

- **Is there a service boundary?** No. The modules are one process; a call between them is a plain call inside the deployable. gRPC adds a contract to maintain, generated code and a network hop that nothing needs. The boundary question comes first, and here the answer is no.
- **"It's faster"** is not a reason. gRPC is chosen per boundary for a named reason: an internal service-to-service call that benefits from a strict typed contract, a real streaming need, or measured throughput. None applies, and no number was given.
- **The storefront** is a browser. Browsers cannot speak native gRPC without a gRPC-Web proxy, so a browser-facing API stays REST with an OpenAPI contract (`api-contract-design`), whatever the modules do inside.
- **Cost of the strictness.** A Protobuf contract couples every producer and consumer to one schema and needs a compatibility gate in CI. That is worth paying across a service boundary and not between two modules a developer can change in one commit.
- **When the answer would change:** a module becomes its own deployable; a service-to-service boundary needs streaming (a live feed); or a measured throughput need appears that REST cannot meet. Then the boundary gets a proto, with the reason recorded in the Integration Design.
- **No tenant metadata key or isolation** is assumed: Giftlist is one chain.

## Output: the reply (no proto at lean)

> **No gRPC for Giftlist.**
>
> - **Between the modules:** they are one process, so a plain call is enough. There is no service boundary to put a contract on.
> - **For the storefront:** it is a browser, so it stays REST with an OpenAPI contract (see `api-contract-design`); browsers would need a gRPC-Web proxy, and gRPC is for internal service-to-service calls.
> - **"Faster"** is not a reason on its own; gRPC is chosen per boundary for a named reason (a strict typed contract, streaming, measured throughput).
> - **I would revisit** when a module becomes its own service, a feed needs streaming, or a measured need appears. Then the contract is written first as a proto, field numbers are permanent, and a breaking-change check runs in CI.
>
> No gRPC contract is produced at lean.
