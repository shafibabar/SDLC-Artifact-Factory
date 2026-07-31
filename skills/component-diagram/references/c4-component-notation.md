# C4 Level 3 (Component) — Notation Reference

Self-contained reference for the notation of a C4 Level 3 Component diagram as
produced by the `enterprise-architect` for a single container in this repo.
Read this together with `layering-and-dependency-rules.md` (the constraint rules
the arrows must obey) and `diagram-template.md` (the artifact template).

---

## 1. Where Level 3 sits in the C4 zoom sequence

C4 (Simon Brown's model) is a deliberately simplified, opinionated profile of
the component-and-connector viewpoint from Clements et al., *Documenting
Software Architectures*. Its four "levels" are a fixed learnable sequence, not
four different kinds of structure:

| Level | Name | Scope of one diagram | Answers |
|---|---|---|---|
| 1 | System Context | The whole system as one box + external systems + people | Who uses it, what it talks to |
| 2 | Container | One system, decomposed into deployable/executable units | Which services/DBs/brokers exist, what protocol flows between them |
| 3 | **Component** | **One container, decomposed into its internal building blocks** | **What are the parts inside this service, and how do they depend on each other** |
| 4 | Code | One component, decomposed to classes (rarely drawn) | The class/struct layout — usually left to the IDE |

A Level 3 diagram is *inside the boundary of exactly one Level 2 container*. You
choose the container at the Container diagram; the Component diagram never
crosses that boundary. If a box in your Level 3 diagram is another service, you
have accidentally drawn a Container diagram.

### The module-view caveat (Clements)

In *Documenting Software Architectures* terms, this repo's component diagram is
really a **layered module view** — a static, compile-time *allowed-to-use*
structure — wearing C&C-style box-and-arrow notation. This matters for what you
must NOT draw: a module view has **no time dimension**. No sequence numbers, no
"request comes in here, then flows to there," no runtime process/thread
annotations. Those belong in a component-and-connector (runtime) view, which
this repo does not currently produce. Keep the Level 3 diagram to
*dependencies*, not *interactions*.

---

## 2. The box: what a component is (and is not)

The single most-misused piece of C4-L3 notation is the box. A **component** is:

> a grouping of related functionality behind a well-defined interface, with a
> single clear responsibility.

It is emphatically **not** a single class, struct, or function. In this repo:

- `handlers/` (the whole HTTP-handler grouping for one aggregate) is **one**
  component — not one box per handler function.
- `infrastructure/postgres/` (the repository implementation) is **one**
  component — not one box per SQL query.
- The `domain/` package is **one** component in a Level 3 diagram, even though
  it contains many Aggregates, Value Objects and Domain Events. You only split
  it into separate boxes if the container genuinely holds two nearly-independent
  domain areas that a reader must see kept apart.

A component maps to a Go **package** (a directory of `.go` files compiled
together), not to a Go type. When you are tempted to draw a box per struct, you
have dropped to Level 4 (Code) and should stop.

### Box contents — the three mandatory labels

Each component box carries three things. The picture's box shape cannot carry
these on its own; the element catalog (Section 5) is where their full form
lives, but the box itself shows a short version:

| Label | Purpose | Example (DataAsset Management service) |
|---|---|---|
| **Name** | What the component *is*, in the ubiquitous language | `DataAsset Repository` |
| **Type / Technology** | What kind of component and what it is built with | `[Go package: infrastructure/postgres, pgx]` |
| **Responsibility** | One sentence — the single reason this component exists | `Persists and reconstitutes the DataAsset Aggregate` |

If a component's responsibility sentence needs the word "and" to join two
unrelated duties, it is two components (SOLID's Single Responsibility Principle,
enforced at diagram time before any code exists).

---

## 3. The relationship arrow (connector)

An arrow in a Level 3 diagram is a **source-code dependency**: "the component at
the tail imports / calls / depends on the component at the head." Every arrow
must obey the Dependency Rule (see `layering-and-dependency-rules.md`) — arrows
point inward, toward the domain.

Each arrow carries a **label** describing the nature of the dependency, and
optionally a **technology**. The label is a verb phrase read tail-to-head:

```
HTTP Handler  ──"maps DTO to Command, calls"──▶  Application Service
Application Service  ──"loads / saves Aggregate via"──▶  DataAsset Repository
DataAsset Repository  ──"implements"──▶  Repository interface (in Domain)
Application Service  ──"reads / mutates"──▶  DataAsset Aggregate (in Domain)
```

Notation rules for arrows:

- **Direction is dependency, not data flow.** The Repository depends on (points
  at) the Domain's `Repository` interface, even though data flows *out* of the
  database *into* the domain at runtime. Source-code direction and runtime
  control-flow direction can be opposite — that opposition is exactly what
  Dependency Inversion buys you.
- **No bidirectional arrows.** Two components pointing at each other is a
  dependency cycle — a defect. Break it by extracting an interface into the
  inner layer.
- **Label every arrow.** An unlabeled arrow is an incomplete connector; the
  reviewer cannot tell a "calls" dependency from an "implements" one.
- **Do not label with a protocol** (HTTP, gRPC, Redpanda topic) *between
  in-process components* — those are compile-time dependencies within one
  process. Protocols belong on the *Container* diagram's arrows, between
  separate processes. The only protocol-bearing arrows at Level 3 are the ones
  leaving the boundary box toward an external container.

---

## 4. The container boundary box

The whole diagram is enclosed in one labeled boundary box representing the
container being decomposed:

```
┌─ DataAsset Management Service  [Container: Go, net/http + chi] ───────────┐
│                                                                            │
│   (components live here, with only inward arrows between them)             │
│                                                                            │
└────────────────────────────────────────────────────────────────────────┘
        │ (arrows leaving the box go to external containers)
        ▼
   PostgreSQL (dataasset schema)      Redpanda (dataasset.events topic)
```

Anything crossing the boundary line is a relationship to another container
(PostgreSQL, Redpanda, another service) — and *those* arrows do carry a
protocol/technology label, because they are inter-process. Anything inside the
box is a component of this one service.

---

## 5. Clements' documentation package — beyond the picture

A picture alone is an *underspecified* view. Per *Documenting Software
Architectures* (Ch. 3, 9), a complete view is a documentation package. For a
Level 3 component diagram, produce at minimum:

1. **Primary presentation** — the diagram itself (Mermaid or textual C4; see
   `diagram-template.md`).
2. **Element catalog** — a table enumerating every component and every
   relationship shown, with the properties the boxes and lines cannot carry:

   | Element | Type / property | What the picture cannot show |
   |---|---|---|
   | Component | Its *interface* (the Go interface or exported API it presents) | `DataAsset Repository` presents `domain.DataAssetRepository` |
   | Component | Its *responsibility*, in full | one paragraph, not the one-line box label |
   | Relationship | Its *nature* | "implements" vs. "calls" vs. "reads" |
   | Relationship | Its *direction rationale* | why this arrow points inward |

3. **Context** — one line restating what this container talks to (its Level 2
   neighbours), so the Level 3 reader has the boundary without re-opening the
   Container diagram.
4. **Variability guide** — what changes per deployment. In this repo, note the
   per-tenant physical isolation: the component structure is identical across
   tenants, but each tenant runs its own instance against its own PostgreSQL
   schema/database — the diagram is one template, instantiated N times.
5. **Rationale** — one or two sentences on any *non-default* structural choice
   (e.g., "the Classification Projector is split from the Repository because it
   writes a separate read-model updated off the event stream, not the write
   path"). This is view-shape rationale, lighter than an ADR; if the reasoning
   is cross-cutting and consequential, promote it to an ADR via `adr-authoring`.

An element catalog and a rationale are the two parts most often skipped and are
exactly what separate a reviewable *specification* from "just a picture."

---

## 6. Notation quick-checklist

Before an `enterprise-architect` hands a Level 3 diagram to `backend-engineer`:

- [ ] Exactly one container boundary box; nothing inside it is another service.
- [ ] Every box is a *package-grouping* component, not a single struct/class.
- [ ] Every box has name, type/technology, and a one-sentence responsibility.
- [ ] Every arrow is labeled and points *inward* (toward the domain).
- [ ] No bidirectional arrows and no dependency cycles.
- [ ] No sequence numbers, no runtime timeline (this is a module view).
- [ ] Protocols appear only on arrows crossing the boundary box.
- [ ] An element catalog and a one-line rationale accompany the picture.
