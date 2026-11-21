# C4 Level 3 (Component): Notation

Reference for `component-diagram`. Self-contained: where Level 3 sits, what a component box is, how arrows are drawn and labelled, the container boundary, and the documentation package a complete view needs. The constraint the arrows obey is in `layering-and-dependency-rules.md`.

## 1. Where Level 3 Sits

C4 (Brown, `research/software-architecture/c4-model-brown.md`) is a fixed zoom sequence:

| Level | Scope of one diagram | Answers |
|---|---|---|
| 1 System Context | The whole system, its people and external systems | Who uses it, what it talks to |
| 2 Container | One system, as runnable units | Which apps, APIs, databases, brokers exist; what protocol between them |
| **3 Component** | **One container, as its building blocks** | **What the parts inside this service are, and how they depend on each other** |
| 4 Code | One component, as classes or tables | Usually generated from code, rarely drawn |

A Level 3 diagram stays inside one Level 2 container. A box in it that is another service means you are drawing a container diagram.

**Brown's supplementary diagrams** sit beside the four: the **dynamic diagram** shows how elements collaborate at runtime for one feature, with **numbered interactions**; the **deployment diagram** shows where containers run (here, the container diagram's deployment view section). Step numbers and runtime order belong in a dynamic diagram, never on Level 3.

### The module-view caveat (Clements)

In *Documenting Software Architectures* terms (`documenting-software-architectures-clements.md`) this diagram is a **layered module view**: a static, compile-time *allowed-to-use* structure drawn in box-and-arrow notation. A module view has no time dimension: no sequence numbers, no "request enters here, then flows there", no process or thread annotations. It shows dependencies, not interactions.

## 2. The Box

A **component** is a grouping of related functionality behind a well-defined interface, inside one container, running in its process and not separately deployable (Brown). It is **not** a single class, struct or function:
- The entry-point grouping for a context (all its HTTP handlers) is **one** component, not one box per handler function.
- The persistence adapter is **one** component, not one box per query.
- The domain is **one** component unless the container genuinely holds two nearly independent domain areas a reader must see kept apart.

A component usually maps to a package or module. A box per type means you have dropped to Level 4.

**Three labels on every box:**

| Label | Purpose | Example |
|---|---|---|
| Name | What it is, in the Ubiquitous Language | `Locker Controller Adapter` |
| Type and technology | What kind of component, built with what | `[Component: adapter, Go package infrastructure/lockervendor]` |
| Responsibility | One sentence: the single reason it exists | `Translates the vendor's controller API into domain commands and events` |

A responsibility joining two unrelated duties with "and" is two components (SOLID's single responsibility, applied before any code exists).

## 3. Arrows

An arrow is a **source-code dependency**: the tail imports, calls or implements something of the head. Every arrow obeys the Dependency Rule: it points inward, toward the domain.
- **Label every arrow** with a verb phrase read tail to head: "maps requests to commands and calls", "loads and saves via", "implements". An unlabelled arrow can't be told apart from another kind.
- **Direction is dependency, not data flow.** A persistence adapter points at the domain's port it implements, although at runtime data flows from the database into the domain. That opposition is what Dependency Inversion buys.
- **Never two-way.** Two components pointing at each other form a cycle; break it with an interface in the inner ring.
- **No protocol on in-process arrows.** HTTP, gRPC, SQL or a topic name belong on arrows that leave the boundary to another container, and only there.
- **Implements** arrows may be drawn dashed to set them apart from calls; the key says so.

## 4. The Boundary

The whole picture sits inside one boundary box named for the container and its technology. Arrows that cross the boundary go to other containers (its database, the broker, an external system) and carry a protocol.

```
+-- Locker Service [Container: API, Go, chi] ----------------------------+
|                                                                        |
|   components here, arrows between them point inward, no protocols      |
|                                                                        |
+------------------------------------------------------------------------+
        | SQL                          | Kafka protocol
        v                              v
  [Container: Database]          [Container: Broker]
  Locker DB, PostgreSQL          Event Broker, Redpanda
```

## 5. ASCII Primary, Mermaid Optional

One rule for all three C4 levels (D047-13): the primary presentation is **ASCII** inside a fenced block, with the element catalog tables beside it. A Mermaid `C4Component` copy (or a flowchart) may follow when a viewer renders it; it is never the only picture. ASCII survives every Markdown viewer and diff, and the product owner can review it without tooling.

## 6. The Documentation Package (Clements)

A picture alone is underspecified. A complete Level 3 view carries:
1. **Container context:** one line naming the container and its Level 2 neighbours (database, topics, services it calls), so the reader has the boundary without reopening the container diagram.
2. **Primary presentation:** the ASCII picture and its **key** (box types, solid call, dashed implements, what an arrow means).
3. **Element catalog:** every component (role, package or module, the interface it presents, its responsibility in full) and every relationship (from, to, nature, why it points that way).
4. **Dependency Rule statement:** where each port is declared, and that the domain imports only the standard library.
5. **Fitness function:** the named automated check (see `layering-and-dependency-rules.md` § 6).
6. **Variability:** what differs per deployment, taken from the container diagram's deployment view and `multi-tenancy-design`. The component structure is the same in every instance; what varies (instances per region, a siloed tenant's own database) is configuration, not structure. Never assume a per-tenant stamp.
7. **Rationale:** a sentence or two for each departure from the default skeleton. Cross-cutting, consequential reasoning becomes an ADR (`adr-authoring`).

The catalog and the rationale are the parts most often skipped, and they are what make the picture a specification.
