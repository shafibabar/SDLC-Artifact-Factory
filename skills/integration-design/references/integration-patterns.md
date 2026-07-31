# Integration Mechanisms: ACL, CDC, and the Cross-Service Data Menu

Reference for `integration-design`. Self-contained: how to build an Anti-
Corruption Layer in Go, how Change Data Capture works on this stack, the three
ways one service reads another's data (and how to choose), and why the shared-
database pattern is forbidden here.

---

## Anti-Corruption Layer (ACL)

An ACL is a translation adapter placed at a boundary where a *foreign model* —
another Bounded Context's model, or a vendor's API model — would otherwise leak
into our domain. It is `context-map-patterns`' ACL relationship made concrete in
Go. The rule it enforces is absolute: **a foreign model must never appear in our
domain layer.**

### Structure: client, translator, port

```
adapters/sourcecatalog/
  client.go       // speaks the FOREIGN API's types and conventions
  translator.go   // converts foreign DTOs <-> domain types
  dto.go          // the foreign wire shapes (owned by the boundary, not the domain)

domain/dataasset/
  ports.go        // SourceCatalogPort interface — the domain's view of the outside
  asset.go        // pure domain model — imports nothing from adapters/
```

The domain declares a **port interface** describing what it needs in *its own*
language. The ACL implements that port. The domain imports the port, never the
client.

```go
// domain/dataasset/ports.go — the domain's language, no foreign types
type SourceCatalogPort interface {
    LookupOrigin(ctx context.Context, assetID AssetID) (Origin, error)
}

// adapters/sourcecatalog/dto.go — the FOREIGN shape, lives at the boundary
type catalogEntryDTO struct {
    ObjID     string `json:"obj_id"`
    SrcSystem string `json:"src_system"`  // vendor's vocabulary, not ours
    Locator   string `json:"locator"`
    Tags      []struct{ K, V string } `json:"tags"`
}

// adapters/sourcecatalog/translator.go — the ONLY place the two vocabularies meet
func toOrigin(d catalogEntryDTO) (dataasset.Origin, error) {
    return dataasset.Origin{
        System:  dataasset.SourceSystem(d.SrcSystem), // translate, validate
        Path:    d.Locator,
        AssetID: dataasset.AssetID(d.ObjID),
    }, nil
}

// adapters/sourcecatalog/client.go — implements the domain port
func (c *Client) LookupOrigin(ctx context.Context, id dataasset.AssetID) (dataasset.Origin, error) {
    var dto catalogEntryDTO
    if err := c.get(ctx, "/entries/"+string(id), &dto); err != nil { // resilience stack lives here
        return dataasset.Origin{}, err
    }
    return toOrigin(dto)
}
```

### Boundary DTO vs. domain model — the separation that matters

The DTO (`catalogEntryDTO`) mirrors the vendor's wire format exactly, warts and
all (`obj_id`, `src_system`). The domain model (`Origin`) is *ours*, clean and
invariant-enforcing. Never let the DTO cross into the domain, and never serialize
the domain model directly onto the foreign wire — the translator is the airlock.

**Guard against stamp coupling** (Ford, *Hard Parts*): translate only the fields
the domain actually needs. If `catalogEntryDTO` grows a field nothing in the
domain reads, the translator ignores it — the domain stays uncoupled from fields
it never uses, so a vendor adding a field never forces a domain redeploy.

### Testing the ACL in isolation

The three-way split makes each piece independently testable:

- **Translator** — pure function; table-test foreign DTOs → expected domain types,
  including malformed inputs, with no network.
- **Client** — point it at an `httptest.Server` returning canned foreign JSON;
  assert it produces the right domain type and drives the resilience stack.
- **Domain** — depends only on `SourceCatalogPort`; test it with an in-memory
  fake, no external API involved at all.

---

## Change Data Capture (CDC) — non-invasive read integration

When a consuming context needs an owning context's data but the owner cannot (or
should not) be modified to publish Domain Events — a legacy service, a service
another team owns, an off-the-shelf component — **CDC** reads the owner's
PostgreSQL write-ahead log and turns row changes into a stream, without touching
the source service's code.

### How it works on this stack (Debezium → Redpanda)

```
Owner Service ──writes──▶ PostgreSQL ──WAL──▶ Debezium ──▶ Redpanda topic
                          (logical                          cdc.<owner>.<table>
                           replication slot)                        │
                                                                    ▼
                                                          Consumer projects into
                                                          its own Read Model
```

1. Enable **logical replication** on the owner's PostgreSQL (`wal_level = logical`)
   and create a replication slot.
2. **Debezium** (open-source, Kafka-Connect-compatible, works against Redpanda)
   connects to the slot and reads committed row changes (`INSERT`/`UPDATE`/
   `DELETE`) in commit order.
3. Debezium emits each change as a message to a `cdc.<owner>.<table>` Redpanda
   topic — a before/after image of the row.
4. The consuming context runs a normal idempotent consumer that projects those
   row changes into its own local Read Model.

CDC reads *committed* rows only (it reads the WAL, which reflects committed
state), preserves ordering per row, and survives consumer downtime (the slot
retains WAL until acknowledged). It is the non-invasive counterpart to the
Transactional Outbox: the outbox is how a service *we own* publishes intentional
Domain Events; CDC is how we integrate with a service that publishes *nothing*.

### CDC caveats

- CDC exposes the owner's **table schema**, not a curated event — a leakier
  contract than a Domain Event. Treat the CDC topic as needing its own ACL-style
  translation into the consumer's model; do not let raw column names spread.
- A schema migration on the owner changes the CDC payload — coordinate, or the
  consumer breaks. This is a real cost of the non-invasiveness.
- Per-tenant physical isolation means one Debezium connector + slot per tenant
  instance; account for the connector fleet in capacity planning.

---

## The cross-service data menu: three ways to read another context's data

When Service B needs data Aggregate A owns (cross-aggregate refs are by ID only —
`data-model-design`), there are exactly three legitimate patterns. Name which one,
and why, in the design — never leave it as an implicit "just call the API."

| Pattern | Mechanism | Consistency | Cost | Use when |
|---|---|---|---|---|
| **API composition** (Delegate) | B calls A's API live at read time | Always fresh | A must be up on B's read path; adds a sync hop + its resilience stack | Data changes fast, staleness unacceptable, read volume modest |
| **Data replication** (event-based) | A publishes Domain Events; B projects a local Read Model | Eventually consistent | B owns a projection to maintain and rebuild | B reads often, can tolerate lag, wants read-time independence from A |
| **CDC** | Debezium streams A's WAL; B projects it | Eventually consistent | Debezium infra; leaks A's schema | A *cannot* be modified to publish events (legacy/third-party) |

**Choosing:** prefer **data replication** for services we own that already publish
Domain Events — B reads its own store, no runtime coupling to A. Use **API
composition** when the data must be fresh and read volume is low enough that the
extra sync hop (wrapped in the full resilience stack) is acceptable. Reach for
**CDC** only when the owner publishes nothing and cannot be changed — it is the
non-invasive option of last resort, accepting a leakier schema contract in
exchange for touching no source code.

Ford's data-ownership vocabulary maps here: **Single Owner + Delegate** = one
service owns the table, others fetch live (API composition). **Common/Joint
Ownership** (two services writing the same data) is a red flag — escalate, it
usually means the boundary is wrong (a candidate for **Service Consolidation**).

---

## The shared-database anti-pattern — forbidden here

**Two services must never share a database table.** It looks like the cheapest
integration — B just `SELECT`s from A's table — and it is the most expensive
mistake:

- Both services couple to a schema **neither exclusively owns**; A cannot migrate
  the table without risking B, so neither can deploy independently — the whole
  point of separate services is lost.
- There is no contract, no interface, no test surface — B depends on A's physical
  storage layout, the most volatile thing A has.
- Invariants leak: A's Aggregate can no longer guarantee its own rules if B writes
  the same rows.
- On this platform it is doubly impossible: **per-tenant physical isolation** puts
  each tenant's data in a separate PostgreSQL instance, and services already own
  distinct databases — there is no shared instance to share a table in.

The correct replacements are exactly the three patterns above: API composition,
event-based replication, or CDC. If two services seem to *need* a shared table,
the boundary between them is wrong — revisit the Context Map, and consider whether
they are really one service (Service Consolidation) rather than two.

---

## Checklist

- [ ] Every foreign model (vendor or cross-BC) enters through an ACL with a
      client / translator / port split; the domain imports only the port.
- [ ] The translator maps only fields the domain uses (no stamp coupling).
- [ ] Each cross-context read path names its pattern: API composition, event
      replication, or CDC — with the reason the other two were rejected.
- [ ] CDC (if used) has its own translation layer and a schema-migration
      coordination plan with the owner.
- [ ] No two services share a database table — verified against the Integration
      Inventory.
