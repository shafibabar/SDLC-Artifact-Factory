# Service Decomposition

How Bounded Contexts become deployables. Self-contained. Moved here from `bounded-context-mapping` under D047-6 and reworked: the old "one Bounded Context = one service" default is gone. Sources: `research/software-architecture/software-architecture-hard-parts-ford.md` (granularity disintegrators and integrators, data ownership), `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md` (characteristics as trade-offs, fitness functions), `research/software-architecture/building-microservices-newman.md` (Conway's Law, smart endpoints and dumb pipes), `research/software-architecture/c4-model-brown.md` (modular monoliths and microservices in C4).

Run it after the Context Map is approved. The Context Map says where the languages end; this decides how many things are deployed. They are different questions: a context boundary is drawn on language and model, a deployable boundary on operational forces.

---

## 1. Words

- **Deployable:** one thing built, released and run on its own (a service, or the one application of a modular monolith). It may have several containers: an API, a worker, its database.
- **Module:** a context inside a deployable, with its own package, its own tables or schema, and a published interface the other modules call in-process.
- **Write authority:** the one deployable that writes an Aggregate's records.

## 2. The Starting Point by Profile

| Profile | Start | Splits |
|---|---|---|
| Lean | One modular monolith: every context a module | None, unless a disintegrator is so strong the product can't run without it (rare; say why) |
| Standard | The modular monolith, or the groups the Context Map's coupling already suggests | Each split names a disintegrator with evidence and the integrators it overrides |
| Enterprise | The same | The same; split decisions that are costly to reverse get an ADR |

A modular monolith is not a failure to decompose (Brown: one application container plus its database, the modules as its components). It keeps the context boundaries as module boundaries, so a later split moves a module, not a model.

## 3. The Two Checklists (Hard Parts)

Run both for every candidate split and record the forces each way.

**Disintegrators: reasons to split.**

| Force | Evidence that counts |
|---|---|
| Scope and function | The part has one cohesive purpose unrelated to its neighbours |
| Code volatility | It changes far more often than the rest (a release cadence, a churning rule set) |
| Scalability and throughput | An NFR scenario needs it to scale on its own (a burst, a batch, a hot path) |
| Fault tolerance | Its failure must not take its neighbours down (a flaky third party behind it) |
| Security | Its data or operations need stricter isolation (regulated records, payments) |
| Extensibility | It is a plug-in surface that must evolve without touching the core |

**Integrators: reasons to keep together.**

| Force | Evidence that counts |
|---|---|
| Database transactions | Two parts must commit together; split, they need a saga |
| Workflow chattiness | Most requests cross between them several times |
| Shared code | Much tightly coupled logic would be duplicated or turned into a fragile shared library |
| Data relationships | They join each other's data constantly |

Characteristics trade against each other (Richards & Ford): a split buys independent deployability or isolation and pays for it in latency, consistency and operations. Name both sides; "microservices are the default" is not a reason.

**Team ownership is a constraint, not a disintegrator** (Newman's Conway's Law; Brown). Every deployable has one owning team. A service another team builds and runs is not a container of this system; it is an external system on the context diagram.

## 4. Rules at Every Profile

- **One write authority per Aggregate.** A context may run as an API and a worker (two containers of one deployable). If a context is ever split across deployables, one is the write authority; the others read through a Read Model or an event, never the write tables.
- **No shared database between deployables.** A schema two deployables write is an unmanaged shared model (Hard Parts calls joint ownership something to avoid). In a modular monolith: one database, one schema or table set per module, no module queries another's tables.
- **Cross-deployable data:** ask the owner (an API call), or keep a copy fed by its events. Name which, per consumer.
- **Never one service per Aggregate, per table or per use case.** Aggregates are consistency units inside a context; tables are storage; use cases are behaviour. Each produces a mesh of chatty calls with no language boundary to justify it.
- **Never a context split for "cleanliness".** If no disintegrator is named, it stays together.

## 5. Merging Contexts Into One Deployable

Merging is a deployment decision; the domain model doesn't change. Keep the boundary as a module boundary:
- each module has its own package and tables; the others call its published interface in-process;
- no module imports another's internals (the stack's layout: `go-project-structure`);
- events between modules still go through the outbox if other deployables consume them.

Valid reasons: lean profile; an integrator dominates; the team can't yet run several deployables; both are Supporting or Generic with little behaviour.

## 6. Splitting

Valid reasons are disintegrators with evidence (§ 3). Common shapes:
- **An ingestion or batch part** with a different scaling profile from the interactive part: a worker container of the same deployable first; a separate deployable only if it also needs a separate release or isolation.
- **A regulated part** (health or payment data) isolated for security: its own deployable and database.
- **A part behind a flaky third party**, isolated for fault tolerance.

## 7. Naming

- A deployable is named for the context or contexts it holds, in the product's language (`appointments`, `clinical-records`), never a technical suffix soup (`asset-svc-api`).
- A modular monolith is named for the product (`boxoffice`), its modules for their contexts.
- Database, schema, topic prefix and chart names follow the deployable name, so the deployment view and the manifests can be traced back.

## 8. Fitness Functions

A rule nobody checks drifts (Richards & Ford). For each rule this decomposition relies on, name the automated check, in the artifact:
- module boundaries: an import test that fails the build when one module imports another's internals;
- one schema per module: a check that no query in a module touches another module's tables;
- one write authority: a check that only the owning deployable has write grants on its tables;
- no synchronous chain longer than one hop between deployables: a dependency check over the communication matrix.

## 9. Anti-Patterns

| Anti-pattern | How it shows | Instead |
|---|---|---|
| One context, one service, by default | A lean product with five deployables | Modular monolith; split on a named force |
| Distributed monolith | Every request crosses three services synchronously | Merge on the workflow integrator, or go async |
| Shared database | Two deployables write one schema | One owner; API or events for the other |
| Service per Aggregate or table | Tiny services that orchestrate each other | One deployable per context group |
| Split for team count | A second team invents a second service in one context | A team is a constraint; another team's system is external |
| Big-bang split later | No module boundaries in the monolith | Modules from day one, with fitness functions |
