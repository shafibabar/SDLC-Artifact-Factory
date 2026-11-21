# Foreign Models and Cross-Context Data

Reference for `integration-design`. Self-contained: the anti-corruption layer, the three ways one context reads another's data, Change Data Capture, and why a shared database is never one of them. Roles and rules; the code for the configured stack lives in backend-engineer's skills.

## 1. Anti-Corruption Layer

A translation adapter at a boundary where a **foreign model** (an external vendor's API, or another context whose model differs) would otherwise leak into the domain. It is `context-map-patterns`' anti-corruption layer relationship made concrete. **A foreign model never appears in the domain.**

**Three parts:**
- **Port:** declared by the domain in its own language ("look up a delivery slot", "reserve stock"), with domain types.
- **Client:** speaks the foreign API: its endpoints, field names, error codes, authentication. Carries the resilience from `resilience-patterns.md`.
- **Translator:** the only place the two vocabularies meet. It maps foreign shapes to domain types and back, validates, and turns foreign error codes into domain outcomes.

The domain imports the port, never the client. The foreign wire shapes belong to the adapter, not to the domain.

**Translate only what the domain uses** (stamp coupling, Ford, `research/software-architecture/software-architecture-hard-parts-ford.md`): a new vendor field nobody reads is ignored, so it never forces a domain change.

**Testing in isolation:** the translator with table tests of foreign payloads (including malformed ones), no network; the client against a stub server returning canned foreign responses; the domain against an in-memory fake of the port.

## 2. Reading Another Context's Data

When one context needs data another owns (references across Aggregates are by id only, `data-model-design`), there are three legitimate options. Name the one chosen per read path, and why the others weren't.

| Option | How | Freshness | Cost | Use when |
|---|---|---|---|---|
| **API composition** | Call the owner live at read time | Always fresh | The owner must be up on your read path: a sync hop with its resilience | Data changes fast, staleness unacceptable, modest read volume |
| **Event replication** | The owner publishes Domain Events; you project a local Read Model (`read-model-design`) | Eventual | You maintain and can rebuild a projection | You read often, can tolerate lag, want independence from the owner |
| **Change Data Capture** | Stream the owner's database log into events; project them | Eventual | Connector infrastructure; you depend on the owner's table schema | The owner **cannot** publish events (legacy, third-party, another team's fixed system) |

**Choosing:** event replication for services you own that publish Domain Events; API composition when freshness matters and the extra hop is acceptable; Change Data Capture only as the non-invasive last resort.

Ford's data-ownership terms: **single owner and delegate** (one service owns the data; others ask it: API composition). **Joint ownership** (two services writing the same data) is a red flag: the boundary is probably wrong (consider consolidating the services).

## 3. Change Data Capture

Reads the owner's committed changes from its database log (in PostgreSQL, logical replication) and emits each row change as an event with before and after images, in commit order per row, surviving consumer downtime.

It is the counterpart of the **Transactional Outbox**: the outbox is how a service you own publishes intentional Domain Events (`event-driven-patterns`); Change Data Capture is how you integrate with a source that publishes nothing.

**Caveats:**
- It exposes the owner's **table schema**, not a curated event: translate it through an anti-corruption layer and never let raw column names spread.
- An owner's migration changes the payload: agree a coordination process, or the consumer breaks.
- One connector per source database; with several databases (per region, or per siloed tenant if `multi-tenancy-design` chose that), the connector count grows with them.

**Never use it on a service you own and can change** to stream its business tables: publish Domain Events through the outbox instead. Using log tailing to *relay the outbox table* is different and fine: it is one of the two outbox relays (polling publisher or transaction-log tailing, Richardson); the events are still the curated Domain Events.

## 4. No Shared Database

**Two services never share a table.** It looks like the cheapest integration and is the most expensive:
- neither owns the schema, so neither can migrate or deploy alone;
- there is no contract and no test surface, only the other side's storage layout;
- invariants leak: an Aggregate can't protect its rules if another service writes its rows.

The replacements are the three options in § 2. If two services seem to need a shared table, revisit the context map and the container diagram's decomposition: they may be one deployable. Inside a lean modular monolith the same rule holds between modules: one schema per module, reached only through the owning module's interface or events.

## 5. Checklist

- [ ] Every foreign model enters through an anti-corruption layer: port, client, translator; the domain imports only the port.
- [ ] Translators map only fields the domain uses.
- [ ] Every cross-context read path names its option and why the others were rejected.
- [ ] Change Data Capture, if used, has its own translation and a migration-coordination agreement, and the source genuinely can't publish events.
- [ ] No two services share a table.
